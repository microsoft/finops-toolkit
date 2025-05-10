# Render operator

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Instructs the user agent to render the results of the query in a specific format.

## Syntax

*T* `| render` *Visualization* [`with` `(` *PropertyName* `=` *PropertyValue* [`,` ...] `)`]

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *T* | string | ✓ | The input tabular data source. |
| *Visualization* | string | ✓ | The type of visualization to use. Options include: `table`, `columnchart`, `barchart`, `piechart`, `linechart`, `timechart`, `areachart`, `scatterchart` and more. |
| *PropertyName*/*PropertyValue* | string/string | | Additional parameters to control the visualization, specified as name-value pairs. |

## Visualization types

### Table (default)

The default visualization, presenting the data in tabular format.

```kusto
StormEvents
| take 5
| render table
```

### Column chart

Displays vertical bars, where the first column is the x-axis and other numeric columns are the values.

```kusto
StormEvents
| summarize Count=count() by State
| top 10 by Count desc
| render columnchart
```

### Bar chart

Similar to column chart but with horizontal bars.

```kusto
StormEvents
| summarize Count=count() by State
| top 10 by Count desc
| render barchart
```

### Pie chart

Displays data as slices of a pie. The first column is used as labels, the second numeric column as values.

```kusto
StormEvents
| summarize Count=count() by EventType
| top 5 by Count desc
| render piechart
```

### Line chart

Good for showing trends over time or comparing multiple series.

```kusto
StormEvents
| summarize EventCount=count() by bin(StartTime, 1d)
| where StartTime > datetime(2007-06-01) and StartTime < datetime(2007-06-30)
| render linechart
```

### Time chart

Optimized for time series data, automatically formatting the x-axis as a time scale.

```kusto
StormEvents
| summarize EventCount=count() by bin(StartTime, 1d)
| where StartTime > datetime(2007-06-01) and StartTime < datetime(2007-06-30)
| render timechart
```

### Area chart

Similar to line chart but with filled areas below the lines.

```kusto
StormEvents
| summarize EventCount=count() by State, bin(StartTime, 1month)
| where StartTime > datetime(2007-06-01) and StartTime < datetime(2007-12-31)
| render areachart
```

### Scatter chart

Shows the relationship between two variables as points on a coordinate system.

```kusto
StormEvents
| summarize AvgDamage=avg(DamageProperty), Count=count() by State
| render scatterchart
```

## Visualization properties

You can add properties to control the visualization using the `with` clause:

```kusto
StormEvents
| summarize EventCount=count() by State
| render columnchart with (title="Storm Events by State", yaxis=EventCount)
```

Common properties include:

| Property | Description |
|--|--|
| `title` | The title of the chart |
| `xtitle` | Title for the x-axis |
| `ytitle` | Title for the y-axis |
| `xaxis` | Column to use for x-axis |
| `yaxis` | Column to use for y-axis |
| `series` | Column to split the data into different series |
| `legend` | Whether to show the legend (`visible`/`hidden`) |
| `xcolumn` | Column from the result to use for the x-axis |
| `ycolumns` | Comma-separated list of columns to use as y-axes |

## Notes

1. The `render` operator is processed on the client side, not by the service. Visual effects depend on the client tool you're using.

2. Visualizations work best when you pre-aggregate data. Use `summarize` to reduce your data to a manageable size before rendering.

3. Not all chart types support all data arrangements. Format your data to match the requirements of your chosen visualization.

4. When using the time series visualizations (`timechart`), ensure your time column is the x-axis and properly binned (using `bin()` or `floor()`).

5. Use the rendering property arguments to customize your charts, making them more readable and informative.
