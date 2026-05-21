# chart-name: chart4-commitment-monthly
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4.5))

sizes = [96.08, 3.92]
labels_pie = ['On-Demand\n96.1%', 'Reservation\n3.9%']
colors_pie = ['#f59e0b', '#2563eb']
explode = (0.05, 0)
ax1.pie(sizes, labels=labels_pie, colors=colors_pie, explode=explode, startangle=90, autopct='',
textprops={'fontsize': 11, 'fontweight': 'bold'})
ax1.set_title('Commitment Discount Coverage\n(Core-Hours, 90-day)', fontsize=11, fontweight='bold', pad=10)

month_labels = ['Nov\n2025', 'Dec', 'Jan\n2026', 'Feb', 'Mar', 'Apr']
month_vals = [1377.34, 1365.50, 1371.74, 1373.07, 1351.37, 1343.73]
colors_month = ['#3b82f6'] * 6
bars = ax2.bar(month_labels, month_vals, color=colors_month, width=0.5, edgecolor='white')
for bar, val in zip(bars, month_vals):
    ax2.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 2, f'${val:,.0f}', ha='center', va='bottom',
fontsize=8, fontweight='bold')
ax2.set_ylim(1300, 1420)
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax2.set_title('Monthly Avg Daily Cost (6-month)', fontsize=11, fontweight='bold', pad=10)
ax2.set_ylabel('Avg Daily Cost (USD)', fontsize=9)
ax2.grid(axis='y', alpha=0.2)

plt.tight_layout()
plt.savefig('chart4-commitment-monthly.svg', bbox_inches='tight')
plt.close()
