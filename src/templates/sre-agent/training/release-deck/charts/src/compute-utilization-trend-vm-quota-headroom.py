# chart-name: vm-quota-headroom
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

regions = ['westus', 'eastus2', 'eastus', 'westus2', 'westus3', 'au-southeast', 'swedencentral']
regional_limits = [350, 100, 100, 100, 150, 100, 100]
current_usage = [0, 0, 0, 0, 0, 0, 0]
resource_counts = [70, 35, 3, 3, 1, 1, 1]

fig, axes = plt.subplots(1, 2, figsize=(14, 5))

colors_bar = ['#2ecc71'] * len(regions)
ax1 = axes[0]
bars = ax1.barh(regions, regional_limits, color='#e8f5e9', edgecolor='#4caf50', linewidth=1.2, label='Available (Headroom)')
ax1.barh(regions, current_usage, color='#1976d2', label='Used')
ax1.set_xlabel('vCPU Cores', fontsize=11)
ax1.set_title('Regional vCPU Quota Headroom\n(Non-Prod-Workloads)', fontsize=13, fontweight='bold')
ax1.legend(loc='lower right', fontsize=9)
ax1.set_xlim(0, 400)

for i, (limit, region) in enumerate(zip(regional_limits, regions)):
    ax1.text(limit + 5, i, f'{limit}', va='center', fontsize=9, color='#333')

ax1.invert_yaxis()
ax1.grid(axis='x', alpha=0.3)

ax2 = axes[1]
colors_pie = ['#1976d2', '#42a5f5', '#90caf9', '#bbdefb', '#e3f2fd', '#f5f5f5', '#fafafa']
wedges, texts, autotexts = ax2.pie(resource_counts, labels=regions, autopct=lambda pct: f'{pct:.0f}%' if pct > 3
else '', colors=colors_pie, startangle=90, pctdistance=0.8)
ax2.set_title('Azure Resource Distribution by Region\n(114 total resources)', fontsize=13, fontweight='bold')

for text in texts:
    text.set_fontsize(8)
for autotext in autotexts:
    autotext.set_fontsize(8)

plt.tight_layout(pad=2)
plt.savefig('vm-quota-headroom.svg', bbox_inches='tight', facecolor='white')
plt.close()
