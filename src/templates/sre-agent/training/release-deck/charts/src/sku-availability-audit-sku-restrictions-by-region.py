# chart-name: sku-restrictions-by-region
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from collections import defaultdict

regions_list = ['westus', 'eastus2']
unrestricted = [1100, 1047]
restricted = [73, 239]
totals = [1173, 1286]

vm_families_by_region = {
    'westus': {'NVadsv5': 9, 'DPromo': 8, 'DS': 8, 'DSPromo': 8, 'Lsv2': 6, 'G': 5, 'GS': 5, 'GS-': 4, 'Ls': 4,
'NCsv3': 3},
    'eastus2': {'M-ms': 20, 'DPromo': 16, 'DSPromo': 16, 'Lsv2': 12, 'E-adsv5': 11, 'E-asv4': 11, 'E-asv5': 11,
'G': 10, 'GS': 10, 'Mms': 10, 'NCsv3': 8}
}

all_families = defaultdict(int)
for region, families in vm_families_by_region.items():
    for fam, count in families.items():
        all_families[fam] += count

top_families = sorted(all_families.items(), key=lambda x: -x[1])[:12]
fam_names = [f[0] for f in top_families]
fam_counts_westus = [vm_families_by_region['westus'].get(f, 0) for f in fam_names]
fam_counts_eastus2 = [vm_families_by_region['eastus2'].get(f, 0) for f in fam_names]

fig, axes = plt.subplots(1, 2, figsize=(14, 5.5))

x = np.arange(len(regions_list))
width = 0.35

bars1 = axes[0].bar(x, unrestricted, width, label='Available', color='#2ecc71', edgecolor='white')
bars2 = axes[0].bar(x, restricted, width, bottom=unrestricted, label='Restricted', color='#e74c3c',
edgecolor='white')

axes[0].set_xlabel('Region', fontsize=11)
axes[0].set_ylabel('SKU Count', fontsize=11)
axes[0].set_title('Compute SKU Availability by Region', fontsize=13, fontweight='bold')
axes[0].set_xticks(x)
axes[0].set_xticklabels(regions_list, fontsize=10)
axes[0].legend(fontsize=9)

for i, (r, t) in enumerate(zip(restricted, totals)):
    pct = round(r / t * 100, 1)
    axes[0].text(i, unrestricted[i] + r + 15, f'{r} ({pct}%)', ha='center', va='bottom', fontsize=9,
fontweight='bold', color='#e74c3c')

axes[0].set_ylim(0, max(totals) * 1.15)
axes[0].grid(axis='y', alpha=0.3)

y = np.arange(len(fam_names))
height = 0.35

axes[1].barh(y + height/2, fam_counts_westus, height, label='westus', color='#3498db', edgecolor='white')
axes[1].barh(y - height/2, fam_counts_eastus2, height, label='eastus2', color='#e67e22', edgecolor='white')

axes[1].set_xlabel('Restricted SKU Count', fontsize=11)
axes[1].set_ylabel('VM Family', fontsize=11)
axes[1].set_title('Top Restricted VM Families by Region', fontsize=13, fontweight='bold')
axes[1].set_yticks(y)
axes[1].set_yticklabels(fam_names, fontsize=9)
axes[1].legend(fontsize=9)
axes[1].grid(axis='x', alpha=0.3)
axes[1].invert_yaxis()

plt.tight_layout()
plt.savefig('sku-restrictions-by-region.svg', bbox_inches='tight')
plt.close()
