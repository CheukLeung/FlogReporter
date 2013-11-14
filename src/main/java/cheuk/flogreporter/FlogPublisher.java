/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter;

import hudson.Extension;
import hudson.Launcher;
import hudson.model.AbstractBuild;
import hudson.model.AbstractProject;
import hudson.model.BuildListener;
import hudson.tasks.BuildStepDescriptor;
import hudson.tasks.BuildStepMonitor;
import hudson.tasks.Publisher;
import org.kohsuke.stapler.DataBoundConstructor;
import cheuk.flogreporter.resource.FlogReport;
import cheuk.flogreporter.resource.SourceFile;
import hudson.model.Action;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;

/**
 *
 * @author cheuk
 */
public class FlogPublisher extends Publisher{
    
    public String flogDir;
    HashMap<String, SourceFile> sourceFileHash;
    
    @DataBoundConstructor
    public FlogPublisher(String flogDir) {
        this.flogDir = flogDir;
    }
    
    public BuildStepMonitor getRequiredMonitorService() {
        return BuildStepMonitor.BUILD;
    }
    

    @Override
    @SuppressWarnings("null")
    public boolean perform (AbstractBuild build, Launcher launcher, BuildListener listener){
        listener.getLogger().println("Running Flog result reporter");
        List<FlogReport> flogReports = FlogReportParser.doParse(build.getWorkspace().child(flogDir));
        listener.getLogger().println("" + FlogReport.getSize() + " warning(s) are found.");
        
        sourceFileHash = new HashMap<String, SourceFile>();
        setSourceFileHash(build, flogReports);
        
        final FlogResult result = new FlogResult(build, flogReports, sourceFileHash);
        final FlogBuildAction action = FlogBuildAction.load(build, result);
        build.getActions().add(action);
        
        return true;
    }
    
    @Override
    public Action getProjectAction(AbstractProject<?, ?> project){
        return new FlogProjectAction(project);
    }
    
    @Override
    public FlogPublisher.DescriptorImpl getDescriptor(){
        return (FlogPublisher.DescriptorImpl)super.getDescriptor();
    }

    private void setSourceFileHash(AbstractBuild<?, ?> build, List<FlogReport> flogReports) {
        Iterator<FlogReport> it = flogReports.iterator();
        while (it.hasNext()){
            FlogReport report = it.next();
            SourceFile sourceFile;
            String fileName = report.getSource();
            if (sourceFileHash.containsKey(fileName)){
                sourceFile = sourceFileHash.get(fileName);
            }
            else {
                sourceFile = new SourceFile(build, fileName);
                sourceFileHash.put(fileName, sourceFile);
            }
            sourceFile.addReport(report);
            
        }
    }

    @Extension
    public static final class DescriptorImpl extends BuildStepDescriptor<Publisher> {
        @Override
        public boolean isApplicable(Class<? extends AbstractProject> type){
            return true;
        }
        
        @Override
        public String getDisplayName(){
            return "Flog result reporter";
        }
    }
}
