# chart-name: top-services
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

services = ['VMSS','VMs','SQL DB','ADX','ADF','App Service','Firewall','VNet','Storage','AI Search']
costs = [14904, 5911, 4392, 3924, 1921, 1786, 1260, 1204, 1045, 887]

fig, ax = plt.subplots(figsize=(10, 5))
y = np.arange(len(services))
bars = ax.barh(y, costs, color='#0078D4', alpha=0.85, height=0.6)

for bar, cost in zip(bars, costs):
    ax.text(bar.get_width() + 150, bar.get_y() + bar.get_height()/2, f'${cost:,.0f}', va='center', fontsize=9)

ax.set_yticks(y)
ax.set_yticklabels(services, fontsize=9)
ax.invert_yaxis()
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x/1000:.0f}K'))
ax.set_title('Top 10 Services by Effective Cost — April 2026', fontsize=13, fontweight='bold')
ax.set_xlabel('Effective Cost (USD)')
ax.grid(axis='x', alpha=0.3)
plt.tight_layout()
plt.savefig('top-services.svg', bbox_inches='tight')
plt.close()
