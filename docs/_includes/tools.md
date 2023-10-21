<!-- markdownlint-disable MD041 -->

{% if include.all != "1" %}

---

## 🧰 Related tools

{% endif %}

{% if include.ignore_this_condition %}

- Ignore this. It's a placeholder so the auto-formatting won't mess up the list.{% endif %}{% if include.all == "1" or include["finops-hub"] == "1" %}
- [FinOps hubs](https://microsoft.github.io/finops-toolkit/hubs/) – Open, extensible, and scalable cost reporting.{% endif %}{% if include.all == "1" or include["power-bi"] == "1" %}
- [Power BI reports](https://microsoft.github.io/finops-toolkit/power-bi/) – Accelerate your reporting with Power BI starter kits.{% endif %}{% if include.all == "1" or include["optimization-workbook"] == "1" %}
- [Cost optimization workbook](https://microsoft.github.io/finops-toolkit/optimization-workbook/) – Central hub for cost optimization.{% endif %}{% if include.all == "1" or include["governance-workbook"] == "1" %}
- [Governance workbook](https://microsoft.github.io/finops-toolkit/governance-workbook/) – Central hub for governance.{% endif %}{% if include.all == "1" or include["powershell"] == "1" %}
- [PowerShell module](https://microsoft.github.io/finops-toolkit/powershell/) – Automate and manage FinOps solutions and capabilities.{% endif %}{% if include.all == "1" or include["bicep-registry"] == "1" %}
- [Bicep Registry modules](https://microsoft.github.io/finops-toolkit/bicep/) – Official repository for Bicep modules.{% endif %}{% if include.all == "1" or include["open-data"] == "1" %}
- [Open data](https://microsoft.github.io/finops-toolkit/data/) – Data available for anyone to access, use, and share without restriction.{% endif %}{% if include.all == "1" or include["open-data-regions"] == "1" %}
  - [Regions](https://microsoft.github.io/finops-toolkit/data/#-regions) – Cost Management locations and their corresponding Azure region IDs and names.{% endif %}

{% if include.all != "1" %}
<br>
{% endif %}
