# chart-name: recommendations-by-category
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

fig, ax = plt.subplots(figsize=(7, 4.5))
categories = ['Security', 'Cost', 'High\nAvailability', 'Operational\nExcellence']
high_counts = [56, 29, 20, 1]
medium_counts = [44, 0, 21, 0]
low_counts = [13, 0, 1, 0]

x = np.arange(len(categories))
width = 0.25
bars_h = ax.bar(x - width, high_counts, width, label='High Impact', color='#e74c3c', edgecolor='white')
bars_m = ax.bar(x, medium_counts, width, label='Medium Impact', color='#f39c12', edgecolor='white')
bars_l = ax.bar(x + width, low_counts, width, label='Low Impact', color='#3498db', edgecolor='white')

for bars in [bars_h, bars_m, bars_l]:
    for bar in bars:
        h = bar.get_height()
        if h > 0:
            ax.text(bar.get_x() + bar.get_width() / 2, h + 0.8, str(int(h)), ha='center', va='bottom', fontsize=9,
fontweight='bold')

ax.set_ylabel('Recommendation Count', fontsize=11)
ax.set_title('Active Advisor Recommendations by Category & Impact\n(185 Total — 0 Suppressed)', fontsize=12,
fontweight='bold', pad=12)
ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=10)
ax.legend(loc='upper right', fontsize=9)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('recommendations-by-category.svg', bbox_inches='tight')
plt.close()
