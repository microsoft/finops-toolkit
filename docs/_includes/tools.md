<!-- markdownlint-disable MD041 -->

{% if include.ignore_this_condition %}

- Ignore this. It's a placeholder so the auto-formatting won't mess up the list.{% endif %}{% if include.all == "1" or include.hubs == "1" %}
- 🏦 [FinOps hubs]({{ "/hubs" | relative_url }}) – Open, extensible, and scalable cost reporting.{% endif %}{% if include.all == "1" or include.pbi == "1" %}
- 📊 [Power BI reports]({{ "/power-bi" | relative_url }}) – Accelerate your reporting with Power BI starter kits.{% endif %}{% if include.all == "1" or include.opt == "1" %}
- 📒 [Cost optimization workbook]({{ "/optimization-workbook" | relative_url }}) – Central hub for cost optimization.{% endif %}{% if include.all == "1" or include.gov == "1" %}
- 📒 [Governance workbook]({{ "/governance-workbook" | relative_url }}) – Central hub for governance.{% endif %}{% if include.all == "1" or include.aoe == "1" %}
- 🔍 [Azure Optimization Engine]({{ "/optimization-engine" | relative_url }}) – Extensible solution for custom optimization recommendations.{% endif %}{% if include.all == "1" or include.ps == "1" %}
- 🖥️ [PowerShell module]({{ "/powershell" | relative_url }}) – Automate and manage FinOps solutions and capabilities.{% endif %}{% if include.all == "1" or include.bicep == "1" %}
- 🦾 [Bicep Registry modules]({{ "/bicep" | relative_url }}) – Official repository for Bicep modules.{% endif %}{% if include.all == "1" or include.data == "1" %}
- 🌐 [Open data]({{ "/data" | relative_url }}) – Data available for anyone to access, use, and share without restriction.{% endif %}{% if include.all == "1" or include.datatypes == "1" %}
  - 📏 [Pricing units]({{ "/data#-pricing-units" | relative_url }}) – Microsoft pricing units, distinct units, and scaling factors.
  - 🗺️ [Regions]({{ "/data#%EF%B8%8F-regions" | relative_url }}) – Microsoft Commerce locations and Azure regions (IDs and names).
  - 📚 [Resource types]({{ "/data#-resource-types" | relative_url }}) – Microsoft Azure resource type display names, icons, and more.
  - 🎛️ [Services]({{ "/data#%EF%B8%8F-services" | relative_url }}) – Microsoft consumed services, resource types, and FOCUS service categories.
  - ⬇️ [Sample exports]({{ "/data#%EF%B8%8F-sample-exports" | relative_url }}) – Sample files from Cost Management exports.{% endif %}
