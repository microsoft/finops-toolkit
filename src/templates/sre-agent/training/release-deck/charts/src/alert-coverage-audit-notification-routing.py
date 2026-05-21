# chart-name: notification-routing
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

fig3, ax3 = plt.subplots(figsize=(8, 4))

routing_categories = ['Budget Alerts', 'Service Health', 'App Insights\nSmart Detection']
single_person = [1, 1, 0]
team_escalation = [0, 0, 1]

x = np.arange(len(routing_categories))
width = 0.35

bars_single = ax3.bar(x - width/2, single_person, width, label='Single Recipient (AGOwner)', color='#FFC107',
edgecolor='white')
bars_team = ax3.bar(x + width/2, team_escalation, width, label='Team/Role-Based (AGManager or RBAC)',
color='#28A745', edgecolor='white')

ax3.set_ylabel('Alert Rule Count', fontsize=11)
ax3.set_title('Notification Routing — Single vs Team Coverage', fontsize=12, fontweight='bold')
ax3.set_xticks(x)
ax3.set_xticklabels(routing_categories, fontsize=10)
ax3.set_ylim(0, 2)
ax3.legend(loc='upper right', fontsize=9)
ax3.spines['top'].set_visible(False)
ax3.spines['right'].set_visible(False)

ax3.annotate('Budget & Health alerts route\nto single person only — no escalation', xy=(0.5, 1), xytext=(1.5, 1.6),
arrowprops=dict(arrowstyle='->', color='#DC3545'), fontsize=9, color='#DC3545', fontweight='bold', ha='center')

plt.tight_layout()
plt.savefig('notification-routing.svg', bbox_inches='tight')
plt.close()
