# chart-name: ai-mom-comparison
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

fig, axes = plt.subplots(1, 3, figsize=(13, 4.5))

categories = ['March', 'April']
token_volumes = [75.33, 27.96]
bars1 = axes[0].bar(categories, token_volumes, color=['#4472C4', '#ED7D31'], width=0.5)
for bar, val in zip(bars1, token_volumes):
    axes[0].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1.5, f'{val:.1f}M', ha='center', fontsize=11,
fontweight='bold')
axes[0].set_ylabel('Tokens (Millions)', fontsize=10)
axes[0].set_title('Token Volume', fontsize=11, fontweight='bold')
axes[0].set_ylim(0, 95)
axes[0].annotate('-62.9%', xy=(1, token_volumes[1]), xytext=(1.3, 55), fontsize=12, fontweight='bold',
color='#C00000', arrowprops=dict(arrowstyle='->', color='#C00000'))

costs_mom = [33.92, 11.82]
bars2 = axes[1].bar(categories, costs_mom, color=['#4472C4', '#ED7D31'], width=0.5)
for bar, val in zip(bars2, costs_mom):
    axes[1].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.8, f'${val:.2f}', ha='center', fontsize=11,
fontweight='bold')
axes[1].set_ylabel('Effective Cost ($)', fontsize=10)
axes[1].set_title('Total AI Cost', fontsize=11, fontweight='bold')
axes[1].set_ylim(0, 45)
axes[1].yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
axes[1].annotate('-65.1%', xy=(1, costs_mom[1]), xytext=(1.3, 25), fontsize=12, fontweight='bold', color='#C00000',
arrowprops=dict(arrowstyle='->', color='#C00000'))

model_counts = [19, 5]
bars3 = axes[2].bar(categories, model_counts, color=['#4472C4', '#ED7D31'], width=0.5)
for bar, val in zip(bars3, model_counts):
    axes[2].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5, str(val), ha='center', fontsize=11,
fontweight='bold')
axes[2].set_ylabel('Model Variants', fontsize=10)
axes[2].set_title('Model Diversity', fontsize=11, fontweight='bold')
axes[2].set_ylim(0, 25)
axes[2].annotate('-73.7%', xy=(1, model_counts[1]), xytext=(1.3, 14), fontsize=12, fontweight='bold',
color='#C00000', arrowprops=dict(arrowstyle='->', color='#C00000'))

plt.suptitle('Month-over-Month: March vs April 2026', fontsize=13, fontweight='bold', y=1.02)
plt.tight_layout()
plt.savefig('ai-mom-comparison.svg', bbox_inches='tight')
plt.close()
