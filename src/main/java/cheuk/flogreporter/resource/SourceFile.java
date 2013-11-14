/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter.resource;

import cheuk.flogreporter.FlogBuildAction;
import hudson.FilePath;
import hudson.model.AbstractBuild;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.kohsuke.stapler.StaplerRequest;
import org.kohsuke.stapler.StaplerResponse;

/**
 *
 * @author cheuk
 */
public class SourceFile {
    private AbstractBuild<?, ?> owner;
    private final String fileName;
    private List<SourceLine> lines;
    private int numberOfWarning;
    
    public SourceFile(AbstractBuild<?, ?> owner, String fileName){
        this.owner = owner;
        this.fileName = fileName;
        numberOfWarning = 0;
        lines = new ArrayList();
        setLines(owner.getWorkspace());
    }
    
    private void setLines(FilePath workspace){
        try {
            lines.clear();
            if (!workspace.child(fileName).exists()){
                return;
            }
            File file = new File (workspace.child(fileName).getRemote());
            BufferedReader br;
            br = new BufferedReader(new FileReader(file));
            String line = br.readLine();
            int i = 1;
            while (line != null) {
                SourceLine currentLine = new SourceLine(i, line);
                lines.add(currentLine);
                line = br.readLine();
                i++;
            }
        } catch (FileNotFoundException ex) {
            Logger.getLogger(SourceFile.class.getName()).log(Level.SEVERE, null, ex);
        } catch (IOException ex) {
            Logger.getLogger(SourceFile.class.getName()).log(Level.SEVERE, null, ex);
        } catch (InterruptedException ex) {
            Logger.getLogger(SourceFile.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    public void addReport(FlogReport report) {
        numberOfWarning += report.getLines().size();
        if (lines.isEmpty()){
            return;
        }
        Iterator<Integer> it = report.getLines().iterator();
        while (it.hasNext()){
            int lineNo = it.next();
            SourceLine sourceLine = lines.get(lineNo-1);
            sourceLine.addReport(report);
        }
    }
    
    public void doGraph(StaplerRequest req, StaplerResponse rsp) throws IOException {
        FlogBuildAction buildAction = owner.getAction(FlogBuildAction.class);
        if (buildAction != null) {
            buildAction.doSourceGraph(fileName, req, rsp);
        }
    }
    
    public AbstractBuild<?, ?> getOwner(){
        return owner;
    }
    
    public String getFileName(){
        return fileName;
    }
    
    public List<SourceLine> getLines(){
        return lines;
    }
    
    public int getNumberOfWarning(){
        return numberOfWarning;
    }
    
    public class SourceLine{
        private final String content;
        private final int lineNo;
        private List<FlogReport> reports;
        
        SourceLine(int lineNo, String content){
            this.content = content;
            this.lineNo = lineNo;
            reports = new ArrayList();
        }
        
        public String getContent(){
            return content;
        }
        
        public int getLineNo(){
            return lineNo;
        }

        private void addReport(FlogReport report) {
            reports.add(report);
        }
        
        public List<FlogReport> getReports(){
            return reports;
        }
    };
    
}
