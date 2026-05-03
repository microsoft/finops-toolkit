# chart-name: fy-regional-cost
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

regions = ['West US', 'East US', 'West US 2', 'West Central US', 'South Central US', 'Other']
reg_costs = [188169, 76859, 62640, 19418, 15396, 423131 - 188169 - 76859 - 62640 - 19418 - 15396]
reg_colors = ['#0078D4', '#50E6FF', '#00BCF2', '#FF8C00', '#FFB900', '#B4D8E7']

fig, ax = plt.subplots(figsize=(7, 5))
wedges, texts, autotexts = ax.pie(reg_costs, labels=regions, autopct='%1.1f%%', colors=reg_colors, startangle=140,
pctdistance=0.8, textprops={'fontsize': 9})
for t in autotexts:
    t.set_fontsize(8)
    t.set_fontweight('bold')
ax.set_title('FY25-26 Cost by Region', fontsize=13, fontweight='bold')
plt.tight_layout()
plt.savefig('fy-regional-cost.svg', bbox_inches='tight')
plt.close()
