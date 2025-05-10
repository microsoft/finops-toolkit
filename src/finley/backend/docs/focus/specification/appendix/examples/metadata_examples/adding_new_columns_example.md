# Adding New Columns

## Scenario

ACME has decided add additional columns to their FOCUS data export. The new columns are x_awesome_column1, x_awesome_column2, and x_awesome_column3. The provider creates a new [Schema](#schema) object to represent the new schema, this schema object has a unique [SchemaId](#schemaid). The subsequent data exports that use the new schema include the new schema's id as a reference to their corresponding schema object.

## Supplied Metadata

Metadata can be provided at a location such as `/FOCUS/metadata/schemas/schema-23456-abcde-23456-abcde-23456.json`.

The updated schema related metadata could look like this:

```json
 {
  "SchemaId": "23456-abcde-23456-abcde-23456",
  "FocusVersion": "1.0",
  "CreationDate": "2024-02-02T12:01:03.083z",
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
                "ProviderTagPrefixes": ["awecorp", "ac"]
          },
          {
                "ColumnName": "x_awesome_column1",
                "DataType": "STRING",
                "StringMaxLength": 64,
                "StringEncoding": "UTF-8"
          },
          {
                "ColumnName": "x_awesome_column2",
                "DataType": "DATETIME"
          },
          {
                "ColumnName": "x_awesome_column3",
                "DataType": "STRING",
                "StringMaxLength": 64,
                "StringEncoding": "UTF-8"
          }
      ]
}
```

For an example of how ACME ensures the schema metadata reference requirement is met see: [Schema Metadata to FOCUS Data Reference](#schemametadatatofocusdatareference)
