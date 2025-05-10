# Column: Tags

## Example provider mappings

Current resource types found or extracted from available data sets:

| Provider  | Dataset                 | Column                                      | Hierarchical Resources | Supports Inheritance?
| :-------- | :---------------------- | :-------------------------------------------| :-----------------------------------------------| :----------
| AWS       | CUR                     | resourceTags/user:\*, costCategories/\*       | Organization, Organizational Unit(s), Account | No
| GCP       | BigQuery Billing Export | tags, labels, system_labels, project.labels   | Folder(s), Project                            | Yes
| Microsoft | Cost details            | Tags | Billing Account, Billing Profile, Invoice Section, Department, Enrollment Account, Management Group, Subscription, Resource Group | Yes
| OCI       | Cost reports            | tags/\*                                          | Organization, Tenancy, Compartment            | Yes

## Documentation
- AWS - [Resource tags details](https://docs.aws.amazon.com/cur/latest/userguide/resource-tags-columns.html)
- Azure - [Usage details](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields#list-of-fields-and-descriptions)
- GCP - [Billing reports](https://cloud.google.com/billing/docs/how-to/reports#columns-in-csv)
- OCI - [Cost reports](https://docs.public.oneportal.content.oci.oraclecloud.com/en-us/iaas/Content/Billing/Concepts/usagereportsoverview.htm)


## Discussion Topics

Discussion / Scratch space:
- Finalized section may or may not be necessary because providers would only provide finalized tags
	- Remove 'finalized' from first sentence of Tags 
- User-defined tags should not have a prefix
- Provider can create and account for a reserved prefix set
- Providers should publish known prefixes somewhere
	- Refer to Numeric Attribute language around provider-publishing guidelines
- Separator poll?
	- Double forward slash (Chris Harris)
	- Pipe (Shawn Alpay)
- 2 columns: EffectiveTags and RawTags (better names to be decided)
- Tags
	- Providers must account for collisions
	- If inheritance exists for a set of tags, provide the “winning” tag
	- If inheritance does not exist for a tag, provide all namespaced tags (i.e. costCategory/foo, resourceTags/user:foo)
	- MUST adhere to the Key-Value attribute spec

- Questions:
	- Inheritance (e.g., source)?
	- Merging different datasets (e.g., source)?
	- Do we split effective tags and raw tags or merge them together with a predefined key format (e.g., “<source>/<key>”)?
	- Simple JSON key/value pair or array of JSON objects?
	- What does it look like interpreting labels using Excel formulas only? Would users be required to dl a plugin, use vbscript, etc.
		- Excel: https://support.microsoft.com/en-au/office/parse-text-as-json-or-xml-power-query-7436916b-210a-4299-83dd-8531a1d5e945 (supports {"foo": "bar"} approach)
		- Sheets: Seems to require scripting
	- How do we fit into the top 3 clouds?
	- Should we give an opinion around requiring k/v tags?
	- Create a poll around calling the dimension “Tags” or “Labels”?
		- “Custom Tags/Labels”?
		- One key/value pair for all tags “tags”: [ … ]
	- Which raw format do we go with?
    	- After much discussion and exploring multiple different options, and formats, the following were decided:
        	- Tags are presented in a json structure - key/value (tags) and key-only (labels) are both included using the same json object.
        	- Labels will be shown with a value of true (boolean not string). Other options were to break labels out into a separate column, separate part of the JSON object, or provide inline with null OR the boolean    	- 
