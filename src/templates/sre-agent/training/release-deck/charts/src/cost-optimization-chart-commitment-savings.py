# chart-name: chart-commitment-savings
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4.5))

labels_cov = ['On Demand\n96.5%', 'Reservation\n3.5%']
sizes_cov = [96.54, 3.46]
colors_cov = ['#ED7D31', '#4472C4']
explode_cov = (0, 0.08)
wedges, texts = ax1.pie(sizes_cov, colors=colors_cov, explode=explode_cov, startangle=90, labels=labels_cov,
textprops={'fontsize': 11, 'fontweight': 'bold'})
ax1.set_title('Commitment Coverage\n(Core Hours)', fontsize=12, fontweight='bold')

categories = ['Negotiated\nDiscounts', 'Commitment\nDiscounts', 'Total\nSavings']
savings_vals = [34.27, 1127.22, 1161.49]
colors_sv = ['#70AD47', '#4472C4', '#ED7D31']
bars = ax2.bar(categories, savings_vals, color=colors_sv, width=0.55, edgecolor='white')
for bar, val in zip(bars, savings_vals):
    ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 20, f'${val:,.0f}', ha='center', va='bottom',
fontsize=10, fontweight='bold')
ax2.set_title('April 2026 Savings Breakdown\n(ESR: 2.80%)', fontsize=12, fontweight='bold')
ax2.set_ylabel('USD', fontsize=10)
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax2.set_ylim(0, max(savings_vals) * 1.25)
ax2.grid(axis='y', alpha=0.3)
ax2.spines['top'].set_visible(False)
ax2.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('chart-commitment-savings.svg', bbox_inches='tight')
plt.close()
