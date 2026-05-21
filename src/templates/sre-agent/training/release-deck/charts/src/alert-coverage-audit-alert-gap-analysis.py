# chart-name: alert-gap-analysis
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

fig2, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

severities = ['Critical', 'High', 'Medium']
counts = [1, 2, 2]
sev_colors = ['#DC3545', '#FD7E14', '#FFC107']

bars2 = ax1.bar(severities, counts, color=sev_colors, edgecolor='white', width=0.5)
for bar, count in zip(bars2, counts):
    ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.05, str(count), ha='center', va='bottom',
fontweight='bold', fontsize=13)

ax1.set_ylabel('Number of Findings', fontsize=11)
ax1.set_title('Alert Coverage Findings by Severity', fontsize=12, fontweight='bold')
ax1.set_ylim(0, max(counts) + 1)
ax1.spines['top'].set_visible(False)
ax1.spines['right'].set_visible(False)

alert_types = ['Budget Alerts\n(6 rules)', 'Service Health\n(1 rule)', 'App Insights\n(4 rules)', 'Cost Anomaly\n(0 rules)', 'KQL Alerts\n(0 rules)']
alert_counts = [6, 1, 4, 0, 0]
pie_colors = ['#28A745', '#28A745', '#28A745', '#DC3545', '#DC3545']

non_zero = [(t, c, col) for t, c, col in zip(alert_types, alert_counts, pie_colors) if c > 0]
zero_items = [(t, c) for t, c in zip(alert_types, alert_counts) if c == 0]

if non_zero:
    labels_nz, counts_nz, colors_nz = zip(*non_zero)
    wedges, texts, autotexts = ax2.pie(counts_nz, labels=labels_nz, colors=colors_nz, autopct='%1.0f%%',
startangle=90, textprops={'fontsize': 9})
    for t in autotexts:
        t.set_fontweight('bold')
        t.set_color('white')

if zero_items:
    missing_text = "Missing: " + ", ".join([t.replace('\n', ' ') for t, _ in zero_items])
    ax2.text(0, -1.4, missing_text, ha='center', va='center', fontsize=9, color='#DC3545', fontweight='bold',
bbox=dict(boxstyle='round,pad=0.3', facecolor='#FFF3CD', edgecolor='#DC3545'))

ax2.set_title('Alert Rule Distribution', fontsize=12, fontweight='bold')

plt.tight_layout()
plt.savefig('alert-gap-analysis.svg', bbox_inches='tight')
plt.close()
