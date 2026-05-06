# chart-name: chart-reservation-recommendations
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

rec_labels = ['SQL DB BC Gen5\n(westus2, 3yr)', 'SQL DB BC Gen5\n(westus2, 1yr)', 'DS1_v2 VMs\n(eastus, 1yr)',
'D2s_v3 VMs\n(eastus, 3yr)', 'DS1_v2 VMs\n(westus, 1yr)']
rec_savings = [2388, 1517, 1083, 675, 620]
rec_pct = [55.0, 34.9, 57.7, 61.6, 38.8]

fig, ax = plt.subplots(figsize=(8, 4.5))
colors_rec = ['#4472C4', '#5B9BD5', '#ED7D31', '#FFC000', '#70AD47']
bars = ax.barh(range(len(rec_labels)), rec_savings, color=colors_rec, height=0.6, edgecolor='white')
ax.set_yticks(range(len(rec_labels)))
ax.set_yticklabels(rec_labels, fontsize=9)
for i, (bar, val, pct) in enumerate(zip(bars, rec_savings, rec_pct)):
    ax.text(bar.get_width() + 30, bar.get_y() + bar.get_height()/2, f'${val:,.0f}/mo ({pct:.0f}% off)', ha='left',
va='center', fontsize=9, fontweight='bold')
ax.set_title('Top 5 Reservation Recommendations — Potential Savings', fontsize=13, fontweight='bold', pad=12)
ax.set_xlabel('Estimated Monthly Savings (USD)', fontsize=11)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax.set_xlim(0, max(rec_savings) * 1.35)
ax.invert_yaxis()
ax.grid(axis='x', alpha=0.3)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('chart-reservation-recommendations.svg', bbox_inches='tight')
plt.close()
