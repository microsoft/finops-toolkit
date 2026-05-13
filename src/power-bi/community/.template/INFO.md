# Community Report Template

This directory contains template files for contributing a community Power BI report to the FinOps toolkit.

## How to use this template

1. **Copy this template directory** to a new folder under `src/power-bi/community/` with your report name
   - Use lowercase with hyphens (e.g., `advanced-chargeback`)

2. **Update README.md** with your report details
   - Replace all `[placeholder text]` with your actual content
   - Remove sections that don't apply
   - Add screenshots in the `images/` folder

3. **Update CONTRIBUTORS.md** with your information
   - Add yourself as the technical lead
   - List any additional contributors
   - Add acknowledgments if applicable

4. **Add your report files**
   - Power BI Project (.pbip) format is preferred
   - Include .pbit template file
   - Optionally include .pbix with sample data
   - Remove any sensitive information

5. **Create images folder** and add screenshots
   ```bash
   mkdir images
   ```
   - Include at least 2-3 screenshots of key pages
   - Use descriptive filenames (e.g., `overview-page.png`)

6. **Review the checklist** in the main README.md to ensure your report meets all requirements

7. **Submit a pull request** with your community report

## File structure

Your completed report directory should look like this:

```
your-report-name/
├── README.md           # Required: Your report documentation
├── CONTRIBUTORS.md     # Required: Contributor information
├── images/             # Required: Screenshots
│   ├── screenshot-overview.png
│   └── screenshot-detail.png
├── report.pbip/        # Recommended: Power BI Project
│   ├── report.pbip
│   ├── definition/
│   └── ...
├── report.pbit         # Recommended: Template file
└── report.pbix         # Optional: File with sample data
```

## Questions?

If you have questions about contributing a community report:

1. Review the [contribution guidelines](../README.md#-contribution-guidelines) in the main community README
2. Check existing community reports for examples
3. Ask in [GitHub Discussions](https://github.com/microsoft/finops-toolkit/discussions)
4. Open an issue with the `question` label

<br>

---

_Thank you for contributing to the FinOps toolkit community!_
