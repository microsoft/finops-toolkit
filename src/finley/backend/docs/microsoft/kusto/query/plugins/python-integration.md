# Python Integration with KQL

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

Kusto Query Language (KQL) provides the ability to integrate Python code directly into queries using the `python()` plugin. This integration allows you to leverage the rich ecosystem of Python libraries for advanced analytics, machine learning, and data visualization.

## Overview

The Python plugin enables you to:

1. Use Python libraries that aren't available in native KQL
2. Implement complex algorithms more easily
3. Apply machine learning models
4. Perform advanced statistical analysis
5. Create custom visualizations

## Prerequisites

To use the Python plugin, you need:

1. A cluster with Python support enabled (enabled by default in Microsoft Fabric)
2. Appropriate permissions to run Python code
3. Knowledge of both KQL and Python

## Syntax

```kusto
[T |] python([kickout=<kickout_value>],
            [script=r'''<python_script>'''],
            [sandbox=<sandbox_name>])
[<inline_python_code>]
```

### Parameters

- **kickout**: Optional integer that controls the memory used by the plugin.
- **script**: The Python script as a string literal.
- **sandbox**: Optional name of a custom sandbox with pre-installed Python packages.
- **inline_python_code**: Python code inline after the plugin reference.

## Input Schema and Tabular Data

The Python script receives the tabular data from KQL as a DataFrame in a variable called `df`.

For example, if your KQL query outputs columns `Timestamp`, `Id`, and `Value`, your Python code can access them in the DataFrame:

```python
# Access the columns from the input DataFrame
timestamps = df['Timestamp']
ids = df['Id']
values = df['Value']
```

## Returning Results

The output of your Python script must be a DataFrame. This DataFrame is automatically converted back to a tabular result in KQL.

The last DataFrame assigned to a variable named `result` is returned to KQL:

```python
# Create an output DataFrame
result = pd.DataFrame({
    'Timestamp': timestamps,
    'Id': ids,
    'ProcessedValue': processed_values
})
```

## Example: Basic Data Transformation

```kusto
let data = range x from 1 to 100 step 1;
data
| python()
```
```python
result = df
result["x2"] = df["x"] * 2
result["x3"] = df["x"] * 3
```

## Example: Time Series Analysis with Pandas

```kusto
let timeData = Events
| where Timestamp >= ago(1d)
| project Timestamp, Value;
timeData
| python()
```
```python
import pandas as pd
import numpy as np

# Ensure timestamp is the index
df['Timestamp'] = pd.to_datetime(df['Timestamp'])
df = df.set_index('Timestamp')

# Resample to hourly buckets and calculate stats
hourly = df.resample('1H').agg({
    'Value': ['mean', 'min', 'max', 'count']
})

# Flatten the multi-level columns
hourly.columns = ['_'.join(col).strip() for col in hourly.columns.values]

# Reset index to get Timestamp as a column
result = hourly.reset_index()
```

## Example: Machine Learning with Scikit-learn

```kusto
let trainingData = Events
| where Timestamp < ago(7d) and Timestamp >= ago(14d)
| project Feature1, Feature2, Feature3, Label;
let testData = Events
| where Timestamp >= ago(7d)
| project Feature1, Feature2, Feature3;
trainingData
| python(script=r'''
from sklearn.ensemble import RandomForestClassifier
import pandas as pd

# Split into features and label
X_train = df.drop('Label', axis=1)
y_train = df['Label']

# Train a model
model = RandomForestClassifier(n_estimators=100)
model.fit(X_train, y_train)

# We don't need to return anything from the training
result = pd.DataFrame()
''')
| limit 0; // No output needed for training

testData
| python(script=r'''
from sklearn.ensemble import RandomForestClassifier
import pandas as pd
import pickle

# Get features from test data
X_test = df

# Train a model (in production, you would load a pre-trained model)
model = RandomForestClassifier(n_estimators=100)
# model.fit(X_train, y_train) - training would occur in a previous step

# Make predictions
predictions = model.predict_proba(X_test)[:, 1]  # Probability of positive class

# Create result DataFrame
result = df.copy()
result['PredictedProbability'] = predictions
''')
```

## Debugging Python Code

Debugging Python code embedded in KQL queries can be challenging. You can:

1. Add print statements (output appears in the query execution details)
2. Use Visual Studio Code for debugging by following these steps:
   - Install VS Code and the Python extension
   - Export the input DataFrame to a local file
   - Debug locally, then copy the working code back to KQL

## Supported Python Packages

The Python plugin includes many popular data science packages:

- pandas
- numpy
- scikit-learn
- scipy
- statsmodels
- matplotlib
- seaborn
- tensorflow
- keras
- pytorch
- xgboost
- lightgbm

## Best Practices

1. **Data Volume**: Be mindful of the amount of data processed by the Python plugin. Large datasets can cause performance issues.
2. **Error Handling**: Include error handling in your Python code to prevent query failures.
3. **Code Reuse**: For complex Python code, consider storing it in a KQL function for reuse.
4. **Performance**: Perform as much data filtering and aggregation as possible in KQL before passing data to Python.
5. **Memory Management**: Use the `kickout` parameter to control memory usage.

## Limitations

1. Time limit for script execution (typically 10 minutes)
2. Memory limits based on cluster configuration
3. Network access restrictions (sandbox environment)
4. Custom package installation limitations
5. Performance overhead compared to native KQL operations

## See Also

- [python() plugin reference](plugins/python-plugin.md)
- [Debug inline Python using Visual Studio Code](debug-inline-python.md)
- [Python sandboxes](plugins/python-sandbox.md)
