# Glossary

<a name="glossary:adjustment"><b>Adjustment</b></a>

A charge representing a modification to billing data to account for certain events or circumstances not previously captured, or captured incorrectly. Examples include billing errors, service disruptions, or pricing changes.

<a name="glossary:amortization"><b>Amortization</b></a>

The distribution of upfront costs over time to accurately reflect the consumption or benefit derived from the associated resources or services. Amortization is valuable when the commitment period (time duration of the cost) extends beyond the granularity of the source report.

<a name="glossary:availability-zone"><b>Availability Zone</b></a>

A collection of geographically separated locations containing a data center or cluster of data centers. Each availability zone (AZ) should have its own power, cooling, and networking, to provide redundancy and fault tolerance.

<a name="glossary:billed-cost"><b>Billed Cost</b></a>

A charge that serves as the basis for invoicing. It includes the total amount of fees and discounts, signifying a monetary obligation. Valuable when reconciling cash outlay with incurred expenses is required, such as cost allocation, budgeting, and invoice reconciliation.

<a name="glossary:billing-account"><b>Billing Account</b></a>

A container for resources and/or services that are billed together in an invoice. A billing account may have sub accounts, all of whose costs are consolidated and invoiced to the billing account.

<a name="glossary:billing-currency"><b>Billing Currency</b></a>

An identifier that represents the currency that a charge for resources and/or services was billed in.

<a name="glossary:billing-period"><b>Billing Period</b></a>

The time window that an organization receives an invoice for, inclusive of the start date and exclusive of the end date. It is independent of the time of usage and consumption of resources and services.

<a name="glossary:block-pricing"><b>Block Pricing</b></a>

A pricing approach where the cost of a particular resource or service is determined based on predefined quantities or tiers of usage. In these scenarios, the Pricing Unit and the corresponding Pricing Quantity can be different from the Consumed Unit and Consumed Quantity.

<a name="glossary:capacity-reservation"><b>Capacity Reservation</b></a>

A capacity reservation is an agreement that secures a dedicated amount of resources or services for a specified period. This ensures the reserved capacity is always available and accessible, even if it's not fully utilized. Customers are typically charged for the reserved capacity, regardless of actual consumption.

<a name="glossary:charge"><b>Charge</b></a>

A row in a FOCUS-compatible cost and usage dataset.

<a name="glossary:chargeperiod"><b>Charge Period</b></a>

The time window for which a charge is effective, inclusive of the start date and exclusive of the end date. The charge period for continuous usage should match the time granularity of the dataset (e.g., 1 hour for hourly, 1 day for daily). The charge period for a non-usage charge with time boundaries should match the duration of eligibility.

<a name="glossary:cloud-service-provider"><b>Cloud Service Provider (CSP)</b></a>

A company or organization that provides remote access to computing resources, infrastructure, or applications for a fee.

<a name="glossary:commitment"><b>Commitment</b></a>

A customer's agreement to consume a specific quantity of a service or resource over a defined period, usually also creating a financial commitment throughout the entirety of the commitment period. Some commitments also hold Providers to certain assurance levels of resource availability.

<a name="glossary:commitment-discount"><b>Commitment Discount</b></a>

A billing discount model that offers reduced rates on preselected SKUs in exchange for an obligated usage or spend amount over a predefined term.  Commitment discount purchases, made upfront and/or with recurring monthly payments are amortized evenly across predefined charge periods (i.e. hourly), and unused amounts cannot be carried over to subsequent charge periods. Commitment discounts are publicly available to customers without special contract arrangements.

<a name="glossary:commitment-discount-flexibility"><b>Commitment Discount Flexibility</b></a>

A feature of [*commitment discounts*](#glossary:commitment-discount) that may further transform the predetermined amount of usage purchased or consumed based on additional, provider-specific requirements.

<a name="glossary:contracted-unit-price"><b>Contracted Unit Price</b></a>

The agreed-upon unit price for a single [Pricing Unit](#pricingunit) of the associated SKU, inclusive of negotiated discounts, if present, and exclusive of any other discounts. This price is denominated in the [Billing Currency](#glossary:billingcurrency).

<a name="glossary:dimension"><b>Dimension</b></a>

A specification-defined categorical attribute that provides context or categorization to billing data.

<a name="glossary:effective-cost"><b>Effective Cost</b></a>

The amortized cost of the charge after applying all reduced rates, discounts, and the applicable portion of relevant, prepaid purchases (one-time or recurring) that covered this charge.

<a name="glossary:exclusivebound"><b>Exclusive Bound</b></a>

A Date/Time Format value that is not contained within the ending bound of a time period.

<a name="glossary:finalized-tag"><b>Finalized Tag</b></a>

A tag with one tag value chosen from a set of possible tag values after being processed by a set of provider-defined or user-defined rules.

<a name="glossary:finops-cost-and-usage-specification"><b>FinOps Cost and Usage Specification (FOCUS)</b></a>

An open-source specification that defines requirements for billing data.

<a name="glossary:FOCUS-dataset"><b>FOCUS Dataset</b></a>

A structured collection of cost and usage data that meets or exceeds the Basic compliance criteria of FOCUS.

<a name="glossary:inclusivebound"><b>Inclusive Bound</b></a>

A Date/Time Format value that is contained within the beginning bound of a time period.

<a name="glossary:interruptible"><b>Interruptible</b></a>

A category of compute resources that can be paused or terminated by the CSP within certain criteria, often advertised at reduced unit pricing when compared to the equivalent non-interruptible resource.

<a name="glossary:list-unit-price"><b>List Unit Price</b></a>

The suggested provider-published unit price for a single [Pricing Unit](#pricingunit) of the associated [SKU](#glossary:sku), exclusive of any discounts. This price is denominated in the [Billing Currency](#glossary:billingcurrency).

<a name="glossary:managed-service-provider"><b>Managed Service Provider (MSP)</b></a>

A company or organization that provides outsourced management and support of a range of IT services, such as network infrastructure, cybersecurity, cloud computing, and more.

<a name="glossary:metric"><b>Metric</b></a>

A FOCUS-defined column that provides numeric values, allowing for aggregation operations such as arithmetic operations (sum, multiplication, averaging etc.) and statistical operations.

<a name="glossary:negotiated-discount"><b>Negotiated Discount</b></a>

A contractual agreement where a customer commits to specific spend or usage goals over a [*term*](#glossary:term) in exchange for discounted rates across varying SKUs.  Unlike [*commitment discounts*](#glossary:commitment-discount), negotiated discounts are typically more customized to customer's accounts, can be utilized at varying frequencies, and may overlap with *commitment discounts*.

<a name="glossary:on-demand"><b>On-Demand</b></a>

A term that describes a service that is available and provided immediately or as needed, without requiring a pre-scheduled appointment or prior arrangement. In cloud computing, virtual machines can be created and terminated as needed, i.e. on demand.

<a name="glossary:pascalcase"><b>Pascal Case</b></a>

Pascal Case (PascalCase, also known as UpperCamelCase) is a format for identifiers which contain one or more words meaning the words are concatenated together with no delimiter and the first letter of each word is capitalized.

<a name="glossary:potato"><b>Potato</b></a>

A long and often painful conversation had by the FOCUS contributors. Sometimes the name of a thing that we could not yet name. No starchy root vegetables were harmed during the production of this specification. We thank potato for its contribution in the creation of this specification.

<a name="glossary:practitioner"><b>Practitioner</b></a>

An individual who performs FinOps within an organization to maximize the business value of using cloud and cloud-like services.

<a name="glossary:price-list"><b>Price List</b></a>

A comprehensive list of prices offered by a provider.

<a name="glossary:provider"><b>Provider</b></a>

An entity that made internal or 3rd party resources and/or services available for purchase.

<a name="glossary:resource"><b>Resource</b></a>

A unique component that incurs a charge.

<a name="glossary:row"><b>Row</b></a>

A row in a FOCUS-compatible cost and usage dataset.

<a name="glossary:service"><b>Service</b></a>

An offering that can be purchased from a provider, and can include many types of usage or other charges; eg., a cloud database service may include compute, storage, and networking charges.

<a name="glossary:sku"><b>SKU</b></a>

A construct composed of the common properties of a product offering associated with one or many SKU Prices.

<a name="glossary:sku-price"><b>SKU Price</b></a>

The unit price used to calculate a charge that is associated with one SKU.  SKU Prices are usually referenced from the provider's price list and are unique to various providers.

<a name="glossary:sub-account"><b>Sub Account</b></a>

A sub account is an optional provider-supported construct for organizing resources and/or services connected to a billing account. Sub accounts must be associated with a billing account as they do not receive invoices.

<a name="glossary:tag"><b>Tag</b></a>

A metadata label assigned to a resource to provide information about it or to categorize it for organizational and management purposes.

<a name="glossary:tag-source"><b>Tag Source</b></a>

A Resource or Provider-defined construct for grouping resources and/or other Provider-defined construct that a Tag can be assigned to.

<a name="glossary:term"><b>Term</b></a>

A duration of a contractual agreement like with a [*commitment discount*](#glossary:commitment-discount) or [*negotiated discount*](#glossary:negotiated-discount).
