# Column naming convention

## Example provider mappings

Examples of column names found in provider datasets:

| Provider  | Data set                 | Column                |
| --------- | ------------------------ | --------------------- |
| AWS       | CUR                      | bill_invoicing_entity |
| GCP       | Big Query Billing Export | resource.global_name  |
| Microsoft | Cost details             | ResourceId            |
| OCI       | Cost reports             | product/resourceId    | 

## Discussion / Scratch space

* Discussed the need for naming convention to apply to FOCUS columns
* Group wanted to get naming convention adopted broadly for provider columns as well, to simplify reporting and analysis by practitioners
* Different conventions like camel case, snake case, and title case were considered
* Discussion included different columns naming conventions used by databases

### How to handle custom columns

* Providers need to add additional details that are not available in FOCUS columns to support additional FinOps scenarios.
* FOCUS needs to allow the addition of these columns without the risk of collision with future FOCUS columns.
* Considerations:
  * **Placement (prefix vs. suffix):**
    * A prefix would be easier to identify as a custom column even with limited space.
    * A suffix would require expanding the column or explicitly looking at the end of the column name, which can be difficult is some client tools where the end of the name gets cut off.
    * BEST: **Prefix**.
  * **Separator character:**
    * Should be easily identifiable as a separator.
      * Common: `_`, `-`, `.`, `:`. `@`, `/`, `~`, `|`, `+`, `=`, `;`
      * Uncommon: `$`, `&`, `#`, `!`, `?`, `*`
    * Should avoid characters that don't work in most tools or programming languages, since they would need to divert from the spec.
      * Can be used in variable names: `_`
      * Can be logically handled via nesting: `.`, `/`, `:`
      * Limited support: `-`, `$`, `@`, `#`. `~`
    * Prefer characters that are commonly used in spreadsheet and database column names.
      * Common: `_`, `.`, `/`
      * Uncommon: `-`, `:`. `~`, `+`, `$`, `#`
    * BEST: **Underscore** (`_`).
  * **Identifying string (FOCUS vs. provider-specific vs. constant vs. none):**
    * A FOCUS prefix allows providers to add FOCUS columns to existing datasets without breaking anyone, which could make adoption simpler
      * Examples: `FOCUS_`, `focus_`, `f_`
      * This would double the size of the dataset as new columns are added.
      * It's unlikely that any provider will add FOCUS columns to an existing datasets without an explicit opt-in, which means we likely wouldn't see the benefit of this approach since practitioners still need to opt-in and change their reporting.
      * This makes the spec feel like it's a supplemental thing, rather than the primary thing that should be used.
      * Practitioners will need to explicitly switch to the new columns anyway, so the value of augmenting existing provider-specific datasets provides little to no value.
      * In general, this isn't approach any other open specification tasks for its primary dataset.
      * Prefixing custom columns establishes FOCUS as _the_ schema and custom columns as the exceptional thing that should be caveated.
    * A provider ID would make the source of the data easily identifiable, but requires every provider to have new columns which would bloat the column count of a consolidated dataset.
      * Examples: `ali_`, `aws_`, `gcp_`, `ibm_`, `ms_`, `oci_`, `tencent_`, `vmw_`
      * If we use a provider prefix, there are concerns about conflicting names that would require a registration system, which is a lot of work.
      * Ultimately, there shouldn't be a need to use custom prefixes since provider-specific columns will never conflict due to data being in separate rows.
    * A constant string would allow providers to reuse column names, but would make column names longer. This might also look like a FOCUS column if capitalized in the same way.
      * Examples: `Custom_`, `External_`, `Provider_`, `Vendor_`
    * A lowercase constant string would distinguish it from FOCUS column naming conventions, but could still make column names exceedingly long.
      * Examples: `custom_`, `provider_`, `vendor_`
    * An abbreviated or very short constant string would keep names short, but goes against the no abbreviations rule.
      * Examples: `alt_`, `aux`, `col_`, `dim_`, `ext_`, `m_`, `oth_`, `p_`, `src_`, `x_`
    * Using a single character alone would be the shortest and would distinguish it from the FOCUS columns that don't have a prefix.
      * Examples: `_`, `.`, `~`, `$`, `#`, `@`
      * Using a special character first would also keep all provider columns together outside of the core FOCUS columns when columns are sorted alphabetically.
      * Some programming languages use an underscore (`_`) as a convention to indicate that a property is private. While these values are not "private", it might be a good way to indicate that these columns are not part of the core FOCUS columns.
    * BEST: **x_**.

Examples:

* ms_BillingAccountType
* Provider_BillingAccountType
* provider_BillingAccountType
* custom_BillingAccountType
* \_BillingAccountType
