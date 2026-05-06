# chart-name: zone-availability-by-region
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

zone_data = {
    'westus': {'No zones': 1100, '1 zone': 0, '2 zones': 0, '3 zones': 0},
    'eastus2': {'No zones': 147, '1 zone': 0, '2 zones': 0, '3 zones': 900}
}

fig2, axes2 = plt.subplots(1, 2, figsize=(14, 5))

for idx, (region, zone_counts) in enumerate(zone_data.items()):
    labels = list(zone_counts.keys())
    values = list(zone_counts.values())
    colors_pie = ['#95a5a6', '#f39c12', '#e67e22', '#2ecc71']

    wedges, texts, autotexts = axes2[idx].pie(values, labels=labels, autopct='%1.0f%%', colors=colors_pie,
startangle=90, textprops={'fontsize': 9})
    axes2[idx].set_title(f'{region} — Available VM SKU Zone Distribution', fontsize=12, fontweight='bold')

plt.tight_layout()
plt.savefig('zone-availability-by-region.svg', bbox_inches='tight')
plt.close()
