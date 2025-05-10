# Provider Version

The ProviderVersion MAY be supplied to declare the version of logic by which the [*FOCUS dataset*](#glossary:FOCUS-dataset) was generated and is separate from FOCUS Version. ProviderVersion allows for the provider to specify changes that may not result in a structural change in the data. It is suggested that the provider version use a versioning approach such as [SemVer](https://semver.org) version.

ProviderVersion MUST be of type String and MUST NOT contain null values. If FocusVersion is changed a new ProviderVersion MUST be also changed. The provider MUST document what changes are present in the ProviderVersion.

## Metadata ID

ProviderVersion

## Metadata Name

Provider Version

## Content constraints

| Constraint    | Value            |
|:--------------|:-----------------|
| Feature level | Optional         |
| Allows nulls  | False            |
| Data type     | STRING           |
| Value format  | \<not specified> |

## Introduced (version)

1.1
