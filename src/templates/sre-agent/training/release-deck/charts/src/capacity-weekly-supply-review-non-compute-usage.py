# chart-name: non-compute-usage
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

nc_items = [
    ("Network Interfaces (westus)", 12, 65536),
    ("NSGs (westus)", 9, 5000),
    ("Private Endpoints (westus)", 4, 65536),
    ("Storage Accounts (westus)", 3, 250),
    ("Public IPs (westus)", 3, 1000),
    ("Load Balancers (westus)", 3, 1000),
    ("Route Tables (westus)", 3, 600),
    ("VNets (westus)", 2, 1000),
    ("NSGs (eastus2)", 3, 5000),
    ("Storage Accounts (eastus2)", 2, 250),
    ("VNets (eastus2)", 1, 1000),
    ("Storage Accounts (westus2)", 1, 250),
    ("Key Vault (sub-level)", 1, 5000),
]

nc_labels = [x[0] for x in nc_items]
nc_used = [x[1] for x in nc_items]
nc_util = [x[1] / x[2] * 100 for x in nc_items]

fig, ax = plt.subplots(figsize=(9, 5.5))
colors_nc = plt.cm.Greens(np.linspace(0.7, 0.3, len(nc_items)))
ax.barh(range(len(nc_labels)), nc_util, color=colors_nc, edgecolor='white', height=0.65)
ax.set_yticks(range(len(nc_labels)))
ax.set_yticklabels(nc_labels, fontsize=8)
ax.invert_yaxis()
ax.set_xlabel('Utilization %', fontsize=10)
ax.set_title('Non-Compute Quota Utilization (Active Resources)', fontsize=12, fontweight='bold', pad=12)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'{x:.1f}%'))

for i, (u, used, item) in enumerate(zip(nc_util, nc_used, nc_items)):
    ax.text(u + 0.02, i, f'{used}/{item[2]}', va='center', fontsize=7, color='#555')

ax.set_xlim(0, max(nc_util) * 1.5)
ax.grid(axis='x', alpha=0.2)
plt.tight_layout()
plt.savefig('non-compute-usage.svg', bbox_inches='tight')
plt.close()
