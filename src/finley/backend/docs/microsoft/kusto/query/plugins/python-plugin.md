# Python plugin

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer

The `python()` plugin runs a Python script in the context of the query. The Python script receives tabular data as its input and produces tabular data as its output.

The plugin is invoked with the [evaluate](/en-us/kusto/query/evaluateoperator) operator. The query must specify the schema of the returned tabular data, and the Python code must ensure that the returned data indeed conforms to this schema.

## Syntax

`T | evaluate python(`*output_schema*`,` *script* [`,` *script_parameters*] [`,` *external_artifacts*]`)`

## Parameters

| Name | Type | Required | Description |
|--|--|--|--|
| *output_schema* | string | ✓ | A `typeof` expression that defines the output schema of the tabular data returned by the Python code. |
| *script* | string | ✓ | The Python script to execute. |
| *script_parameters* | dynamic | | A property bag of name/value pairs to be passed to the Python script as the reserved `kargs` dictionary. |
| *external_artifacts* | dynamic | | A property bag of name/URL pairs for artifacts that are made available to the Python script. |

## Python sandbox

The plugin executes in a sandbox - an isolated and secure environment on the Kusto node running the query. The sandbox exposes some commonly used Python libraries and packages.

## The python script

The Python script gets its input table as a [pandas DataFrame](https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.DataFrame.html) called `df`. The script must create a pandas DataFrame or an array of JSON strings called `result` to serve as the result.

## Example

```kusto
range x from 1 to 4 step 1
| evaluate python(
    typeof(*, x4:int),
    'exp = kargs["exp"]\n'
    'result = df\n'
    'result["x4"] = df["x"].pow(exp)\n'
    , bag_pack('exp', 4))
```

Output:

| x | x4 |
|---|---|
| 1 | 1  |
| 2 | 16 |
| 3 | 81 |
| 4 | 256|

## Debugging Python code

To debug Python code embedded in KQL using Visual Studio Code:

1. Run the query with the `set query_python_debug;` statement:

```kusto
set query_python_debug;
range x from 1 to 4 step 1
| evaluate python(typeof(*, x4:int), 
'exp = kargs["exp"]\n'
'result = df\n'
'result["x4"] = df["x"].pow(exp)\n'
, bag_pack('exp', 4))
```

2. Visual Studio Code will launch and allow you to debug the Python code.

For more detailed information on debugging, see [Debug Kusto Query Language inline Python using Visual Studio Code](/en-us/kusto/debug-inline-python?view=microsoft-fabric).
