# let statement

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

The `let` statement binds a name to an expression or a function, which can then be referenced throughout the query. It enables code reuse, improves readability, and can enhance query performance through common subexpression materialization.

## Syntax

### Scalar variable

```kusto
let varName = scalar_expression;
```

### Tabular variable

```kusto
let varName = tabular_expression;
```

### Function with parameters

```kusto
let funcName = (param1:type1, param2:type2, ...) { function_body };
```

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *varName* or *funcName* | string | ✓ | The name of the variable or function being defined. |
| *scalar_expression* | scalar | ✓ | An expression that returns a scalar value. |
| *tabular_expression* | tabular | ✓ | An expression that returns a tabular result. |
| *param1*, *param2*, ... | any | | Parameters for a function definition. |
| *type1*, *type2*, ... | string | | Data types for function parameters. |
| *function_body* | any | ✓ | An expression that uses the parameters and returns a result. |

## Examples

### Scalar variables

```kusto
let timeThreshold = ago(7d);
Events
| where Timestamp > timeThreshold
```

```kusto
let errorSeverity = "Error";
let minCount = 10;
Events
| where Severity == errorSeverity
| summarize ErrorCount = count() by Source
| where ErrorCount >= minCount
```

### Tabular variables

```kusto
let recentErrors = Events
| where Timestamp > ago(1h)
| where Severity == "Error";

recentErrors
| summarize count() by Source
```

```kusto
let recentErrors = Events
| where Timestamp > ago(1h)
| where Severity == "Error";

let criticalSystems = datatable(SystemName:string)
[
    "Payment",
    "Authentication",
    "Core"
];

recentErrors
| where Source in (criticalSystems)
```

### Function definitions

Simple function:

```kusto
let getEventsInPeriod = (startTime:datetime, endTime:datetime) {
    Events
    | where Timestamp between (startTime .. endTime)
};

getEventsInPeriod(ago(2h), ago(1h))
| summarize count() by Source
```

Function with default parameters:

```kusto
let getErrors = (timeago:timespan = 1h, severityLevel:string = "Error") {
    Events
    | where Timestamp > ago(timeago)
    | where Severity == severityLevel
};

getErrors()  // Uses defaults: 1h and "Error"
getErrors(3h)  // Uses 3h and default "Error"
getErrors(12h, "Critical")  // Specifies both parameters
```

### Multiple let statements

```kusto
let timeThreshold = ago(1d);
let criticalErrors = Events
| where Timestamp > timeThreshold
| where Severity == "Critical";
let warningErrors = Events
| where Timestamp > timeThreshold
| where Severity == "Warning";

criticalErrors | count as CriticalCount
```

### Views with let statements

```kusto
let ErrorView = view () {
    Events
    | where Severity == "Error"
    | project Timestamp, Source, Message
};

ErrorView
| where Timestamp > ago(1h)
```

## Common patterns

### Time windows and constants

```kusto
let lookbackWindow = 7d;
let timeGrain = 1h;
let errorSeverities = dynamic(["Critical", "Error"]);

Events
| where Timestamp > ago(lookbackWindow)
| where Severity in (errorSeverities)
| summarize ErrorCount = count() by bin(Timestamp, timeGrain), Source
```

### Reusable filters

```kusto
let isProduction = (environment:string) { environment contains "prod" };
let isUserFacing = (service:string) { service in ("Frontend", "API", "Auth") };

Events
| where isProduction(Environment) and isUserFacing(ServiceName)
```

### Creating temporary tables

```kusto
let UserTable = ExternalTable("Users");
let ActivityTable = ExternalTable("Activity");

UserTable
| join ActivityTable on UserID
| project UserName, LastActivity
```

### Materialization

The `materialize()` function can be used to cache the result of an expensive operation:

```kusto
let materializedData = materialize(
    Events
    | where Timestamp > ago(7d)
    | where Severity in ("Critical", "Error")
);

// Use the materialized data multiple times
materializedData
| summarize count() by Source

materializedData
| summarize count() by bin(Timestamp, 1h)
```

## Scope and visibility

- `let` statements are visible from their declaration until the end of the query
- `let` statements can reference previously defined variables or functions
- Later `let` statements can shadow (override) earlier ones with the same name
- `let` statements in a query can reference global functions/variables

## Performance considerations

1. Use `let` to avoid repeating complex expressions
2. Use `materialize()` to cache intermediate results used multiple times
3. Place `let` statements at the beginning of the query for clarity
4. Consider breaking complex queries into smaller, more manageable parts using `let`
5. Use parameters in functions to make them more reusable

## Related statements and operators

- [tabular expression statements](tabular-expression-statements.md) - Statements that define a tabular expression
- [print](print-operator.md) - Displays scalar results during query execution
- [materialize()](materialize-function.md) - Materializes tabular expressions for reuse
