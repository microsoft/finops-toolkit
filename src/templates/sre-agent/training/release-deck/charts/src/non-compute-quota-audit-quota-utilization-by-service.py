# chart-name: quota-utilization-by-service
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

service_names = ['App Service plans', 'Key Vault vaults', 'SQL servers', 'Service Bus namespaces', 'Storage']
max_utils = [0.0, 0.02, 0.0, 0.0, 1.2]

fig, ax = plt.subplots(figsize=(8, 4))
colors_list = ['#2ecc71' if v < 50 else '#f39c12' if v < 80 else '#e74c3c' for v in max_utils]
bars = ax.barh(service_names, max_utils, color=colors_list, edgecolor='white', linewidth=0.5)

for bar, val in zip(bars, max_utils):
    ax.text(bar.get_width() + 0.3, bar.get_y() + bar.get_height()/2, f'{val:.1f}%', va='center', fontsize=9,
fontweight='bold')

ax.set_xlabel('Max Utilization %', fontsize=10)
ax.set_title('Peak Non-Compute Quota Utilization by Service\n(Network Watchers excluded)', fontsize=12,
fontweight='bold')
ax.set_xlim(0, max(max_utils) * 1.3 + 5)
ax.axvline(x=80, color='#e74c3c', linestyle='--', alpha=0.7, label='80% Risk Threshold')
ax.legend(loc='lower right', fontsize=8)
ax.grid(axis='x', alpha=0.2)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

plt.tight_layout()
plt.savefig('chart_quota_utilization_by_service.svg', bbox_inches='tight')
plt.close()
