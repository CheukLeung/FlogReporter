/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter;

import cheuk.flogreporter.resource.DataGraph;
import cheuk.flogreporter.resource.SourceFile;
import hudson.model.AbstractBuild;
import hudson.model.Action;
import hudson.model.Actionable;
import hudson.model.Result;
import hudson.util.ChartUtil;
import hudson.util.DataSetBuilder;
import hudson.util.Graph;
import java.io.IOException;
import java.util.Calendar;
import org.kohsuke.stapler.StaplerProxy;
import org.kohsuke.stapler.StaplerRequest;
import org.kohsuke.stapler.StaplerResponse;

/**
 *
 * @author cheuk
 */
public class FlogBuildAction extends Actionable implements Action, StaplerProxy {

    public static final String URL_NAME = "FlogResult";

    public static FlogBuildAction load(AbstractBuild<?, ?> owner, FlogResult result) {
        return new FlogBuildAction(owner, result);
    }
    
    static public FlogBuildAction getPreviousResult(AbstractBuild<?, ?> start) {
        AbstractBuild<?, ?> b = start;
        while (true) {
            b = b.getPreviousNotFailedBuild();
            if (b == null){
                return null;
            }
            assert b.getResult() != Result.FAILURE;
            FlogBuildAction r = b.getAction(FlogBuildAction.class);
            if (r != null){
                return r;
            }
        }
    }
    
    private final AbstractBuild<?, ?> owner;
    private final FlogResult result;
    
    FlogBuildAction(AbstractBuild<?, ?> owner, FlogResult result){
        this.owner = owner;
        this.result = result;
    }
    
    private DataSetBuilder<String, ChartUtil.NumberOnlyBuildLabel> getDataSetBuilder(){
        DataSetBuilder<String, ChartUtil.NumberOnlyBuildLabel> dsb =
                new DataSetBuilder<String, ChartUtil.NumberOnlyBuildLabel>();
        
        for (FlogBuildAction a = this; a != null; a = a.getPreviousResult()){
            ChartUtil.NumberOnlyBuildLabel label = new ChartUtil.NumberOnlyBuildLabel(a.owner);
            FlogResult aResult = a.getResult();
            dsb.add(aResult.getFlogReports().size(), "Number of warnings", label);
        }
        
        return dsb;
    }
    
    public void doGraph(StaplerRequest req, StaplerResponse rsp) throws IOException {
        if (ChartUtil.awtProblemCause != null){
            rsp.sendRedirect2(req.getContextPath() + "/images/headless.png");
            return;
        }
        Calendar timestamp = getOwner().getTimestamp();
        
        if (req.checkIfModified(timestamp, rsp)){
            return;
        }
        
        Graph g = new DataGraph(getOwner(), getDataSetBuilder().build(),
                "Number of warnings", 500, 200);
        g.doPng(req, rsp);
    }
    
    private DataSetBuilder<String, ChartUtil.NumberOnlyBuildLabel> getSourceDataSetBuilder(String fileName){
        DataSetBuilder<String, ChartUtil.NumberOnlyBuildLabel> dsb =
                new DataSetBuilder<String, ChartUtil.NumberOnlyBuildLabel>();
        
        for (FlogBuildAction a = this; a != null; a = a.getPreviousResult()){
            ChartUtil.NumberOnlyBuildLabel label = new ChartUtil.NumberOnlyBuildLabel(a.owner);
            if (a.getResult().getSourceFileHash().containsKey(fileName)){
                SourceFile srcFile = a.getResult().getSourceFileHash().get(fileName);
                dsb.add(srcFile.getNumberOfWarning(), "Number of warnings", label);
            }
        }
        
        return dsb;
    }
    
    public void doSourceGraph(String fileName, StaplerRequest req, StaplerResponse rsp) throws IOException {
        if (ChartUtil.awtProblemCause != null){
            rsp.sendRedirect2(req.getContextPath() + "/images/headless.png");
            return;
        }
        Calendar timestamp = getOwner().getTimestamp();
        
        if (req.checkIfModified(timestamp, rsp)){
            return;
        }
        
        Graph g = new DataGraph(getOwner(), getSourceDataSetBuilder(fileName).build(),
                "Number of warnings", 500, 200);
        g.doPng(req, rsp);
    }
    
    public FlogBuildAction getPreviousResult(){
        return getPreviousResult(owner);
    }
    
    public String getDisplayName() {
        return "Flog Result";
    }

    public String getSearchUrl() {
        return getUrlName();
    }

    public String getIconFileName() {
        return "clipboard.png";
    }

    public String getUrlName() {
        return URL_NAME;
    }
    
    public AbstractBuild<?, ?> getOwner(){
        return owner;
    }

    public Object getTarget() {
        return result;
    }

    public FlogResult getResult() {
        return result;
    }
    
}
