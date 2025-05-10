# Date/Time Format

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                               |
|:----------|:-------------------------|:-----------------------------------------------------|
| AWS       | CUR                      | lineItem/UsageStartDate, lineItem/UsageEndDate, etc. |
| GCP       | Big Query Billing Export | usage_start_time, usage_end_time, etc.               |
| Microsoft | Cost details             | date, etc.                                           |
| OCI       | Cost reports             | lineItem/intervalUsageStart, lineItem/intervalUsageEnd |

### Documentation

* AWS: [Line item details - AWS Cost and Usage Reports](https://docs.aws.amazon.com/cur/latest/userguide/Lineitem-columns.html#Lineitem-details-U)
* GCP: [Structure of Standard data export | Cloud Billing](https://cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage)
* Microsoft: [Understand usage details fields - Microsoft Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields)

## Example usage scenarios

Current values observed in billing data for various scenarios:

| Provider  | Data set                                        | Example Value           |
|:----------|:------------------------------------------------|:------------------------|
| AWS       | CUR                                             | 2023-05-13T21:00:00Z    |
| GCP       | Big Query Billing Export                        | 2023-05-13 21:00:00 UTC |
| Microsoft | Cost details via Consumption API (usageDetails) | 2023-05-13T00:00:00Z    |
| Microsoft | Cost details via Cost export file               | 05/13/2023              |
| OCI       | Cost reports                                    | 2022-08-19T01:00Z       |

## Discussion / Scratch space

* Date related dimension in Microsoft Cost Management exports are not aligned with ISO 8601 and those provided in Consumption Usage Details API are (Note: the API will be retired at some point)
* Dates should always be accompanied by time and timezone components to avoid ambiguity. Will result in more space usage but the additional clarity is justified
* Oddities in date/time/timezone
  * Azure currently provides daily-level data without hourly granularity.
  * GCP uses PST for timezone.
* All date/time columns currently defined in the FOCUS specification (scope of FOCUS v0.5) provide information about a specific point in time. For this purpose, the extended format with separators (hyphens and colons) was chosen (provides consistency and improved readability). When and if the need arises, additional formats will be specified (e.g., for date/time intervals, duration, etc.).
* The ISO 8601 format supports various precision levels. Since it is most commonly used, FOCUS specification opted for the seconds precision level ('YYYY-MM-DDTHH:mm:ssZ'). If required, other precision levels (e.g., minutes, milliseconds, or microseconds) can also be introduced.
