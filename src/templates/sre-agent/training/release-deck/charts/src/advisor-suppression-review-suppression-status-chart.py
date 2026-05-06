# chart-name: suppression-status-chart
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(6, 4))
statuses = ['Orphaned\n(Resource Deleted)', 'No Expiration\n(TTL = -1)', 'Missing Owner', 'Missing\nJustification',
'Recommendation\nDeleted']
counts = [1, 1, 1, 1, 1]
colors_status = ['#e74c3c', '#e67e22', '#f39c12', '#f39c12', '#e74c3c']
bars = ax.barh(statuses, counts, color=colors_status, edgecolor='white', height=0.6)
ax.set_xlim(0, 1.5)
ax.set_xlabel('Count', fontsize=11)
ax.set_title('Advisor Suppression Governance Issues\n(1 Suppression Found)', fontsize=13, fontweight='bold',
pad=12)
for bar, c in zip(bars, counts):
    ax.text(bar.get_width() + 0.05, bar.get_y() + bar.get_height() / 2, str(c), va='center', fontsize=11,
fontweight='bold')
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_xticks([0, 1])
plt.tight_layout()
plt.savefig('suppression-status-chart.svg', bbox_inches='tight')
plt.close()
