# chart-name: benefit-recommendations-chart
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

recs = [
    {"label": "SQL DB BC Gen5\n(West US 2, 3yr)", "savings": 2388.41, "pct": 55.0},
    {"label": "SQL DB BC Gen5\n(West US 2, 1yr)", "savings": 1517.15, "pct": 34.9},
    {"label": "DSv2 VMs\n(East US, 1yr)", "savings": 1083.22, "pct": 57.7},
    {"label": "DSv3 VMs\n(East US, 3yr)", "savings": 674.71, "pct": 61.6},
    {"label": "DSv2 VMs\n(West US, 1yr)", "savings": 619.94, "pct": 38.8},
    {"label": "Ddv4 VMs\n(West Central US, 3yr)", "savings": 603.85, "pct": 62.1},
    {"label": "SQL DB HS Gen5\n(West US 2, 3yr)", "savings": 574.70, "pct": 55.0},
    {"label": "SQL MI GP Gen5\n(West US 2, 3yr)", "savings": 477.68, "pct": 55.0},
    {"label": "SQL DB GP Gen5\n(East US, 3yr)", "savings": 477.68, "pct": 55.0},
    {"label": "DSv3 VMs\n(S Central US, 3yr)", "savings": 462.48, "pct": 59.0},
]

labels = [r["label"] for r in recs]
savings = [r["savings"] for r in recs]
pcts = [r["pct"] for r in recs]

fig, ax1 = plt.subplots(figsize=(10, 6))
colors_bar = plt.cm.Blues(np.linspace(0.85, 0.45, len(recs)))
bars = ax1.barh(range(len(labels)), savings, color=colors_bar, edgecolor='white', height=0.7)
ax1.set_yticks(range(len(labels)))
ax1.set_yticklabels(labels, fontsize=8)
ax1.invert_yaxis()
ax1.set_xlabel('Estimated Savings ($/term)', fontsize=10)
ax1.set_title('Top 10 Reservation Recommendations by Savings', fontsize=13, fontweight='bold', pad=12)
ax1.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))

for i, (s, p) in enumerate(zip(savings, pcts)):
    ax1.text(s + 30, i, f'{p:.0f}% off', va='center', fontsize=8, color='#333')

ax1.set_xlim(0, max(savings) * 1.18)
ax1.grid(axis='x', alpha=0.3)
plt.tight_layout()
plt.savefig('benefit-recommendations-chart.svg', bbox_inches='tight')
plt.close()
