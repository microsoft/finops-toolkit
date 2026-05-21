# chart-name: fy-top-services
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

services = ['VMSS', 'Virtual Machines', 'Azure SQL DB', 'Azure Data Explorer', 'Data Factory', 'App Service',
'Fabric', 'Firewall', 'Virtual Network', 'Storage', 'AI Search', 'AKS']
costs = [150804, 56124, 44103, 40216, 20780, 17850, 13118, 12769, 12383, 10467, 8984, 6078]
services_r = services[::-1]
costs_r = costs[::-1]

fig, ax = plt.subplots(figsize=(9, 5.5))
colors = ['#0078D4' if c > 40000 else '#50E6FF' if c > 15000 else '#B4D8E7' for c in costs_r]
bars = ax.barh(services_r, costs_r, color=colors, edgecolor='white', height=0.65)
for bar, cost in zip(bars, costs_r):
    ax.text(bar.get_width() + 1500, bar.get_y() + bar.get_height()/2, f'${cost/1000:,.0f}K', va='center',
fontsize=9, fontweight='bold')
ax.set_xlabel('Effective Cost (USD)', fontsize=11)
ax.set_title('Top 12 Services by FY25-26 Effective Cost', fontsize=13, fontweight='bold')
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x/1000:,.0f}K'))
ax.set_xlim(0, max(costs)*1.25)
ax.grid(axis='x', alpha=0.3)
plt.tight_layout()
plt.savefig('fy-top-services.svg', bbox_inches='tight')
plt.close()
