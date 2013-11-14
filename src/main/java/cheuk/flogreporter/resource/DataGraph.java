/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package cheuk.flogreporter.resource;

import hudson.model.AbstractBuild;
import hudson.util.Graph;
import hudson.util.ShiftedCategoryAxis;
import hudson.util.StackedAreaRenderer2;
import java.awt.Color;
import org.jfree.chart.ChartFactory;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.axis.CategoryAxis;
import org.jfree.chart.axis.CategoryLabelPositions;
import org.jfree.chart.axis.NumberAxis;
import org.jfree.chart.plot.CategoryPlot;
import org.jfree.chart.plot.PlotOrientation;
import org.jfree.chart.renderer.category.StackedAreaRenderer;
import org.jfree.data.category.CategoryDataset;
import org.jfree.ui.RectangleInsets;

/**
 *
 * @author cheuk
 */
public class DataGraph extends Graph {
    public static final int DEFAULT_CHART_WIDTH = 500;
    public static final int DEFAULT_CHART_HEIGHT = 200;
    private static final Color RED    = new Color(0xEF, 0x29, 0x29);
    private static final Color VIOLET = new Color(0xEE, 0x82, 0xEE);
    private static final Color YELLOW = new Color(0xCC, 0xCC, 0x00);
    private static final Color GRAY   = new Color(0x30, 0x30, 0x30);
    
    private final String yLabel;
    private final CategoryDataset categoryDataset;
    
    public DataGraph(AbstractBuild<?, ?> owner, CategoryDataset categoryDataset, String yLabel, int chartWidth, int chartHeight) {
        super(owner.getTimestamp(), chartWidth, chartHeight);
        this.yLabel = yLabel;
        this.categoryDataset = categoryDataset;
    }
    
     /**
     * Creates a trend graph
     *
     * @return the JFreeChart graph object
     */
    protected JFreeChart createGraph() {

        final JFreeChart chart = ChartFactory.createLineChart(
                null,                     // chart title
                null,                     // unused
                yLabel,                   // range axis label
                categoryDataset,          // data
                PlotOrientation.VERTICAL, // orientation
                false,                     // include legend
                true,                     // tooltips
                false                     // urls
        );

        // NOW DO SOME OPTIONAL CUSTOMISATION OF THE CHART...

        //final LegendTitle legend = chart.getLegend();
        //legend.setPosition(RectangleEdge.RIGHT);

        chart.setBackgroundPaint(Color.white);

        final CategoryPlot plot = chart.getCategoryPlot();

        // plot.setAxisOffset(new Spacer(Spacer.ABSOLUTE, 5.0, 5.0, 5.0, 5.0));
        plot.setBackgroundPaint(Color.WHITE);
        plot.setOutlinePaint(null);
        plot.setRangeGridlinesVisible(true);
        plot.setRangeGridlinePaint(Color.black);

        CategoryAxis domainAxis = new ShiftedCategoryAxis(null);
        plot.setDomainAxis(domainAxis);
        domainAxis.setCategoryLabelPositions(CategoryLabelPositions.UP_90);
        domainAxis.setLowerMargin(0.0);
        domainAxis.setUpperMargin(0.0);
        domainAxis.setCategoryMargin(0.0);

        final NumberAxis rangeAxis = (NumberAxis) plot.getRangeAxis();
        rangeAxis.setStandardTickUnits(NumberAxis.createIntegerTickUnits());
        rangeAxis.setLowerBound(0);
//        rangeAxis.setAutoRange(true);

        final StackedAreaRenderer renderer = new StackedAreaRenderer2();
        plot.setRenderer(renderer);
        //renderer.setBaseStroke(new BasicStroke(2.0f));
        //ColorPalette.apply(renderer);
        plot.setRenderer(renderer);
        renderer.setSeriesPaint(2, RED);
        renderer.setSeriesPaint(1, VIOLET);
        renderer.setSeriesPaint(0, YELLOW);

        // crop extra space around the graph
        plot.setInsets(new RectangleInsets(5.0, 0, 0, 5.0));

        return chart;
    }
    
}

