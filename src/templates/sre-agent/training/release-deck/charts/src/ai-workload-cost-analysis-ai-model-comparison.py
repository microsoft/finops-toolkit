# chart-name: ai-model-comparison
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

models_short = ['GPT 5.2\nOutput', 'GPT 5.2\nStd Input', 'GPT 4.1 nano\nOutput', 'GPT 5.2\nCached Input', 'GPT 4.1 nano\nInput']
cost_per_1k = [14.0, 1.75, 0.44, 0.175, 0.11]
colors_bar = ['#C00000', '#ED7D31', '#FFC000', '#4472C4', '#70AD47']

fig, ax = plt.subplots(figsize=(9, 4.5))
bars = ax.barh(models_short, cost_per_1k, color=colors_bar, height=0.55)

for bar, val in zip(bars, cost_per_1k):
    ax.text(bar.get_width() + 0.2, bar.get_y() + bar.get_height()/2, f'${val:.3f}' if val < 1 else f'${val:.2f}',
va='center', fontsize=9, fontweight='bold')

ax.set_xlabel('Cost per 1K Tokens ($)', fontsize=10)
ax.set_title('Model Cost Efficiency — April 2026 (Current Month)', fontsize=12, fontweight='bold', pad=10)
ax.set_xlim(0, 18)
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.1f}'))
ax.invert_yaxis()
plt.tight_layout()
plt.savefig('ai-model-comparison.svg', bbox_inches='tight')
plt.close()
