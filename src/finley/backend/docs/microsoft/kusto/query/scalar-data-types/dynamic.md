# dynamic data type

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

The `dynamic` data type is special in that it can take on any value from the other scalar data types, as well as arrays and property bags (similar to JSON objects).

## Overview

The `dynamic` type is particularly useful for representing:

- JSON data
- Semi-structured or unstructured data
- Data with varying schemas
- Nested data structures

## dynamic literals

Literals of type `dynamic` can be created using JSON notation:

### Arrays

```kusto
dynamic([1, 2, 3, 4])
dynamic(["this", "is", "an", "array"])
dynamic([1, "a", 2.0])
```

### Property bags (objects)

```kusto
dynamic({"name": "John", "age": 30})
dynamic({"key": "value", "items": [1, 2, 3]})
```

### Mixed types

```kusto
dynamic({"users": [{"name": "John"}, {"name": "Jane"}]})
```

## Working with dynamic values

### Accessing array elements

Elements in a dynamic array are zero-indexed and can be accessed using square brackets:

```kusto
let arr = dynamic([10, 20, 30, 40]);
print 
    FirstElement = arr[0],  // 10
    SecondElement = arr[1], // 20
    Length = array_length(arr)  // 4
```

### Accessing property bag properties

Properties in a dynamic property bag can be accessed using dot notation or square brackets:

```kusto
let person = dynamic({"name": "John", "age": 30, "address": {"city": "Seattle"}});
print 
    Name = person.name,  // "John"
    Age = person["age"], // 30
    City = person.address.city  // "Seattle"
```

## Type conversions

You can convert dynamic values to specific types using conversion functions:

```kusto
let value = dynamic({"name": "John", "age": 30});
print 
    Name = tostring(value.name),
    Age = toint(value.age)
```

The following functions are useful for dynamic type conversions:

- `tostring()` - Converts to string
- `toint()` - Converts to integer
- `tolong()` - Converts to long
- `todouble()` - Converts to double
- `tobool()` - Converts to boolean
- `totimespan()` - Converts to timespan
- `todatetime()` - Converts to datetime

## Functions for working with dynamic values

Kusto provides numerous functions for working with dynamic values:

### Array functions

- `array_length()` - Returns the number of elements in a dynamic array
- `array_contains()` - Checks if an array contains a specified value
- `array_index_of()` - Returns the index of a value in an array
- `array_concat()` - Concatenates multiple arrays
- `range()` - Creates an array of sequential numbers
- `mv-expand` - Expands array elements into rows

Example:

```kusto
let arr1 = dynamic([1, 2, 3]);
let arr2 = dynamic([4, 5, 6]);
print 
    CombinedArray = array_concat(arr1, arr2),  // [1, 2, 3, 4, 5, 6]
    ContainsTwo = array_contains(arr1, 2)      // true
```

### Property bag functions

- `bag_keys()` - Returns the names of all root-level properties
- `bag_merge()` - Merges property bags
- `pack()` - Creates a property bag from key-value pairs
- `bag_pack()` - Creates a property bag from key-value pairs (alias of `pack()`)
- `pack_all()` - Creates a property bag from all columns

Example:

```kusto
let person = dynamic({"name": "John", "age": 30});
let details = dynamic({"height": 180, "weight": 75});
print 
    Keys = bag_keys(person),  // ["name", "age"]
    MergedBag = bag_merge(person, details)  // {"name": "John", "age": 30, "height": 180, "weight": 75}
```

## Common operations

### Filtering on dynamic fields

```kusto
Table
| where Properties.Level == "Error"
| where array_contains(Tags, "critical")
```

### Expanding arrays into rows

```kusto
Table
| mv-expand Tags
| where Tags == "critical"
```

### Creating dynamic values

```kusto
Table
| extend 
    User = pack("name", UserName, "id", UserId, "roles", Roles),
    RequestInfo = pack("url", Url, "method", Method, "statusCode", StatusCode)
```

### Conditional access

```kusto
Table
| extend ErrorDetails = iff(Properties.hasError == true, Properties.errorDetails, dynamic(null))
```

## Performance considerations

1. **Indexing**: Dynamic columns are not indexed by default, which can impact query performance
2. **Materialization**: Consider materializing frequently used properties into dedicated columns
3. **Type safety**: Using `dynamic` can bypass type checking, making errors harder to detect

## Best practices

1. **Explicit typing**: Convert dynamic values to specific types using conversion functions
2. **Error handling**: Check for null or missing properties before accessing them
3. **Schema evolution**: Use dynamic type for fields that might change schema over time
4. **Column extraction**: Extract frequently accessed properties into dedicated columns for better performance
5. **Validation**: Validate dynamic structures before processing to avoid runtime errors

## Related data types

- [string](string.md) - For text data
- [long](long.md) - For 64-bit integers
- [datetime](datetime.md) - For date and time values
- [timespan](timespan.md) - For time intervals
