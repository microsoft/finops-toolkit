# 📦 Azure Optimization Engine Automation Runbooks

This folder contains the several Azure Automation Runbooks that are executed periodically by AOE to collect data from several sources and generate optimization recommendations:

- [data-collection](./data-collection/) - runbooks collecting data from several sources (Azure Resource Graph, Azure Monitor, Billing APIs, etc.), exporting it to Azure Storage, and later ingesting it into custom Log Analytics tables.
- [maintenance](./maintenance/) - runbooks executing periodic data cleansing (for example, recommendations retention policy).
- [recommendations](./recommendations/) - runbooks generating the weekly recommendations of different types (by querying the Log Analytics workspace with domain-specific logic), exporting it to Azure Storage, and later ingesting it into custom both a Log Analytics table and a SQL Database.
- [remediations](./remediations/) - runbooks meant to automate the remediation of domain-specific optimization recommendations (**turned off by default**).
