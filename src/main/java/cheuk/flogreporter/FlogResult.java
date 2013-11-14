/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter;

import cheuk.flogreporter.resource.FlogReport;
import cheuk.flogreporter.resource.SourceFile;
import hudson.model.AbstractBuild;
import hudson.model.Item;
import hudson.util.ChartUtil;
import java.io.IOException;
import java.io.Serializable;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import org.kohsuke.stapler.StaplerRequest;
import org.kohsuke.stapler.StaplerResponse;

/**
 *
 * @author cheuk
 */
public class FlogResult implements Serializable{
    private static final long serialVersionUID = 1L;
    
    private AbstractBuild<?, ?> owner;
    private List<FlogReport> flogReports;
    private HashMap<String, SourceFile> sourceFileHash;
            
    public FlogResult(AbstractBuild <?, ?> owner, List<FlogReport> flogReports, HashMap<String, SourceFile> sourceFileHash){
        this.owner = owner;
        this.flogReports = flogReports;
        this.sourceFileHash = sourceFileHash;
    }
    
    public FlogResult getPreviousresult(){
        FlogBuildAction previousAction = getPreviousAction();
        FlogResult previousResult = null;
        if (previousAction != null){
            previousResult = previousAction.getResult();
        }
        
        return previousResult;
    }

    private FlogBuildAction getPreviousAction() {
        AbstractBuild<?, ?> previousBuild = owner.getPreviousBuild();
        if (previousBuild != null){
            return previousBuild.getAction(FlogBuildAction.class);
        }
        return null;
    }
    
    public AbstractBuild<?, ?> getOwner(){
        return owner;
    }
    
    public List<FlogReport> getFlogReports(){
        return flogReports;
    }
    
    public HashMap<String, SourceFile> getSourceFileHash(){
        return sourceFileHash;
    }
    
    @SuppressWarnings("unused")
    public Object getDynamic(final String link, final StaplerRequest request,
                            final StaplerResponse response) throws IOException{
        String linkModified = link.replaceAll("=", "/");

        if (linkModified.startsWith("source.")){
            if (!owner.getProject().getACL().hasPermission(Item.WORKSPACE)){
                response.sendRedirect2("nosourcepermission");
                return null;
            }
            if (sourceFileHash.containsKey(linkModified.replaceFirst("source.", ""))){
                return sourceFileHash.get(linkModified.replaceFirst("source.", ""));
            }
        }
        return null;
    }
    
    public void doGraph(StaplerRequest req, StaplerResponse rsp) throws IOException {
        if (ChartUtil.awtProblemCause != null){
            rsp.sendRedirect2(req.getContextPath() + "/images/headless.png");
            return;
        }
        
        AbstractBuild<?, ?> build = getOwner();
        Calendar timestamp = build.getTimestamp();
        
        if (req.checkIfModified(timestamp, rsp)){
            return;
        }
        
        FlogBuildAction buildAction = owner.getAction(FlogBuildAction.class);
        if (buildAction != null){
            buildAction.doGraph(req, rsp);
        }
    }
}
