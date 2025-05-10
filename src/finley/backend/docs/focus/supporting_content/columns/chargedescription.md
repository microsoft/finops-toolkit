# Column: ChargeDescription

## Example provider mappings

Current resource types found or extracted from available data sets:

| Provider  | Data set                | Column                                            	|
| :-------- | :---------------------- | :-------------------------------------------------------|
| AWS       | CUR                     | lineItem/LineItemDescription 				|
| GCP       | BigQuery Billing Export | sku.description                                         |
| Microsoft | Cost details            | ProductName      			                |

## Example usage scenarios

| Provider  | Data set                | Scenario                           | Value                    |
|:----------|:------------------------|:-----------------------------------|:-------------------------|
| AWS       | CUR                     | Not available                      | $0.00 per GB - US West (Oregon) data transfer from US West (Northern California) |
| GCP       | BigQuery Billing Export | Not available                      | Not Available            |
| Microsoft | Cost details            | via Cost export file		   | Not Available            |

## Guiding Examples

Given that this is a free-form text field, it may be difficult for providers to understand how they should create ChargeDescriptions for their services. The following table grounds out the recommendations above with guiding examples of ChargeDescription values, whether they are recommended, and why or why not.

| Example Value | Recommended | Reason |
| ----------    | ----------- | ------ |
| X3 Compute Core in USA | Yes | Specific, concise, and may be comprehensible even without the  `ServiceName` |
| Class B API Requests | Yes | Specific and concise, even though it might only make sense when combined with the `ServiceName` |
| Foobarsoft OS Licensing Fee | Yes | Specific, concise, and may be comprehensible even without the  `ServiceName` |
| $0.005 for the first 1,000 API requests - Free tier<br/>$0.005 for the next 10,000 API requests<br/>$0.0025 per 1,000 requests thereafter | *No* | Includes pricing which is redundant with another column; has multiple descriptions for the same fundamental usage and has multiple skus for the same fundamental usage |
| Megacloud Compute Platform X3 instances with Intel Core i25. Compute Engine is an awesome service and way better than the others. Use it today and try our Y5 as well! | **No** | Not concise; is essentially marketing copy |
| R3_USAGE | *No* | Opaque SKU ID-type or provider-internal identifier that is not necessarily human readable |
| Usage | *No* | Not specific enough |

## Discussion Topics

### Minimum Information Requirements vs Open-Ended

We deliberated if we should be more specific and define the minimum required information for this column?

- A list of FOCUS columns which we believe provide this high-level context without the need for additional discovery and thus must be included (concatenated) as part of the Charge description? (Irena)
- Are these enough? Region/location? Qty? (Larry)
  - What: lineItem/LineItemDescription
  - Where: Region
  - How (many): Qty

Considering a variable landscape across cloud, SaaS, etc. we decided to keep it open-ended.
