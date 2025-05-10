# Tags

The Tags column represents the set of tags assigned to [*tag sources*](#glossary:tag-source) that also account for potential provider-defined or user-defined tag evaluations. Tags are commonly used for scenarios like adding business context to cost and usage data to identify and accurately allocate charges. Tags may also be referred to by providers using other terms such as labels.

A tag becomes [*finalized*](#glossary:finalized-tag) when a single value is selected from a set of possible tag values assigned to the tag key.  When supported by a provider, this can occur when a tag value is set by provider-defined or user-defined rules.

The Tags column adheres to the following requirements:

* The Tags column MUST be present in a [*FOCUS dataset*](#glossary:FOCUS-dataset) when the provider supports setting user or provider-defined tags.
* The Tags column MUST contain user-defined and provider-defined tags.
* The Tags column MUST only contain finalized tags.
* The Tags column MUST be in [KeyValueFormat](#key-valueformat).
* A Tag key with a non-null value for a given resource SHOULD be included in the tags column.
* A Tag key with a null value for a given resource MAY be included in the tags column depending on the provider's tag finalization process.
* A Tag key that does *not* support a corresponding value, MUST have a corresponding true (boolean) value set.
* If Tag finalization is supported, providers MUST publish tag finalization methods and semantics within their respective documentation.
* Providers MUST NOT alter user-defined Tag keys or values.

Provider-defined Tags additionally adhere to the following requirements:

* Provider-defined tags MUST be prefixed with a provider-specified tag key prefix.
* Providers SHOULD publish all provider-specified tag key prefixes within their respective documentation.

## Provider-Defined vs. User-Defined Tags

This example illustrates three different tagging scenarios. The first two illustrate when the provider supports both keys and values, while the third is for supporting keys only. The first tag is user-defined and doesn't have a provider prefix. The second tag is provider-defined and has a prefix of `acme/`, which is reserved by the provider. The third tag has a tag key of `baz` and its value is assigned the boolean value `true` since the tag doesn't support a value.

```json
    {
        "foo": "bar",
        "acme/foo": "bar",
        "baz": true,
    }
```

## Finalized Tags

Within a provider, tag keys may be associated with multiple values, and potentially defined at different levels within the provider, such as accounts, folders, [*resource*](#glossary:resource) and other *resource* grouping constructs. When finalizing, *providers* must reduce these multiple levels of definition to a single value where each key is associated with exactly one value. The method by which this is done and the semantics are up to each provider but must be documented within their respective documentation.

As an example, let's assume 1 [*sub account*](#glossary:sub-account) exists with 1 virtual machine with the following details, and tag inheritance favors Resources over *Sub Accounts*.

* Sub Account
  * id: *my-sub-account*
  * user-defined tags: *team:ops*, *env:prod*
* Virtual Machine
  * id: *my-vm*
  * user-defined tags: *team:web*

The table below represents a finalized dataset with these *resources*.  It also shows the finalized state after all resource-oriented, tag inheritance rules are processed.

| ResourceType    | ResourceId     | Tags                                        |
| :---------------| :--------------| :-------------------------------------------|
| Sub Account     | my-sub-account | { "team": "ops", "env": "prod" }            |
| Virtual Machine | my-vm          | { "team": "web", *"env": "prod"* }          |

Because the the Virtual Machine Resource did not have an `env` tag, it inherited tag, `env:prod` (italicized), from its parent *sub account*.  Conversely, because the Virtual Machine Resource already has a `team` tag (`team:web`), it did not inherit `team:ops` from its parent *sub account*.

## Column ID

Tags

## Display Name

Tags

## Description

The set of tags assigned to *tag sources* that account for potential provider-defined or user-defined tag evaluations.

## Content Constraints

|    Constraint   |      Value       |
|:----------------|:-----------------|
| Column type     | Dimension        |
| Feature level   | Conditional      |
| Allows nulls    | True             |
| Data type       | JSON             |
| Value format    | [Key-Value Format](#key-valueformat) |

## Introduced (version)

1.0-preview
