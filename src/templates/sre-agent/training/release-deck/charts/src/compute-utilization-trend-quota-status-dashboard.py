# chart-name: quota-status-dashboard
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(10, 4))
ax.axis('off')

table_data = [
    ['Region', 'vCPU Limit', 'Used', 'Utilization', 'Resources', 'Status'],
    ['westus', '350', '0', '0%', '70', 'Healthy'],
    ['eastus2', '100', '0', '0%', '35', 'Healthy'],
    ['eastus', '100', '0', '0%', '3', 'Healthy'],
    ['westus2', '100', '0', '0%', '3', 'Healthy'],
    ['westus3', '150', '0', '0%', '1', 'Healthy'],
    ['au-southeast', '100', '0', '0%', '1', 'Healthy'],
    ['swedencentral', '100', '0', '0%', '1', 'Healthy'],
]

table = ax.table(cellText=table_data[1:], colLabels=table_data[0], cellLoc='center', loc='center', colWidths=[0.18,
0.13, 0.08, 0.13, 0.12, 0.16])

table.auto_set_font_size(False)
table.set_fontsize(10)
table.scale(1, 1.6)

for j in range(len(table_data[0])):
    cell = table[0, j]
    cell.set_facecolor('#1976d2')
    cell.set_text_props(color='white', fontweight='bold')

for i in range(1, len(table_data)):
    for j in range(len(table_data[0])):
        cell = table[i, j]
        cell.set_facecolor('#f5f5f5' if i % 2 == 0 else 'white')

ax.set_title('Weekly Compute Utilization Summary — 2026-05-02\nSubscription: Non-Prod-Workloads (cab7feeb...)',
fontsize=13, fontweight='bold', pad=20)

plt.savefig('quota-status-dashboard.svg', bbox_inches='tight', facecolor='white')
plt.close()
