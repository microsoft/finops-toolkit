# Changing Column Metadata

## Scenario

ACME has decided to change the datatype of column x_awesome_column1 from a string to a number. ACME creates a new [Schema](#schema) object with the modification to x_awesome_column2.

## Supplied Metadata

Metadata can be provided at a location such as `/FOCUS/metadata/schemas/schema-67891-abcde-67891-abcde-67891.json`.

The updated schema related metadata could look like this:

```json
 {
  "SchemaId": "67891-abcde-67891-abcde-67891",
  "FocusVersion": "1.0",
  "CreationDate": "2024-06-02T12:01:03.083z",
  "ColumnDefinition": [
    {
      "ColumnName": "BillingAccountId",
                "DataType": "STRING",
                "StringMaxLength": 64,
                "StringEncoding": "UTF-8"
          },
          {
                "ColumnName": "BillingAccountName",
                "DataType": "STRING",
                "StringMaxLength": 64,
                "StringEncoding": "UTF-8"
          },
          {
               "ColumnName": "ChargePeriodStart",
               "DataType": "DATETIME"
          },
          {
                "ColumnName": "ChargePeriodEnd",
                "DataType": "DATETIME"
          },
          {
                "ColumnName": "BilledCost",
                "DataType": "DECIMAL",
                "NumericPrecision": 20,
                "NumberScale": 10
          },
          {
                "ColumnName": "EffectiveCost",
                "DataType": "DECIMAL",
                "NumericPrecision": 20,
                "NumberScale": 10
          },
          {
                "ColumnName": "Tags",
                "DataType": "JSON",
                "ProviderTagPrefixes": ["acme", "ac"]
          },
          {
                "ColumnName": "x_awesome_column1",
                "DataType": "DECIMAL",
                "NumericPrecision": 20,
                "NumberScale": 10
          },
          {
                "ColumnName": "x_awesome_column2",
                "DataType": "DATETIME"
          }
      ]
}
```

For an example of how ACME ensures the schema metadata reference requirement is met see: [Schema Metadata to FOCUS Data Reference](#schemametadatatofocusdatareference)
