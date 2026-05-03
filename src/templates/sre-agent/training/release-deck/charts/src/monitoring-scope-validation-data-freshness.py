# chart-name: data-freshness
import matplotlib.pyplot as plt

fig, (ax_left, ax_right) = plt.subplots(1, 2, figsize=(10, 4.5), gridspec_kw={'width_ratios': [3, 2]})

functions = ['Costs()', 'Prices()', 'Recommendations()', 'Transactions()']
row_counts = [1266578, 14343006, 45, 0]
display_counts = [max(c, 0.5) for c in row_counts]
bar_colors = ['#2ecc71', '#2ecc71', '#f39c12', '#e74c3c']

bars = ax_left.barh(functions, display_counts, color=bar_colors, edgecolor='white', linewidth=1.5)
ax_left.set_xscale('log')
ax_left.set_xlim(0.1, 50000000)
for bar, val in zip(bars, row_counts):
    label = f'{val:,}' if val > 0 else '0 (EMPTY)'
    ax_left.text(max(bar.get_width() * 1.3, 1), bar.get_y() + bar.get_height()/2, label, ha='left', va='center',
fontsize=10, fontweight='bold')
ax_left.set_xlabel('Row Count (log scale)', fontsize=11)
ax_left.set_title('Hub Function Row Counts', fontsize=12, fontweight='bold')
ax_left.spines['top'].set_visible(False)
ax_left.spines['right'].set_visible(False)
ax_left.invert_yaxis()

staleness_labels = ['Costs()', 'Prices()', 'Rec.()', 'Trans.()']
staleness_colors = ['#2ecc71', '#95a5a6', '#95a5a6', '#e74c3c']
staleness_display = ['1 day\n(Healthy)', 'N/A\n(No date col)', 'N/A\n(Present)', 'EMPTY\n(0 rows)']

for i, (label, color, display) in enumerate(zip(staleness_labels, staleness_colors, staleness_display)):
    ax_right.barh(i, 1, color=color, edgecolor='white', linewidth=1.5, height=0.6)
    ax_right.text(0.5, i, display, ha='center', va='center', fontsize=10, fontweight='bold', color='white')

ax_right.set_yticks(range(len(staleness_labels)))
ax_right.set_yticklabels(staleness_labels)
ax_right.set_xlim(0, 1)
ax_right.set_xticks([])
ax_right.set_title('Data Staleness', fontsize=12, fontweight='bold')
ax_right.spines['top'].set_visible(False)
ax_right.spines['right'].set_visible(False)
ax_right.spines['bottom'].set_visible(False)
ax_right.invert_yaxis()

plt.suptitle('FinOps Hub Data Freshness — 2026-05-02 18:28 UTC', fontsize=14, fontweight='bold', y=1.02)
plt.tight_layout()
plt.savefig('data-freshness.svg', bbox_inches='tight')
plt.close()
