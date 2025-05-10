# Column: ChargePeriod(Start|End)

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                | Provider column                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| :-------- | :---------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AWS       | CUR                     | line_item_usage_start_date<br>line_item_usage_end_date                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| GCP       | BigQuery Billing Export | From the BigQuery billing export, every row has two dates:<br><br>- usage_start_time - TIMESTAMP<br> 2018-07-02 03:00:00 UTC<br>- usage_end_time - TIMESTAMP<br> 2018-07-02 04:00:00 UTC<br><br>The start time is inclusive and the end time is exclusive. The moment defined by usage_end_time is then used to define a usage_start_time for subsequent cost rows.<br>In addition to these two fields, there is usage data that could have an impact on usage duration and measuring a usage period:<br>- usage.amount<br>- usage.unit<br>- usage.amount_in_pricing_units<br>- usage.pricing_unit |
| Microsoft | Cost details            | Azure cost export contains a “date” field with the assumption that the cost details. <br><br>This date field is a Timestamp with 00:00:00 UTC time.<br>2018-07-03 00:00:00UTC                                                                                                                                                                                                                                                                                                                                                                                                                      |
| OCI       | Cost reports            | lineItem/intervalUsageStart<br>lineItem/intervalUsageEnd                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

## Example usage scenarios

Current values observed in billing data for various scenarios:

See [Date/Time Format](../attributes/datetime_format.md) for examples

## Discussion Topics

- How does this relate to the billing period?
  - Billing period is the time period where you get billed. Usage start period will be in the billing period range.
  - Can you pre-pay for something where you don't start the usage for future periods
    - Is there a term even when the provider is being flexible with the start/end
    - Check with Tim / Tatiana for examples
- Is Charge Period End required?
  - Yes, clearer if they are both specified. Otherwise it depends on granularity of the billing data per provider (some might be hourly, others monthly etc.)
- Dates in UTC format?
  - Yes, reference the attribute for date/time format
