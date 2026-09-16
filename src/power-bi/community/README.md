# 🌐 Community Power BI reports

Welcome to the FinOps toolkit community reports repository! This is a collection of Power BI reports contributed and maintained by the FinOps community. These reports are designed to accelerate your FinOps journey by providing specialized reporting solutions for various use cases.

<br>

On this page:

- [📋 About community reports](#-about-community-reports)
- [🔍 Available reports](#-available-reports)
- [🤝 Contributing a report](#-contributing-a-report)
- [📐 Contribution guidelines](#-contribution-guidelines)
- [✅ Validation requirements](#-validation-requirements)
- [⚖️ License and support](#️-license-and-support)

---

## 📋 About community reports

Community reports are Power BI reports contributed by FinOps practitioners like you. These reports complement the official FinOps toolkit reports by providing specialized solutions for specific use cases, industries, or scenarios.

### Key differences from official reports

| Aspect | Official toolkit reports | Community reports |
|--------|-------------------------|-------------------|
| **Maintenance** | Maintained by the FinOps toolkit team | Maintained by community contributors |
| **Support** | Supported through toolkit channels | No formal support guarantee |
| **Quality assurance** | Full QA and testing by toolkit team | Community reviewed, best effort |
| **Updates** | Regular updates with toolkit releases | Updated by report owners |
| **Branding** | FinOps toolkit branding | Community contributor branding |

> [!IMPORTANT]
> Community reports are provided "AS IS" without warranty of any kind. The FinOps toolkit team does not guarantee the quality, compatibility, performance, or ongoing maintenance of community reports. Each report is the responsibility of its contributor.

<br>

## 🔍 Available reports

The following reports are available in this directory. Each report is maintained by its contributor and may have different levels of maturity, support, and compatibility.

> [!NOTE]
> No community reports have been submitted yet. Be the first to contribute!

To browse all community reports, navigate to the subdirectories in this folder. Each report has its own folder with:
- README.md - Report documentation and setup instructions
- Power BI report files (.pbip, .pbit, or .pbix)
- Sample data (if applicable)
- Contributor contact information

<br>

## 🤝 Contributing a report

We welcome contributions from the FinOps community! If you've created a Power BI report for FinOps that could benefit others, we encourage you to share it here.

### Before you contribute

1. **Review the contribution guidelines** below to ensure your report meets the requirements.
2. **Test your report thoroughly** with real data to ensure it works as expected.
3. **Document your report** with clear setup instructions and data source requirements.
4. **Be prepared to maintain your report** as the technical lead and respond to issues from users.

### How to submit a report

1. **Fork the repository** and create a new branch for your report.
2. **Create a folder** under `src/power-bi/community/` with your report name (use lowercase with hyphens, e.g., `chargeback-advanced`).
3. **Add your report files** following the structure outlined in the contribution guidelines.
4. **Submit a pull request** with a clear description of your report and its use case.
5. **Respond to review feedback** from the community and toolkit team.

<br>

## 📐 Contribution guidelines

To maintain consistency and quality across community reports, please follow these guidelines:

### Folder structure

Each community report must be in its own folder with the following structure:

```
src/power-bi/community/
└── your-report-name/
    ├── README.md           # Required: Report documentation
    ├── report.pbip/        # Recommended: Power BI Project format
    │   └── ...
    ├── report.pbit         # Alternative: Power BI template file
    ├── report.pbix         # Alternative: Power BI file with sample data
    ├── images/             # Optional: Screenshots and diagrams
    │   └── screenshot.png
    └── CONTRIBUTORS.md     # Required: Contributor information
```

### Required files

#### README.md

Your report's README.md must include:

1. **Report title and description** - What the report does and who it's for
2. **Author information** - Your name/organization and contact info
3. **Last updated date** - When the report was last modified
4. **FinOps use case** - Which FinOps capability or persona this addresses
5. **Data sources** - What data sources are required (e.g., Cost Management exports, FinOps hubs)
6. **Services used** - Azure services, Power BI license requirements
7. **Prerequisites** - What users need before using the report
8. **Setup instructions** - Step-by-step guide to configure and use the report
9. **Known limitations** - Any limitations or known issues
10. **Support** - How users can get help or report issues
11. **License** - License under which the report is shared (must be compatible with MIT)

#### CONTRIBUTORS.md

Your report's CONTRIBUTORS.md must include:

1. **Technical lead** - Primary contact and maintainer
2. **Contributors** - Others who have contributed to the report
3. **Acknowledgments** - Any third-party resources or inspirations

### Report guidelines

1. **File format**
   - Prefer Power BI Project (.pbip) format for easier source control and collaboration
   - Include both .pbit (template) and optionally .pbix (with sample data) versions
   - Remove any sensitive data before submitting

2. **Documentation**
   - Include screenshots of key report pages in the `images/` folder
   - Provide clear, step-by-step setup instructions
   - Document all parameters and configuration options
   - List all data sources and connection requirements

3. **Data sources**
   - Support standard FinOps toolkit data sources when possible (Cost Management exports, FinOps hubs)
   - Clearly document any custom or additional data sources needed
   - Include sample queries or export configurations if needed

4. **Naming conventions**
   - Use sentence casing for report and page names (not Title Casing)
   - Be descriptive but concise
   - Avoid special characters in folder and file names

5. **Quality standards**
   - Test the report with real data
   - Ensure the report works with the latest Power BI Desktop version
   - Validate that all visuals render correctly
   - Check for performance issues with larger datasets

<br>

## ✅ Validation requirements

Before submitting your report, please validate:

- [ ] **Folder structure** follows the required layout
- [ ] **README.md** contains all required sections
- [ ] **CONTRIBUTORS.md** is present with maintainer information
- [ ] **Report files** are included (preferably .pbip format)
- [ ] **No sensitive data** is included in report files
- [ ] **Screenshots** are included to showcase the report
- [ ] **Setup instructions** are clear and complete
- [ ] **Report has been tested** with actual data
- [ ] **License is compatible** with MIT license
- [ ] **You commit to maintaining** the report as technical lead

<br>

## ⚖️ License and support

### License

All community reports must be contributed under a license compatible with the [MIT License](../../../LICENSE) that governs this repository. By contributing a report, you agree to license your contribution under the MIT License.

### Support model

Community reports follow a community support model similar to [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates):

- **No warranty**: Reports are provided "AS IS" without warranty of any kind
- **Community maintained**: Report owners are responsible for maintenance and updates
- **Best effort support**: The FinOps toolkit team may provide guidance but does not guarantee support
- **Community reviews**: Other community members may provide feedback and suggestions
- **No SLA**: There is no service level agreement for fixes or updates

### Getting help

If you encounter issues with a community report:

1. **Check the report's README** for troubleshooting guidance
2. **Contact the report maintainer** listed in CONTRIBUTORS.md
3. **Open an issue** on GitHub with the `community-report` label
4. **Ask the community** in [GitHub Discussions](https://github.com/microsoft/finops-toolkit/discussions)

### Reporting issues

When reporting issues with community reports:

1. Use the report name in the issue title
2. Tag the issue with `community-report` and `Type: Bug 🐛` labels
3. @ mention the report maintainer from CONTRIBUTORS.md
4. Provide detailed reproduction steps and screenshots

<br>

---

## 📚 Additional resources

- [Official FinOps toolkit Power BI reports](../README.md)
- [Power BI report design guidelines](../README.md#-design-guidelines)
- [FinOps toolkit contribution guide](../../CONTRIBUTING.md)
- [FinOps Framework](https://www.finops.org/framework/)
- [Microsoft FinOps documentation](https://learn.microsoft.com/azure/cost-management-billing/finops/)

<br>

_Community reports are maintained by their contributors and are not officially supported by Microsoft or the FinOps toolkit team. For supported reports, see the [official Power BI reports](../README.md)._
