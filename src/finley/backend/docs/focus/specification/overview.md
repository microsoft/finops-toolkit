# Introduction

*This section is non-normative.*

FOCUS aims to establish a community-driven specification for consumption-based billing data. Due to the lack of a broadly adopted specification, infrastructure and services [*providers*](#glossary:provider) have resorted to proprietary billing schemas and terminology. The lack of conformance amongst the billing data generators has forced FinOps practitioners to employ disparate, best-effort schemes which each *practitioner* must develop individually for each *provider* to perform essential FinOps capabilities such as chargeback, cost allocation, budgeting and forecasting.

The FOCUS specification's schema definition and FinOps-aligned terminology provide a clear guide for producing FinOps-serviceable billing datasets. Datasets conforming to FOCUS enable FinOps practitioners to perform common FinOps capabilities, like the ones mentioned above, using a generic set of instructions, regardless of the origin of the dataset.

## Background and History

This project is supported by the [FinOps Foundation][FODO]. This work initially started under the Open Billing working group under the FinOps Foundation. The decision was made in Jan 2023 to begin to migrate the work to a newly formed project under the Linux Foundation called the FinOps Open Cost and Usage Specification (FOCUS) to better support the creation of a specification.

## Intended Audience

This specification is designed to be used by three major groups:

* Billing data generators: Infrastructure and services *providers* that bill based on consumption, such as (but not limited to):
  * [Cloud Service Providers (CSPs)](#glossary:cloud-service-provider)
  * Software as a Service (SaaS) platforms
  * [Managed Service Providers (MSPs)](#glossary:managed-service-provider)
  * Internal infrastructure and service platforms
* FinOps tool *providers*: Organizations that provide tools to assist with FinOps
* FinOps practitioners: Organizations and individuals consuming billing data for doing FinOps

## Scope

The FOCUS working group will develop an open-source specification for billing data. The schema will define data [*dimensions*](#glossary:dimension), [*metrics*](#glossary:metric), a set of attributes about billing data, and a common lexicon for describing billing data.

## Design Principles

The following principles were considered while building the specification.

### FOCUS is an iterative, living specification

* Incremental iterations of the specification released regularly will provide higher value to practitioners and allow feedback as the specification develops. The goal is not to get to a complete, finished specification in one pass.

### Working backward with ease of adoption

* Aim to work backward from essential FinOps capabilities that practitioners need to perform to prioritize the dimensions, metrics and attributes of the cost and usage data that should be defined in the specification to fulfill that capability.
* Be FinOps scenario-driven. Define columns that answer scenario questions; don't look for scenarios to fit a column, each column must have a use case.
* Don't add dimensions or metrics to the specification just because it can be added.
* When defining the specification, consideration should be made to existing data already in the major providers' (AWS, GCP, Azure, OCI) datasets.
* As long as it solves the FinOps use case, there should be a preference to align with data that is already present in a majority of the major providers.
* Strive for simplicity. However, prioritize accuracy, clarity, and consistency.
* Strive to build columns that serve a single purpose, with clear and concise names and values.
* The specification should allow data to be presented free from jargon, using simple understandable terms, and be approachable.
* Naming and terms used should be carefully considered to avoid using terms for which the definition could be confused by the reader. If a term must be used which has either an unclear or multiple definitions, it should be clarified in the [glossary](#glossary).
* The specification should provide all of the data elements necessary for the [Capabilities][FODOFC].

### Provider-neutral approach by default

* While the schema, naming, terminology, and attributes of many providers are reviewed during development, this specification aims to be provider-neutral.
* Contributors must take care to ensure the specification examines how each decision relates to each of the major cloud providers and SaaS vendors, not favoring any single one.
* In some cases, the approach may closely resemble one or more provider's implementations, while in other cases, the approach might be new. In all cases, the FOCUS group (community composed of FinOps practitioners, Cloud and SaaS providers and FinOps vendors) will attempt to prioritize enabling FinOps [Capabilities][FODOFC] and alignment with the FinOps [Framework][FODOF].

### Extensibility

* The initial specification aims to introduce a common schema and terminology for billing datasets produced by Cloud Service Providers (CSPs).
* The specification, however, aims to be extensible to SaaS products and other types of cost datasets.
* Future versions of the specification will look to expand the content to support a broader set of prioritized FinOps capabilities.

## Design Notes

### Optimize for data analysis

* Optimize columns for data analysis at scale and avoid the requirement of splitting or parsing values.
* Avoid complex JSON structures when an alternative columnar structure is possible.
* Facilitate the inclusion of data necessary for a system of record for cost and usage data to consume.

### Consistency helps with clarity

* Where possible, use consistent names that will naturally create associations between related columns in the specification.
* Column naming must strictly follow the [column naming conventions](#columnnamingconvention).
* Use established standards (e.g., ISO8601 for dates, ISO4217 for currency).

## Typographic Conventions

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this specification are to be interpreted as described in [BCP14](https://tools.ietf.org/html/bcp14) [[RFC2119](https://tools.ietf.org/html/rfc2119)][[RFC8174](https://tools.ietf.org/html/rfc8174)] when, and only when, they appear in all capitals, as shown here.

## FOCUS Feature level

Under each column defined in the FOCUS specification, there exists a 'Feature level' designation that describes the column as 'Mandatory', 'Conditional', or 'Optional'. Feature level is designated based on the following criteria described in the normative requirements in each column definition:

* If the existence of a column is described with MUST with no conditions of when it applies, then the feature level is designated as 'Mandatory'.
* If the existence of a column is described as MUST with conditions of when it applies, then the feature level is designated as 'Conditional'.
* If the existence of a column is described as RECOMMENDED, then the feature level is designated as 'Recommended'.
* If the existence of a column is described as MAY, then the feature level is designated as 'Optional'.

## Conformance Checkers and Validators

There are no current resources available to test for specification conformance or validators to run on sample data. When one becomes available, this section of the specification will be updated with details.

[FODO]: https://www.finops.org
[FODOF]: https://www.finops.org/framework/
[FODOFC]: https://www.finops.org/framework/capabilities/
