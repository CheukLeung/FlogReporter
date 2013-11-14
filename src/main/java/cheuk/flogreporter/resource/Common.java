/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter.resource;

import cheuk.flogreporter.FlogReportParser;
import hudson.FilePath;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author cheuk
 */
public class Common {
    static public List<FilePath> locateFiles(FilePath rootDir){
        List<FilePath> fileList;
        fileList = new ArrayList<FilePath>();

        try {
            if (rootDir.isDirectory()){
                Iterator<FilePath> it = rootDir.list().iterator();
                while ( it.hasNext() ){
                    FilePath element = it.next();
                    fileList.addAll(locateFiles(element));
                }
            }
            else {
                fileList.add(rootDir);
            }
        } catch (IOException ex) {
            Logger.getLogger(FlogReportParser.class.getName()).log(Level.SEVERE, null, ex);
        } catch (InterruptedException ex) {
            Logger.getLogger(FlogReportParser.class.getName()).log(Level.SEVERE, null, ex);
        }
        return fileList;
    }
}
