# Data Changed by Provider Using Provider Version

## Scenario

ACME specifies the optional metadata property [Provider Version](#providerversion) in their [Schema](#schema) object. They made a change to the [*FOCUS dataset*](#glossary:FOCUS-dataset) they produce that does not adopt a new FOCUS Version, nor make a change the included columns but does impact values in the data. This example illustrates that Provider Version changes are independent of column changes, however provider version changes may include column changes.

The provider creates a new schema object to represent the new schema. The provider includes both the FOCUS Version and Provider Version in the schema object.

## Supplied Metadata

Metadata can be provided at a location such as `/FOCUS/metadata/schemas/schema-56789-abcde-56789-abcde-56789.json`.

The updated schema related metadata could look like this:

```json
 {
  "SchemaId": "56789-abcde-56789-abcde-56789",
  "FocusVersion": "1.1",
  "ProviderVersion": "2.4",
  "CreationDate": "2024-05-02T12:01:03.083z",
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
                "DataType": "STRING",
                "StringMaxLength": 64,
                "StringEncoding": "UTF-8"
          },
          {
                "ColumnName": "x_awesome_column2",
                "DataType": "DATETIME"
          }
      ]
}
```

For an example of how ACME ensures the schema metadata reference requirement is met see: [Schema Metadata to FOCUS Data Reference](#schemametadatatofocusdatareference)
