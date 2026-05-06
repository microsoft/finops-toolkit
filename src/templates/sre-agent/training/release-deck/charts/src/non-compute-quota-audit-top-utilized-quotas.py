# chart-name: top-utilized-quotas
import matplotlib.pyplot as plt

labels = ['Storage Accounts (westus)', 'Storage Accounts (eastus2)', 'Route Tables (westus)', 'Storage Accounts (westus2)', 'Public IP Addresses (westus)', 'Public IPv4 Addresses - Standard (westus)', 'Load Balancers (westus)',
'Standard Sku Load Balancers (westus)', 'Virtual Networks (westus)', 'Network Security Groups (westus)', 'Virtual Networks (eastus2)', 'Network Security Groups (eastus2)', 'Network Interfaces (westus)', 'Key Vault vaults estimated subscription limit (global)', 'Private Endpoints (westus)']
utils = [1.2, 0.8, 0.5, 0.4, 0.3, 0.3, 0.3, 0.3, 0.2, 0.18, 0.1, 0.06, 0.02, 0.02, 0.01]
currents = [3, 2, 3, 1, 3, 3, 3, 3, 2, 9, 1, 3, 12, 1, 4]
limits = [250, 250, 600, 250, 1000, 1000, 1000, 1000, 1000, 5000, 1000, 5000, 65536, 5000, 65536]

fig, ax = plt.subplots(figsize=(8, 5))
colors_top = ['#2ecc71' if v < 50 else '#f39c12' if v < 80 else '#e74c3c' for v in utils]
bars = ax.barh(range(len(labels)), utils, color=colors_top, edgecolor='white')
ax.set_yticks(range(len(labels)))
ax.set_yticklabels(labels, fontsize=8)

for bar, val, count, limit in zip(bars, utils, currents, limits):
    ax.text(bar.get_width() + 0.15, bar.get_y() + bar.get_height()/2, f'{val:.1f}% ({count}/{limit})', va='center',
fontsize=7.5)

ax.set_xlabel('Utilization %', fontsize=10)
ax.set_title('Top 15 Most-Utilized Non-Compute Quotas\n(Network Watchers excluded)', fontsize=12,
fontweight='bold')
ax.axvline(x=80, color='#e74c3c', linestyle='--', alpha=0.7, label='80% Risk Threshold')
ax.legend(loc='lower right', fontsize=8)
ax.set_xlim(0, max(utils) * 1.3 + 2)
ax.grid(axis='x', alpha=0.2)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.invert_yaxis()

plt.tight_layout()
plt.savefig('chart_top_utilized_quotas.svg', bbox_inches='tight')
plt.close()
