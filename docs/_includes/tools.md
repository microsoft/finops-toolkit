<!-- markdownlint-disable MD041 -->

{% if include.relatedTools %}

---

## 🧰 Related tools

{% endif %}

{% if include.ignore_this_condition %}

- Ignore this. It's a placeholder so the auto-formatting won't mess up the list.{% endif %}
  {% if include.all or include["finops-hub"] %}
- [FinOps hubs](./finops-hub/README.md) – Open, extensible, and scalable cost reporting.{% endif %}
  {% if include.all or include["power-bi"] %}
- [Power BI reports](./power-bi/README.md) – Accelerate your reporting with Power BI starter kits.{% endif %}
  {% if include.all or include["optimization-workbook"] %}
- [Cost optimization workbook](./optimization-workbook/README.md) – Central hub for cost optimization.{% endif %}
  {% if include.all or include["governance-workbook"] %}
- [Governance workbook](./governance-workbook/README.md) – Central hub for governance.{% endif %}
  {% if include.all or include["powershell"] %}
- [PowerShell module](./powershell/README.md) – Commands to help you automate and manage FinOps solutions and capabilities.{% endif %}
  {% if include.all or include["bicep-registry"] %}
- [Bicep Registry modules](./bicep-registry/README.md) – Official repository for Bicep modules.{% endif %}
  {% if include.all or include["open-data"] %}
- [Open data](./open-data.md/README.md) – Data available for anyone to access, use, and share without restriction.{% endif %}
  {% if include.all or include["open-data-regions"] %}
  - [Regions](./open-data.md/README.md#-regions) – Cost Management locations and their corresponding Azure region IDs and names.{% endif %}

{% if include.relatedTools %}
<br>
{% endif %}
