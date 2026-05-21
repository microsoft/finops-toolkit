# chart-name: savings-commitment
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

fig, axes = plt.subplots(1, 2, figsize=(12, 5))

categories = ['Negotiated\nDiscount', 'Commitment\nDiscount', 'Total\nSavings']
values = [34, 1127, 1161]
colors_bar = ['#50E6FF', '#0078D4', '#00B7C3']
axes[0].bar(categories, values, color=colors_bar, width=0.5)
for i, v in enumerate(values):
    axes[0].text(i, v + 20, f'${v:,.0f}', ha='center', fontsize=10, fontweight='bold')
axes[0].set_title('Savings Breakdown (April 2026)', fontsize=11, fontweight='bold')
axes[0].set_ylabel('Savings (USD)')
axes[0].yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
axes[0].grid(axis='y', alpha=0.3)

labels = ['On-Demand\n96.5%', 'Reserved\n3.5%']
sizes = [96.5, 3.5]
colors_gauge = ['#E74856', '#00B7C3']
axes[1].pie(sizes, labels=labels, colors=colors_gauge, autopct='', startangle=90, textprops={'fontsize': 11,
'fontweight': 'bold'})
axes[1].set_title('Commitment Coverage vs Target (60-70%)', fontsize=11, fontweight='bold')

plt.tight_layout()
plt.savefig('savings-commitment.svg', bbox_inches='tight')
plt.close()
