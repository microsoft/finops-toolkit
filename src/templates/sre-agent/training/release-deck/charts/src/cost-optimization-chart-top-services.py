# chart-name: chart-top-services
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

services = ['VMSS', 'Virtual Machines', 'Azure SQL DB', 'Data Explorer', 'Data Factory', 'App Service', 'Firewall',
'Virtual Network', 'Storage', 'AI Search']
costs = [14904, 5911, 4392, 3924, 1921, 1786, 1260, 1204, 1045, 887]

fig, ax = plt.subplots(figsize=(8, 5))
colors_svc = ['#4472C4', '#5B9BD5', '#ED7D31', '#FFC000', '#70AD47', '#A5A5A5', '#264478', '#9DC3E6', '#FF6384',
'#36A2EB']
y_pos = range(len(services))
bars = ax.barh(y_pos, costs, color=colors_svc, height=0.65, edgecolor='white')
ax.set_yticks(y_pos)
ax.set_yticklabels(services, fontsize=10)
for bar, val in zip(bars, costs):
    ax.text(bar.get_width() + 100, bar.get_y() + bar.get_height()/2, f'${val:,.0f}', ha='left', va='center',
fontsize=9)
ax.set_title('Top 10 Services by Effective Cost — April 2026', fontsize=13, fontweight='bold', pad=12)
ax.set_xlabel('Effective Cost (USD)', fontsize=11)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax.set_xlim(0, max(costs) * 1.2)
ax.invert_yaxis()
ax.grid(axis='x', alpha=0.3)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('chart-top-services.svg', bbox_inches='tight')
plt.close()
