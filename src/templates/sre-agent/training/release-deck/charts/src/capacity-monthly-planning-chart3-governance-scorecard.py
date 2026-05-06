# chart-name: chart3-governance-scorecard
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(8, 5))

categories = ['Budget\nAlerts', 'Anomaly\nAlerts', 'KQL\nAlerts', 'Tag\nGovernance', 'Quota\nGroups',
'CRG\nDeployed']
scores = [1, 0, 0, 0, 0, 0]
colors_gov = ['#059669' if s else '#dc2626' for s in scores]
labels_gov = ['1 Budget', 'MISSING', 'MISSING', 'No Tags', 'None', 'None']

bars = ax.bar(categories, [1] * 6, color=colors_gov, width=0.5, edgecolor='white', linewidth=2)
for bar, label in zip(bars, labels_gov):
    ax.text(bar.get_x() + bar.get_width() / 2, 0.5, label, ha='center', va='center', fontsize=10,
fontweight='bold', color='white')

ax.set_ylim(0, 1.3)
ax.set_yticks([])
ax.set_title('Governance Compliance Scorecard — May 2026', fontsize=12, fontweight='bold', pad=10)
ax.set_ylabel('')

total = sum(scores)
ax.text(0.98, 1.15, f'Score: {total}/6 ({total / 6 * 100:.0f}%)', transform=ax.transAxes, fontsize=14,
fontweight='bold', ha='right', color='#dc2626')

plt.tight_layout()
plt.savefig('chart3-governance-scorecard.svg', bbox_inches='tight')
plt.close()
