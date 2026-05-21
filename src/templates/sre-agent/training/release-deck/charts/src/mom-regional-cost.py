# chart-name: regional-cost
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

regions = ['West US', 'East US', 'West US 2', 'West Central US', 'South Central US', 'Other']
reg_costs = [18542, 7802, 4925, 1803, 1602, 3633]
colors_pie = ['#0078D4', '#50E6FF', '#00B7C3', '#8661C5', '#E74856', '#FFB900']
explode = (0.05, 0, 0, 0, 0, 0)

fig, ax = plt.subplots(figsize=(8, 6))
wedges, texts, autotexts = ax.pie(reg_costs, labels=regions, autopct='%1.1f%%', startangle=90, colors=colors_pie,
explode=explode, textprops={'fontsize': 9})
for autotext in autotexts:
    autotext.set_fontsize(8)
    autotext.set_fontweight('bold')
ax.set_title('Cost by Region — April 2026', fontsize=13, fontweight='bold')
plt.tight_layout()
plt.savefig('regional-cost.svg', bbox_inches='tight')
plt.close()
