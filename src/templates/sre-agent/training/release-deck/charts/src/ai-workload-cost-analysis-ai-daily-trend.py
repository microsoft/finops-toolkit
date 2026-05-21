# chart-name: ai-daily-trend
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

dates = ['04/03','04/04','04/05','04/06','04/07','04/08','04/09','04/10','04/29']
tokens = [1989226, 8995206, 8507812, 4770866, 2597968, 210700, 702242, 70039, 98727]
costs = [0.9729, 3.8793, 3.5560, 1.5782, 0.9548, 0.2159, 0.4464, 0.0557, 0.1276]

fig, ax1 = plt.subplots(figsize=(10, 4.5))
color_bar = '#4472C4'
color_line = '#ED7D31'

bars = ax1.bar(dates, [t/1e6 for t in tokens], color=color_bar, alpha=0.7, label='Tokens (M)', width=0.6)
ax1.set_xlabel('Date (April 2026)', fontsize=10)
ax1.set_ylabel('Tokens (Millions)', color=color_bar, fontsize=10)
ax1.tick_params(axis='y', labelcolor=color_bar)
ax1.set_ylim(0, 12)

ax2 = ax1.twinx()
ax2.plot(dates, costs, color=color_line, marker='o', linewidth=2, markersize=6, label='Cost ($)')
ax2.set_ylabel('Effective Cost ($)', color=color_line, fontsize=10)
ax2.tick_params(axis='y', labelcolor=color_line)
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.2f}'))
ax2.set_ylim(0, 5)

lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1 + lines2, labels1 + labels2, loc='upper right', framealpha=0.9)

plt.title('Daily AI Token Consumption & Cost — April 2026', fontsize=12, fontweight='bold', pad=10)
plt.tight_layout()
plt.savefig('ai-daily-trend.svg', bbox_inches='tight')
plt.close()
