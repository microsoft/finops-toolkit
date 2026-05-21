# chart-name: quarterly-commitment-alignment
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4.5), gridspec_kw={'width_ratios': [1, 1.3]})

labels_pie = ['On-Demand\n96.1%', 'Reservation\n3.9%']
sizes_pie = [96.08, 3.92]
colors_pie = ['#EF5350', '#66BB6A']
explode = (0.03, 0.05)
ax1.pie(sizes_pie, labels=labels_pie, colors=colors_pie, explode=explode, autopct='', startangle=90,
textprops={'fontsize': 11, 'fontweight': 'bold'})
ax1.set_title('Current Core-Hour Coverage\n(Q1 2026)', fontsize=11, fontweight='bold')

rec_names = ['SQL DB BC Gen5\n(westus2, 3yr)', 'SQL DB BC Gen5\n(westus2, 1yr)', 'DSv2 VMs\n(eastus, 1yr)', 'DSv3 VMs\n(eastus, 3yr)', 'DSv2 VMs\n(westus, 1yr)', 'Ddv4 VMs\n(wcus, 3yr)', 'SQL HyperScale\n(westus2, 3yr)', 'SQL MI GP Gen5\n(westus2, 3yr)', 'SQL DB GP Gen5\n(eastus, 3yr)', 'DSv3 VMs\n(scus, 3yr)']
rec_savings = [2388, 1517, 1083, 675, 620, 604, 575, 478, 478, 462]
rec_pct = [55.0, 34.9, 57.7, 61.6, 38.8, 62.1, 55.0, 55.0, 55.0, 59.0]

y_pos = np.arange(len(rec_names))
bars = ax2.barh(y_pos, rec_savings, color='#42A5F5', edgecolor='white', height=0.7)
for i, (bar, pct) in enumerate(zip(bars, rec_pct)):
    ax2.text(bar.get_width() + 30, bar.get_y() + bar.get_height()/2, f'{pct:.0f}% discount', va='center',
fontsize=8, color='#1565C0')

ax2.set_yticks(y_pos)
ax2.set_yticklabels(rec_names, fontsize=8)
ax2.invert_yaxis()
ax2.set_xlabel('Quarterly Savings (USD)')
ax2.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax2.set_title('Top 10 Reservation Recommendations\n(Potential Savings)', fontsize=11, fontweight='bold')
ax2.grid(True, axis='x', alpha=0.25)

fig.tight_layout()
fig.savefig('quarterly-commitment-alignment.svg', bbox_inches='tight')
plt.close()
