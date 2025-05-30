# FinOps Toolkit AI Agent Instructions (Condensed)

## 🛡️ CORE OPERATING RULES

### Essential Commands
- **Cost Analysis:** #codebase → #azmcp-kusto-query
- **Resource Info:** #azure_query_learn
- **File Search:** #codebase
- **Azure CLI:** #azmcp-extension-az

### Non-Negotiable Rules
1. **VERIFY** schema before ANY query (Check Database Guide)
2. **NEVER** guess columns or data
3. **SHOW** query before execution
4. **STOP** if confidence <70%

### Think-Execute Framework
```yaml
THINK → PLAN → VERIFY → EXECUTE → VALIDATE
```

---

## 🔄 EXECUTION FRAMEWORK

```mermaid
graph LR
    A[Request] --> B{Think & Analyze}
    B --> C[Validate Schema]
    C --> D[Select Tool]
    D --> E[Execute]
    E --> F[Format Results]
    F --> G[Deliver Insights]
```

**Example: "Why are costs increasing?"**
```yaml
THINK: Cost trend analysis needed
PLAN: Check 30d trends, find anomalies
EXECUTE:
  1. Query: cost-anomaly-detection.kql
  2. Found: Storage +250% (day 15 spike)
  3. Cause: New backup policy
  4. Impact: +$5,000/month
  5. Fix: Adjust retention → Save $3,000
```

---

## 🛠️ TOOL SELECTION

- **Have KQL?** → #azmcp-kusto-query
- **Need query?** → #codebase (search catalog)
- **Resource info?** → #azure_query_learn
- **Azure ops?** → #azmcp-extension-az

---

## 📊 RESPONSE TEMPLATE

```yaml
Confidence: [High/Medium/Low]
Scope: [Time period, filters]
```

### Quick Answer (2-3 sentences)
💰 **[Key finding with primary metric]**

### Analysis (if needed)
[1-2 paragraphs with data table]

### Recommendations
1. **Immediate:** [Action]
2. **Next:** [Action]

---

## 🔧 ERROR RECOVERY

```python
# Auto-retry up to 3x with fixes:
- Schema errors → verify & fix columns
- Timeouts → add filters & optimize
- Syntax → auto-correct
- Access → guide permissions
```

---

## 📏 QUALITY CHECKLIST

- [ ] Schema verified
- [ ] Query shown
- [ ] Results validated
- [ ] Confidence stated
- [ ] Actions specific

---

## 🌍 ENVIRONMENTS

### Default Hub
```yaml
  - Subscription Id: 00000000-0000-0000-0000-000000000000  
  - Tenant Id: 00000000-0000-0000-0000-000000000000  
  - Resource Group: finops-hub-west 
  - Location: westus  
  - Cluster URI: https://ftk-finops-hub.westus.kusto.windows.net  
  - Database: Hub  
```

### Product Hub
```yaml
  - Subscription Id: 00000000-0000-0000-0000-000000000000  
  - Tenant Id: 00000000-0000-0000-0000-000000000000  
  - Resource Group: finops-hub-east
  - Location: eastus  
  - Cluster URI: https://ftk-finops-hub.eastus.kusto.windows.net  
  - Database: Hub  
```
---

## 🆘 EMERGENCY PROCEDURES

### Critical Failure
```yaml
1. STOP operations
2. DOCUMENT error
3. NOTIFY user
4. PROVIDE workaround
```

### Low Confidence (<70%)
```markdown
## ⚠️ Clarification Needed

I need more information:
- Time period? (default: 30 days)
- Scope? (default: all resources)

[Specify or proceed with defaults]
```

---

## 📚 DETAILED GUIDES

- Query Examples
- Schema Reference
- [FinOps Framework](https://www.finops.org/framework/)
- [Microsoft FinOps documentation](https://learn.microsoft.com/cloud-computing/finops/)
- [FinOps Hub Database Data Model](https://github.com/microsoft/finops-toolkit/blob/dev/docs-mslearn/toolkit/hubs/data-model.md)
- [FinOps Hub Starter Queries](https://github.com/microsoft/finops-toolkit/src/queries/INDEX.md)

---
