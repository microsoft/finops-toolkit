# Provider Tag Prefixes

The Provider Tag Prefixes defines the list of prefixes used in the tag name of provider-defined [tags](#tags). This metadata is useful for the consumer to identify which tags are provider-defined vs user-defined.

The ProviderTagPrefixes MUST be provided when ColumnName is equal to Tags. The ProviderTagPrefix MUST be of type Array of Strings. The ProviderTagPrefixes SHOULD be easily associated with the provider who generated the [*FOCUS dataset*](#glossary:FOCUS-dataset).

## Metadata ID

ProviderTagPrefixes

## Metadata Name

Provider Tag Prefixes

## Content constraints

| Constraint    | Value                               |
|:--------------|:------------------------------------|
| Feature level | Conditional                         |
| Allows nulls  | False                               |
| Data type     | Array                               |
| Value format  | STRING datatype values in the array |

## Introduced (version)

1.0
