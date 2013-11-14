/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter;

import hudson.model.AbstractBuild;
import hudson.model.AbstractProject;
import hudson.model.Actionable;
import hudson.model.ProminentProjectAction;
import hudson.model.Result;
import java.io.IOException;
import org.kohsuke.stapler.StaplerRequest;
import org.kohsuke.stapler.StaplerResponse;

/**
 *
 * @author cheuk
 */
public class FlogProjectAction extends Actionable implements ProminentProjectAction{

    private final AbstractProject<?, ?> project;
    
    public FlogProjectAction(AbstractProject<?, ?> project){
        this.project = project;
    }
    
    public AbstractProject<?, ?> getProject(){
        return project;
    }
    
    public String getDisplayName() {
        return "Flog Results";
    }

    public String getSearchUrl() {
        return getUrlName();
    }

    public String getIconFileName() {
        return "clipboard.png";
    }

    public String getUrlName() {
        return "FlogResult";
    }
    
    public Integer getLastResultBuild() {
        for (AbstractBuild<?, ?> b = project.getLastSuccessfulBuild(); b != null; b = b.getPreviousNotFailedBuild()) {
            if (b.getResult() == Result.FAILURE )
                continue;
            FlogBuildAction r = b.getAction(FlogBuildAction.class);
            if (r != null)
                return b.getNumber();
        }
        return null;
    }    
    
    public void doGraph(StaplerRequest req, StaplerResponse rsp) throws IOException {
        AbstractBuild<?, ?> lastBuild = getLastFinishedBuild();
        FlogBuildAction buildAction = lastBuild.getAction(FlogBuildAction.class);
        if (buildAction != null) {
            buildAction.doGraph(req, rsp);
        }
    }

    public AbstractBuild<?, ?> getLastFinishedBuild() {
        AbstractBuild<?, ?> lastBuild = project.getLastBuild();
        while (lastBuild != null && (lastBuild.isBuilding() || 
                lastBuild.getAction(FlogBuildAction.class) == null)) {
            lastBuild = lastBuild.getPreviousBuild();
        }
        return lastBuild;
    }
    
    @SuppressWarnings("unused")
    public final boolean isDisplayGraph() {
        //Latest
        AbstractBuild<?, ?> b = getLastFinishedBuild();
        if (b == null) {
            return false;
        }

        //Affect previous
        b = b.getPreviousBuild();
        if (b != null) {

            for (; b != null; b = b.getPreviousBuild()) {
                if (b.getResult().isWorseOrEqualTo(Result.FAILURE)) {
                    continue;
                }
                FlogBuildAction action = b.getAction(FlogBuildAction.class);
                if (action == null || action.getResult() == null) {
                    continue;
                }
                
                FlogResult result = action.getResult();
                if (result == null)
                    continue;

                return true;
            }
        }
        return false;
    }
    
    public void doIndex(StaplerRequest req, StaplerResponse rsp) throws IOException {
        Integer buildNumber = getLastResultBuild();
        if (buildNumber == null) {
            rsp.sendRedirect2("nodata");
        } else {
            rsp.sendRedirect2("../" + buildNumber + "/FlogResult");
        }
    }
    
}
