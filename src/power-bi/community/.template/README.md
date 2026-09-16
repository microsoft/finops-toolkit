# [Report Name]

> [!NOTE]
> This is a **community report** maintained by [contributor name/organization]. It is not an official FinOps toolkit report and is provided "AS IS" without warranty. For questions or issues, please contact the maintainer listed in CONTRIBUTORS.md.

**Last updated:** YYYY-MM-DD  
**Author:** [Your Name or Organization]  
**Contact:** [GitHub handle or email]

<br>

## Overview

[Provide a clear, concise description of what this report does and who it's for. Include the specific FinOps use case or capability this report addresses.]

### FinOps use case

**Primary capability:** [e.g., Cost allocation, Rate optimization, Workload optimization]  
**Target persona:** [e.g., FinOps practitioners, Engineering teams, Finance teams]  
**Industry/scenario:** [e.g., General purpose, SaaS companies, Enterprises with chargebacks]

### Key features

- [Feature 1: e.g., Chargeback by department with custom allocation rules]
- [Feature 2: e.g., Trend analysis across multiple subscriptions]
- [Feature 3: e.g., Integration with custom tagging strategy]
- [Add more features as needed]

<br>

## Screenshots

[Include 2-3 screenshots showcasing the key pages/features of your report]

![Report overview](images/screenshot-overview.png)
_Caption describing what this page shows_

![Detailed view](images/screenshot-detail.png)
_Caption describing what this page shows_

<br>

## Prerequisites

Before using this report, ensure you have:

- **Power BI Desktop** - [Download latest version](https://powerbi.microsoft.com/desktop/)
- **Power BI license** - [Specify: Free, Pro, or Premium required]
- **Data sources configured** - [List required data sources]
  - Cost Management exports (FOCUS format) - Required
  - [Any other data sources]
- **Azure access** - [Specify required permissions]
- **[Any other prerequisites]**

<br>

## Data sources

This report connects to the following data sources:

### Primary data source

**[Data Source Name]** (e.g., Cost Management FOCUS exports)
- **Type:** [e.g., Azure Data Lake Storage, Azure Data Explorer]
- **Required exports:** [e.g., Cost and usage (FOCUS), Price sheet]
- **Configuration:** [Brief description or link to setup guide]

### Additional data sources (if applicable)

**[Additional Data Source]**
- **Type:** [Source type]
- **Purpose:** [Why this data is needed]
- **Configuration:** [Setup instructions]

<br>

## Setup instructions

Follow these steps to configure and use this report:

### 1. Download the report

Download the report files from this directory:
- `report.pbit` - Power BI template file (recommended for first-time setup)
- `report.pbix` - Power BI file with sample data (for preview)

### 2. Configure data sources

[Provide detailed step-by-step instructions for setting up data sources]

1. Open the .pbit file in Power BI Desktop
2. When prompted, enter the following parameters:
   - **Storage URL:** The DFS endpoint of your storage account (e.g., `https://mystorageaccount.dfs.core.windows.net`)
   - **[Parameter 2]:** [Description]
   - **[Parameter 3]:** [Description]

### 3. Authenticate to data sources

[Explain how to authenticate to each data source]

1. When prompted, select the authentication method:
   - For storage accounts: Use **Account key** or **Organizational account**
   - [Other data sources]
2. Click **Connect**

### 4. Refresh the data

[Explain the refresh process]

1. Click **Refresh** in the Home ribbon
2. Wait for the refresh to complete (this may take [estimated time] depending on data volume)

### 5. Customize the report (optional)

[Explain any customization options]

- **Filters:** [How to configure filters]
- **Parameters:** [How to adjust parameters]
- **Visuals:** [How to customize visuals]

<br>

## Report pages

Brief description of each page in the report:

### [Page 1 Name]

[Description of what this page shows and how to use it]

### [Page 2 Name]

[Description of what this page shows and how to use it]

### [Additional pages...]

<br>

## Known limitations

- **Limitation 1:** [e.g., Performance may degrade with datasets larger than 10GB]
- **Limitation 2:** [e.g., Requires specific tag structure (Department, Project, Environment)]
- **Limitation 3:** [e.g., Custom visuals may require separate installation]
- [Add any other limitations or known issues]

<br>

## Troubleshooting

### Common issues

**Issue: [Common problem users might encounter]**
- **Cause:** [Why this happens]
- **Solution:** [How to fix it]

**Issue: [Another common problem]**
- **Cause:** [Why this happens]
- **Solution:** [How to fix it]

### Getting help

If you encounter issues not covered here:

1. Check the [FinOps toolkit documentation](https://aka.ms/finops/toolkit)
2. Review [closed issues](https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aclosed+label%3Acommunity-report) for similar problems
3. Contact the report maintainer (see CONTRIBUTORS.md)
4. Open a [new issue](https://github.com/microsoft/finops-toolkit/issues/new/choose) with the `community-report` label

<br>

## Support and maintenance

This report is maintained by the community contributor(s) listed in CONTRIBUTORS.md. 

- **Maintainer:** [Name/Organization]
- **Contact:** [GitHub handle or email]
- **Response time:** [e.g., Best effort, typically within 1 week]
- **Update frequency:** [e.g., Quarterly, as needed]

For issues, questions, or feature requests, please contact the maintainer or open an issue on GitHub.

<br>

## Version history

### [Current Version] - YYYY-MM-DD

- Initial release
- [Key features or changes]

<!-- Add new versions here as the report is updated -->

<br>

## License

This report is licensed under the [MIT License](../../../../LICENSE), consistent with the FinOps toolkit.

<br>

## Acknowledgments

[Optional: Credit any third-party resources, inspirations, or contributors]

- [Resource or person to acknowledge]
- [Resource or person to acknowledge]

<br>

---

_This is a community-contributed report. It is not officially maintained by Microsoft or the FinOps toolkit team. For official reports, see the [FinOps toolkit Power BI reports](../../README.md)._
