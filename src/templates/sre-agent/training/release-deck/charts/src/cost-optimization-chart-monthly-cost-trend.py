# chart-name: chart-monthly-cost-trend
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

months = ['Feb 2026', 'Mar 2026', 'Apr 2026']
effective_cost = [38445.86, 41892.63, 40306.47]

fig, ax = plt.subplots(figsize=(7, 4))
bars = ax.bar(months, effective_cost, color=['#4472C4', '#4472C4', '#ED7D31'], width=0.5, edgecolor='white')
for bar, val in zip(bars, effective_cost):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 300, f'${val:,.0f}', ha='center', va='bottom',
fontsize=11, fontweight='bold')
ax.set_title('Monthly Effective Cost Trend', fontsize=14, fontweight='bold', pad=12)
ax.set_ylabel('Effective Cost (USD)', fontsize=11)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax.set_ylim(0, max(effective_cost) * 1.15)
ax.grid(axis='y', alpha=0.3)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('chart-monthly-cost-trend.svg', bbox_inches='tight')
plt.close()
