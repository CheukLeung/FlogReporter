/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter.resource;

import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author cheuk
 */
public class FlogReport {
    static private int nextID = 0;
    
    public static final int Default = 0;
    public static final int Duplication = 1;
    public static final int NestedIterators = 2;
    public static final int UncommunicativeName = 3;
    public static final int ControlCouple = 4;
    
    static public int getSize(){
        return nextID;
    }
    
    private int id;
    private int type;
    private String source;
    private List<Integer> lines;
    private String context;
    private String smellClass;
    private String subClass;
    private String message;
    private boolean isActive;
    
    private String call;
    private int occurrences;
    private int depth;
    private String methodName;
    private String variableName;
    private String parameter;

    public FlogReport(){
        id = nextID;
        lines = new ArrayList();
        nextID++;
    }
    
    public int getId(){
        return id;
    }
        
    public void setType(int type){
        this.type = type;
    }
    
    public void setSource(String source){
        this.source = source;
    }
    
    public String getSource() {
        return source;
    }
    
    public void addLine(int line){
        this.lines.add(line);
    }
    
    public List<Integer> getLines() {
        return lines;
    }
    
    public void setContext(String context){
        this.context = context;
    }
    
    public void setSmellClass(String smellClass){
        this.smellClass = smellClass;
    }
    
    public String getSmellClass() {
        return smellClass;
    }
    
    public void setSubClass(String subClass){
        this.subClass = subClass;
    }
    
    public String getSubClass() {
        return subClass;
    }
    
    public void setMessage(String message){
        this.message = message;
    }
    
    public String getMessage() {
        return message;
    }
    
    public void setIsActive(boolean isActive){
        this.isActive = isActive;
    }
    
    public void setCall(String call){
        this.call = call;
    }
    
    public void setOccurrences(int occurrences){
        this.occurrences = occurrences;
    }
    
    public void setDepth(int depth){
        this.depth = depth;
    }
    
    public void setMethodName(String methodName){
        this.methodName = methodName;
    }
    
    public void setVariableName(String variableName){
        this.variableName = variableName;
    }
    
    public void setParameter(String parameter){
        this.parameter = parameter;
    }

    public void printAll() {
        System.out.print(id);
        System.out.println(source);
        System.out.println(context);
        System.out.println(smellClass);
        System.out.println(subClass);
        System.out.println(message);
        System.out.println(isActive);
        System.out.println(call);
        System.out.println(occurrences);
        System.out.println(depth);
        System.out.println(methodName);
        System.out.println(variableName);
        System.out.println(parameter);
    }
    
}
