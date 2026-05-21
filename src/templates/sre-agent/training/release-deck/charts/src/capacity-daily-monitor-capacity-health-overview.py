# chart-name: capacity-health-overview
import matplotlib.pyplot as plt

fig, axes = plt.subplots(1, 4, figsize=(14, 4))

check_areas = [
    {'name': 'VM Quota\n(westus)', 'status': 'HEALTHY', 'detail': '0/350 vCPUs\n0% utilized', 'color': '#28a745'},
    {'name': 'Non-Compute\nQuota', 'status': 'HEALTHY', 'detail': 'Storage 3/250\nNetwork <1%', 'color':
'#28a745'},
    {'name': 'Capacity\nReservations', 'status': 'N/A', 'detail': 'No CRGs\nconfigured', 'color': '#6c757d'},
    {'name': 'Hub Data\nFreshness', 'status': 'HEALTHY', 'detail': 'Costs: May 2026\nPrices: 14.3M rows', 'color':
'#28a745'},
]

for ax, area in zip(axes, check_areas):
    circle = plt.Circle((0.5, 0.55), 0.35, color=area['color'], alpha=0.15)
    ax.add_patch(circle)
    ax.text(0.5, 0.75, area['status'], ha='center', va='center', fontsize=14, fontweight='bold',
color=area['color'])
    ax.text(0.5, 0.45, area['detail'], ha='center', va='center', fontsize=9, color='#333')
    ax.text(0.5, 0.05, area['name'], ha='center', va='center', fontsize=10, fontweight='bold', color='#222')
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')

fig.suptitle('Daily Capacity Supply Chain Health — 2026-05-02', fontsize=14, fontweight='bold', y=1.02)
plt.tight_layout()
plt.savefig('capacity-health-overview.svg', bbox_inches='tight')
plt.close()
