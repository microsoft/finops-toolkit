# chart-name: alert-coverage-matrix
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

fig, ax = plt.subplots(figsize=(10, 5))

alert_categories = ['Cost Anomaly\nDetection', 'Budget\nAlerts', 'Scheduled Query\nRules (KQL)', 'Service Health\nAlerts', 'App Insights\nFailure Anomalies', 'Action Groups\nConfigured']
status = [0, 2, 0, 2, 2, 1]
colors_map = {0: '#DC3545', 1: '#FFC107', 2: '#28A745'}
labels_map = {0: 'MISSING', 1: 'PARTIAL', 2: 'COVERED'}
bar_colors = [colors_map[s] for s in status]

bars = ax.barh(alert_categories, [1]*len(alert_categories), color=bar_colors, edgecolor='white', height=0.6)

for i, (bar, s) in enumerate(zip(bars, status)):
    ax.text(0.5, bar.get_y() + bar.get_height()/2, labels_map[s], ha='center', va='center', fontweight='bold',
fontsize=11, color='white' if s != 1 else '#333')

ax.set_xlim(0, 1)
ax.set_xticks([])
ax.set_title('Cost Anomaly Alert Coverage — Non-Prod-Workloads', fontsize=14, fontweight='bold', pad=15)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['bottom'].set_visible(False)

legend_patches = [mpatches.Patch(color='#28A745', label='Covered'), mpatches.Patch(color='#FFC107',
label='Partial'), mpatches.Patch(color='#DC3545', label='Missing')]
ax.legend(handles=legend_patches, loc='lower right', frameon=True, fontsize=10)

plt.tight_layout()
plt.savefig('alert-coverage-matrix.svg', bbox_inches='tight')
plt.close()
