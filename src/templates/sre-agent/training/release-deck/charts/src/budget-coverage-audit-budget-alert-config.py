# chart-name: budget-alert-config
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(6, 3.5))
alert_types = ['Actual 80%', 'Actual 125%', 'Actual 150%', 'Actual 200%', 'Forecast 100%', 'Forecast 125%']
colors_list = ['#27ae60', '#f39c12', '#e67e22', '#e74c3c', '#3498db', '#2980b9']
thresholds = [80, 125, 150, 200, 100, 125]

bars = ax.barh(range(len(alert_types)), thresholds, color=colors_list, edgecolor='white', height=0.6)
for i, (bar, t) in enumerate(zip(bars, thresholds)):
    ax.text(bar.get_width() + 2, bar.get_y() + bar.get_height()/2, f'{t}%', ha='left', va='center',
fontweight='bold', fontsize=10)

ax.set_yticks(range(len(alert_types)))
ax.set_yticklabels(alert_types, fontsize=10)
ax.set_xlabel('Threshold (%)')
ax.set_title('Budget Alert Thresholds — FDPOAzureBudget', fontsize=12, fontweight='bold')
ax.axvline(x=100, color='gray', linestyle='--', alpha=0.5, label='100% line')
ax.set_xlim(0, 220)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('budget-alert-config.svg', bbox_inches='tight')
plt.close()
