# chart-name: resource-distribution
import matplotlib.pyplot as plt
import numpy as np

resource_data = {"Operations Mgmt Solutions": 11, "NSGs": 10, "Managed Identities": 11, "Storage Accounts": 6,
"Event Grid Topics": 6, "Workbooks": 6, "Log Analytics": 5, "Private DNS Zones": 5, "Private DNS Links": 5, "App Insights": 4, "Private Endpoints": 4, "Network Interfaces": 4, "Alert Rules": 4, "Public IPs": 3, "Action Groups":
3, "Cognitive Services": 3, "Other": 30}
region_data = {"westus": 55, "eastus2": 30, "global": 15, "westus2": 3, "eastus": 3, "other": 5}

fig3, (ax3a, ax3b) = plt.subplots(1, 2, figsize=(14, 6))

top_types = dict(sorted(resource_data.items(), key=lambda x: x[1], reverse=True)[:10])
colors_pie = plt.cm.Set3(np.linspace(0, 1, len(top_types)))
wedges, texts, autotexts = ax3a.pie(top_types.values(), labels=None, autopct='%1.0f%%', colors=colors_pie,
startangle=90, pctdistance=0.85)
ax3a.legend(top_types.keys(), loc='center left', bbox_to_anchor=(-0.3, 0.5), fontsize=8)
ax3a.set_title('Resource Distribution by Type', fontsize=10, fontweight='bold')
for t in autotexts:
    t.set_fontsize(7)

bars3 = ax3b.bar(region_data.keys(), region_data.values(), color='#4CAF50', edgecolor='white')
for bar, val in zip(bars3, region_data.values()):
    ax3b.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.5, str(val), ha='center', fontsize=9,
fontweight='bold')
ax3b.set_title('Resource Count by Region', fontsize=10, fontweight='bold')
ax3b.set_ylabel('Count', fontsize=9)
ax3b.grid(axis='y', alpha=0.2)

fig3.suptitle('Azure Resource Estate Overview — cab7feeb…51ff\n(May 2, 2026)', fontsize=11, fontweight='bold')
plt.tight_layout(rect=[0, 0, 1, 0.92])
plt.savefig('resource-distribution.svg', bbox_inches='tight')
plt.close()
