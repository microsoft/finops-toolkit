# Debug Kusto Query Language Inline Python Using Visual Studio Code

Applies to: Microsoft Fabric, Azure Data Explorer

You can embed Python code in Kusto Query Language queries using the `python()` plugin. The plugin runtime is hosted in a sandbox, an isolated and secure Python environment. The python() plugin capability extends Kusto Query Language native functionalities with the huge archive of OSS Python packages. This extension enables you to run advanced algorithms, such as machine learning, artificial intelligence, statistical, and time series as part of the query.

Kusto Query Language tools aren't convenient for developing and debugging Python algorithms. Therefore, develop the algorithm on your favorite Python-integrated development environment such as Jupyter, PyCharm, Visual Studio, or Visual Studio Code. When the algorithm is complete, copy and paste into KQL. To improve and streamline this workflow, Kusto Explorer or Web UI clients can integrate with Visual Studio Code for authoring and debugging KQL inline Python code.

> **Note**: This workflow can only be used to debug relatively small input tables (up to few MB). Therefore, you may need to limit the input for debugging. If you need to process a large table, limit it for debugging using `| take`, `| sample`, or `where rand() < 0.x`.

## Prerequisites

1. A workspace with a Microsoft Fabric-enabled capacity.
2. A database. Create a KQL database.
3. Install Python Anaconda Distribution. In **Advanced Options**, select **Add Anaconda to my PATH environment variable**.
4. Install Visual Studio Code.
5. Install Python extension for Visual Studio Code.
6. Enable the Python plugin.

## Query Example

1. Run the following KQL query in your client application:

```kusto
range x from 1 to 4 step 1
| evaluate python(typeof(*, x4:int), 
'exp = kargs["exp"]\n'
'result = df\n'
'result["x4"] = df["x"].pow(exp)\n'
, bag_pack('exp', 4))
```

See the resulting table:

| x | x4 |
| --- | --- |
| 1 | 1 |
| 2 | 16 |
| 3 | 81 |
| 4 | 256 |

2. Run the same KQL query in your client application using `set query_python_debug;`:

```kusto
set query_python_debug;
range x from 1 to 4 step 1
| evaluate python(typeof(*, x4:int), 
'exp = kargs["exp"]\n'
'result = df\n'
'result["x4"] = df["x"].pow(exp)\n'
, bag_pack('exp', 4))
```

3. Visual Studio Code is launched and allows debugging and printing 'result' dataframe in the debug console.

> **Note**: There may be differences between the Python sandbox image and your local installation. Check the sandbox image for specific packages by querying the plugin.

> **Note**: In case there are errors when launching Visual Studio Code debugging session try setting the default terminal profile to command prompt:
> 1. Press CTRL + SHIFT + P to open the Command Palette.
> 2. Search for "Terminal: Select Default Profile" and select "Command Prompt"
