# Working with Arrays in KQL

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Arrays in Kusto Query Language (KQL) are ordered collections of values, typically represented using the [dynamic](dynamic.md) data type. This document provides an overview of how to create, manipulate, and query arrays in KQL.

## Creating Arrays

### Using dynamic literals

The most common way to create arrays is using dynamic literals:

```kusto
let myArray = dynamic([1, 2, 3, 4, 5]);
print myArray
```

Arrays can contain mixed types:

```kusto
let mixedArray = dynamic([1, "hello", true, datetime(2023-01-01)]);
print mixedArray
```

### Using the range() function

The `range()` function creates arrays of sequential numbers:

```kusto
// Create an array of 5 numbers, starting from 1, with step 1
let numbers = range(1, 5, 1);
print numbers  // [1, 2, 3, 4, 5]
```

### Using make_list() aggregation

You can create arrays by aggregating values:

```kusto
Events 
| summarize UserIds = make_list(UserId) by EventType
```

## Accessing Array Elements

Use zero-based indexing with square brackets to access array elements:

```kusto
let fruits = dynamic(["apple", "banana", "cherry", "date"]);
print 
    FirstFruit = fruits[0],   // "apple"
    LastFruit = fruits[3],    // "date"
    OutOfBounds = fruits[10]  // null (out of bounds)
```

## Array Functions

KQL provides a rich set of functions for working with arrays:

### array_length()

Returns the number of elements in an array:

```kusto
let fruits = dynamic(["apple", "banana", "cherry"]);
print ArrayLength = array_length(fruits)  // 3
```

### array_contains()

Checks if an array contains a specific value:

```kusto
let fruits = dynamic(["apple", "banana", "cherry"]);
print ContainsBanana = array_contains(fruits, "banana")  // true
```

### array_index_of()

Returns the position of a value in an array:

```kusto
let fruits = dynamic(["apple", "banana", "cherry"]);
print BananaPosition = array_index_of(fruits, "banana")  // 1
```

### array_concat()

Combines multiple arrays:

```kusto
let fruits1 = dynamic(["apple", "banana"]);
let fruits2 = dynamic(["cherry", "date"]);
print AllFruits = array_concat(fruits1, fruits2)  // ["apple", "banana", "cherry", "date"]
```

### array_slice()

Extracts a section of an array:

```kusto
let numbers = range(1, 10, 1);
print 
    First3 = array_slice(numbers, 0, 3),  // [1, 2, 3]
    Middle = array_slice(numbers, 3, 3)   // [4, 5, 6]
```

### array_sort()

Sorts array elements:

```kusto
let unsorted = dynamic([3, 1, 4, 2, 5]);
print Sorted = array_sort(unsorted)  // [1, 2, 3, 4, 5]
```

### array_sort_asc() and array_sort_desc()

Sort arrays in ascending or descending order:

```kusto
let numbers = dynamic([3, 1, 4, 2, 5]);
print 
    AscendingSort = array_sort_asc(numbers),   // [1, 2, 3, 4, 5]
    DescendingSort = array_sort_desc(numbers)  // [5, 4, 3, 2, 1]
```

### array_join()

Joins array elements with a delimiter:

```kusto
let fruits = dynamic(["apple", "banana", "cherry"]);
print FruitList = array_join(fruits, ", ")  // "apple, banana, cherry"
```

## Expanding Arrays

### mv-expand

The `mv-expand` operator expands arrays into multiple rows:

```kusto
let logs = datatable(TraceId:string, Events:dynamic)
[
    "trace-1", dynamic(["start", "process", "end"]),
    "trace-2", dynamic(["start", "error"])
];
logs
| mv-expand Events
| project TraceId, Event = Events
```

Result:

| TraceId | Event |
|---------|-------|
| trace-1 | start |
| trace-1 | process |
| trace-1 | end |
| trace-2 | start |
| trace-2 | error |

### mv-apply

The `mv-apply` operator applies a subquery to each array element:

```kusto
let logsWithTimestamps = datatable(TraceId:string, Events:dynamic)
[
    "trace-1", dynamic([
        {"name": "start", "timestamp": "2023-01-01T10:00:00Z"},
        {"name": "process", "timestamp": "2023-01-01T10:01:30Z"},
        {"name": "end", "timestamp": "2023-01-01T10:03:00Z"}
    ])
];
logsWithTimestamps
| mv-apply Events on (
    extend EventName = Events.name,
           EventTime = todatetime(Events.timestamp)
    | project EventName, EventTime
)
```

## Common Patterns

### Filtering elements in arrays

Use `array_where` to filter elements:

```kusto
let numbers = range(1, 10, 1);
print EvenNumbers = array_where(numbers, n => n % 2 == 0)  // [2, 4, 6, 8, 10]
```

### Transforming array elements

Use `array_map` to transform elements:

```kusto
let numbers = range(1, 5, 1);
print Squares = array_map(numbers, n => n * n)  // [1, 4, 9, 16, 25]
```

### Finding unique values

Use `set_union` to get unique values from multiple arrays:

```kusto
let array1 = dynamic([1, 2, 3, 3]);
let array2 = dynamic([3, 4, 5]);
print UniqueValues = set_union(array1, array2)  // [1, 2, 3, 4, 5]
```

### Checking if any/all elements match

Use `array_any` or `array_all` for checking conditions:

```kusto
let numbers = range(1, 5, 1);
print 
    AnyGreaterThan3 = array_any(numbers, n => n > 3),  // true
    AllGreaterThan0 = array_all(numbers, n => n > 0)   // true
```

### Extracting values from object arrays

When working with arrays of objects, extract values using property access:

```kusto
let users = dynamic([
    {"id": 1, "name": "John"},
    {"id": 2, "name": "Jane"},
    {"id": 3, "name": "Bob"}
]);

// Extract names into a new array
print Names = array_map(users, user => user.name)  // ["John", "Jane", "Bob"]
```

## Performance Considerations

1. **Expansion**: Large arrays expanded with `mv-expand` can significantly increase the number of rows
2. **Materialization**: Consider materializing frequently used array elements into dedicated columns
3. **Predicate pushdown**: Apply filters before expanding arrays when possible
4. **Array size**: Very large arrays can impact query performance

## Best Practices

1. Use appropriate array functions rather than custom logic
2. Limit array size when possible to improve performance
3. When working with arrays of objects, consider flattening them into separate columns
4. Apply filters before expanding arrays to reduce the number of rows processed
5. Use array aggregation functions to avoid unnecessary string operations

## Related Topics

- [Dynamic Data Type](dynamic.md)
- [mv-expand Operator](../operators/mv-expand-operator.md)
- [make_list() Aggregation](../functions/makelist-aggregation-function.md)
