# chart-name: chart2-reservation-recs
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

recs = [('SQL DB BC\n(WUS2, 3yr)', 2400.11, 55.0), ('SQL DB BC\n(WUS2, 1yr)', 1524.59, 34.9), ('DSv2\n(EUS, 1yr)',
1088.52, 57.7), ('DSv3\n(EUS, 3yr)', 678.32, 61.6), ('DSv2\n(WUS, 1yr)', 622.97, 38.8), ('Ddv4\n(WCU, 3yr)',
606.81, 62.1), ('SQL HS\n(WUS2, 3yr)', 577.52, 55.0), ('SQL GP\n(EUS, 3yr)', 480.02, 55.0), ('SQL MI GP\n(WUS2, 3yr)', 480.02, 55.0), ('DSv3\n(SCU, 3yr)', 464.97, 59.0)]

fig, ax = plt.subplots(figsize=(10, 5))
names = [r[0] for r in recs]
savings = [r[1] for r in recs]
pcts = [r[2] for r in recs]
colors_bar = ['#1e40af' if 'SQL' in n else '#059669' for n in names]

bars = ax.barh(range(len(recs) - 1, -1, -1), savings, color=colors_bar, height=0.6, edgecolor='white')
for i, (bar, pct) in enumerate(zip(bars, pcts)):
    ax.text(bar.get_width() + 20, bar.get_y() + bar.get_height() / 2, f'{pct:.0f}%', va='center', fontsize=9,
color='#333')

ax.set_yticks(range(len(recs) - 1, -1, -1))
ax.set_yticklabels(names, fontsize=8)
ax.set_xlabel('Projected Savings (USD)', fontsize=10)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax.set_title('Top 10 Reservation Recommendations by Savings\n(Blue=SQL DB/MI, Green=VM)', fontsize=12,
fontweight='bold', pad=10)
ax.grid(axis='x', alpha=0.2)
plt.tight_layout()
plt.savefig('chart2-reservation-recs.svg', bbox_inches='tight')
plt.close()
