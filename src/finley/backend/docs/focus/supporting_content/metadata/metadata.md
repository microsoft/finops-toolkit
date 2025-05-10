# Metadata Example API

## Example Data Generator Metadata

In this example the billing data generator's FOCUS metadata API is queried for the provider metadata.

#### Endpoint: <api_root>/FOCUS/metadata/data_generator
#### Example Request:

    Method: GET 
    Endpoint : <api_root>/FOCUS/metadata/data_generator
####

#### Response
```
{
	"DataGenerator": "awesome_corp"
}`
```

## Example Schema Metadata

In this example, the billing data includes two different structures of data. An older schema for data previously provided, and a newer schema for more recent data. Both schemas metata is provided. 

### API

#### Endpoint: <api_root>/FOCUS/metadata/schemas 
#### Example Request:
    endpoint: <api_root>/FOCUS/metadata/schemas 
    method: GET 
####

#### Response 
```
{
	[
		{
			"FocusVersion": "1.0",
			"name": "my original schema",
			"CreationDate": "2024-01-01T12:01:03.083z"
			"schema_column_endpoint": <api_root>/FOCUS/metadata/schemas/1234/columns
		},
		{
			"FocusVersion": "1.1",
			"name": "my new schema",
			"CreationDate": "2024-07-01T12:00:04.001z"
			"schema_column_endpoint": <api_root>/FOCUS/metadata/schemas/2345/columns
		}
	]
}
```

## Example Schema Column Definition Metadata

In this example the billing data generator's FOCUS metadata API is queried for the schema_id = 1234. 

### API Schema 

#### Endpoint: <api_root>/FOCUS/metadata/schema/{id}/columns
#### Example Request:

    Method: GET 
    Endpoint : <api_root>/FOCUS/metadata/schema/1234/columns
####

#### Response 
```
{
	"FOCUS_version": "1.0",
	"name": "my original schema",
	"CreationDate": "2024-01-01T12:01:03.083z"
	"ColumnDefinition": [
		{
			"ColumnName": "BillingAccountId",
            		"DataType": "STRING",
            		"StringMaxLength: 64,
            		"StringEncoding: "UTF-8"
        	},
        	{
            		"ColumnName: "BillingAccountName",
            		"DataType: "STRING"
            		"StringMaxLength: 64,
            		"StringEncoding: "UTF-8"
	        },
	        {
	           	 "ColumnName: "ChargePeriodStart",
	           	 "DataType: "DATETIME"
	        },
	        {
	            	"ColumnName: "ChargePeriodEnd",
	            	"DataType: "DATETIME"
	        },
	        {
	            	"ColumnName: "BilledCost",
	            	"DataType: "DECIMAL",
	            	"NumericPrecision: 20,
	            	"NumberScale: 10
	        },
	        {
	            	"ColumnName: "EffecitiveCost",
	            	"DataType: "DECIMAL",
	            	"NumericPrecision: 20,
	            	"NumberScale: 10
	        },
	        {
	            	"ColumnName": "Tags",
	            	"DataType": "JSON",
	            	"ProviderTagPrefixes": ["awecorp", "ac"]
	        }
    	]
}
```

## Example Schema Reference Metadata

In this example, when the provider returns the FOCUS data they include in the response a reference to the schema utilized in the FOCUS dataset. 

#### Example Request:
    Endpoint: <api_root>/FOCUS/data/2024010001
    Method: GET 
####

#### Response
```
{
	"data": [
             ...
         ]
}
```
