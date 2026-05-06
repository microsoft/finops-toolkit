# chart-name: adx-sku-availability
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

adx_skus = ['Standard_E4ads_v5', 'Standard_E4d_v4']
adx_status = [0, 1]
adx_colors = ['#e74c3c', '#2ecc71']
adx_labels = ['NOT Available', 'Available']
cluster_names = ['msbw-finops-hub\n(v12.0)', 'msbwtreyhub\n(v13.0)']

fig3, ax3 = plt.subplots(figsize=(8, 4))

bars = ax3.barh(range(len(adx_skus)), [1, 1], color=adx_colors, edgecolor='white', height=0.5)
ax3.set_yticks(range(len(adx_skus)))
ax3.set_yticklabels([f'{cluster_names[i]}\n{adx_skus[i]}' for i in range(len(adx_skus))], fontsize=10)
ax3.set_xlim(0, 1.5)
ax3.set_xticks([])
ax3.set_title('Azure Data Explorer SKU Availability — westus', fontsize=13, fontweight='bold')

for i, (status, label) in enumerate(zip(adx_status, adx_labels)):
    ax3.text(0.5, i, label, ha='center', va='center', fontsize=12, fontweight='bold', color='white')

ax3.set_xlabel('Microsoft.Kusto Regional SKU API Check', fontsize=10)
ax3.grid(False)

plt.tight_layout()
plt.savefig('adx-sku-availability.svg', bbox_inches='tight')
plt.close()
