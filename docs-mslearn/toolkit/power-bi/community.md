---
title: Community Power BI reports
description: Learn about community-contributed Power BI reports for FinOps in the FinOps toolkit and how to contribute your own reports.
author: flanakin
ms.author: micflan
ms.date: 10/10/2025
ms.topic: how-to
ms.service: finops
ms.subservice: finops-toolkit
ms.reviewer: micflan
#customer intent: As a FinOps practitioner, I want to discover and use community-contributed Power BI reports to accelerate my FinOps journey.
---

# Community Power BI reports

The FinOps toolkit includes a repository for community-contributed Power BI reports. These reports are created and maintained by FinOps practitioners like you to address specialized use cases, industries, or scenarios that complement the official toolkit reports.

<br>

On this page:

- [About community reports](#about-community-reports)
- [Available community reports](#available-community-reports)
- [Using community reports](#using-community-reports)
- [Contributing a report](#contributing-a-report)
- [Support and maintenance](#support-and-maintenance)

---

## About community reports

Community reports are Power BI reports contributed by members of the FinOps community. These reports provide specialized solutions for specific scenarios that may not be covered by the [official FinOps toolkit reports](reports.md).

### Key differences from official reports

The following table compares community reports to official FinOps toolkit reports:

| Aspect | Official toolkit reports | Community reports |
|--------|-------------------------|-------------------|
| **Maintenance** | Maintained by the FinOps toolkit team | Maintained by community contributors |
| **Support** | Supported through Microsoft channels | No formal support guarantee |
| **Quality assurance** | Full QA and testing by toolkit team | Community reviewed, best effort |
| **Updates** | Regular updates with toolkit releases | Updated by report owners |
| **Branding** | FinOps toolkit branding | Community contributor branding |
| **SLA** | Best effort support | No SLA |

> [!IMPORTANT]
> Community reports are provided "AS IS" without warranty of any kind. Microsoft and the FinOps toolkit team do not guarantee the quality, compatibility, performance, or ongoing maintenance of community reports. Each report is the responsibility of its contributor.

<br>

## Available community reports

> [!NOTE]
> No community reports have been submitted yet. Be the first to contribute!

To view all available community reports:

1. Browse the [community reports directory](https://github.com/microsoft/finops-toolkit/tree/dev/src/power-bi/community) on GitHub
2. Each report has its own folder containing:
   - README.md with setup instructions and documentation
   - Power BI report files (.pbip, .pbit, or .pbix)
   - Screenshots and sample data (if applicable)
   - CONTRIBUTORS.md with maintainer contact information

<br>

## Using community reports

To use a community report:

### 1. Review the report documentation

Before downloading a community report, review the report's README.md file to understand:

- What the report does and who it's designed for
- Data sources and prerequisites required
- Known limitations or compatibility requirements
- Support expectations from the report maintainer

### 2. Download the report

Download the report files from the GitHub repository:

1. Navigate to the [community reports directory](https://github.com/microsoft/finops-toolkit/tree/dev/src/power-bi/community)
2. Select the report you want to use
3. Download the report files:
   - Use the .pbit file for first-time setup (template with no data)
   - Use the .pbix file to preview with sample data (if available)
   - Use the .pbip folder for source control and collaboration

### 3. Configure data sources

Follow the setup instructions in the report's README.md file to:

1. Configure required data sources (Cost Management exports, FinOps hubs, etc.)
2. Set up authentication
3. Enter any required parameters
4. Refresh the data

### 4. Customize as needed

Community reports are designed to be customized for your specific needs:

- Adjust filters and parameters
- Modify visuals and layouts
- Add your own data sources
- Integrate with other reports

<br>

## Contributing a report

We welcome contributions from the FinOps community! If you've created a Power BI report that could benefit others, consider contributing it to the toolkit.

### Before you contribute

Review the [contribution guidelines](https://github.com/microsoft/finops-toolkit/blob/dev/src/power-bi/community/README.md#-contribution-guidelines) to ensure your report meets the requirements:

- Report must be well-documented with setup instructions
- Must include screenshots and sample data or configuration
- Must be tested with real data
- Must be licensed under MIT or compatible license
- You must commit to maintaining the report as technical lead

### How to contribute

1. Fork the [finops-toolkit repository](https://github.com/microsoft/finops-toolkit)
2. Create a new branch for your report
3. Copy the [report template](https://github.com/microsoft/finops-toolkit/tree/dev/src/power-bi/community/.template) to a new folder
4. Add your report files and documentation following the template structure
5. Submit a pull request with a clear description
6. Respond to review feedback from the community

For detailed contribution steps, see the [community reports contribution guide](https://github.com/microsoft/finops-toolkit/blob/dev/src/power-bi/community/README.md#-contributing-a-report).

<br>

## Support and maintenance

### Getting support

Community reports follow a community support model similar to [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates):

1. **Check the report's README** for troubleshooting guidance and FAQs
2. **Contact the report maintainer** listed in the report's CONTRIBUTORS.md file
3. **Search existing issues** on GitHub for similar problems and solutions
4. **Open a new issue** on GitHub with the `community-report` label if needed
5. **Ask in discussions** for community help and suggestions

### Reporting issues

When reporting issues with a community report:

1. Include the report name in the issue title
2. Tag the issue with `community-report` and `Type: Bug 🐛` labels
3. Mention the report maintainer from the CONTRIBUTORS.md file
4. Provide detailed reproduction steps, screenshots, and error messages
5. Include your Power BI Desktop version and data source configuration

### Maintenance responsibilities

Report contributors serve as technical leads for their reports and are responsible for:

- Responding to issues and questions from users
- Maintaining compatibility with the latest Power BI versions
- Updating documentation as needed
- Reviewing and merging pull requests from other contributors
- Archiving or marking reports as deprecated if no longer maintained

<br>

## Related content

- [Official Power BI reports](reports.md)
- [Help me choose a data source](help-me-choose.md)
- [Set up Power BI reports](setup.md)
- [FinOps toolkit contribution guide](../help/contributors.md)
- [FinOps Framework](https://www.finops.org/framework/)

<br>

---

_Community reports are maintained by their contributors and are not officially supported by Microsoft or the FinOps toolkit team. For supported reports, see [Power BI reports](reports.md)._
