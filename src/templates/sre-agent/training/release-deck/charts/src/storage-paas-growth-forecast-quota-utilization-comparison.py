# chart-name: quota-utilization-comparison
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Patch

labels = ["Storage Accounts\n(westus)", "Storage Accounts\n(eastus2)", "Storage Accounts\n(westus2)", "Public IP Addresses\n(westus)", "Virtual Networks\n(westus)", "Route Tables\n(westus)", "NSGs\n(westus)", "Virtual Networks\n(eastus2)", "NSGs\n(eastus2)", "Network Interfaces\n(westus)", "Key Vault vaults estimated...\n(unknown)", "Private Endpoints\n(westus)"]
utils = [1.2, 0.8, 0.4, 0.3, 0.2, 0.2, 0.1, 0.1, 0.1, 0.0, 0.0, 0.0]
currents = [3, 2, 1, 3, 2, 2, 7, 1, 3, 12, 1, 4]
limits = [250, 250, 250, 1000, 1000, 1000, 5000, 1000, 5000, 65536, 5000, 65536]
limit_types = ["api_reported", "api_reported", "api_reported", "api_reported", "api_reported", "api_reported",
"api_reported", "api_reported", "api_reported", "api_reported", "estimated", "api_reported"]

colors_bar = ['#2196F3' if lt == 'api_reported' else '#FF9800' for lt in limit_types]

fig1, ax1 = plt.subplots(figsize=(10, max(6, len(labels) * 0.45)))
y_pos = np.arange(len(labels))
bars = ax1.barh(y_pos, utils, color=colors_bar, edgecolor='white', height=0.7)

for i, (bar, curr, lim, util) in enumerate(zip(bars, currents, limits, utils)):
    ax1.text(bar.get_width() + 0.1, bar.get_y() + bar.get_height() / 2, f'{curr}/{lim} ({util:.1f}%)', va='center',
fontsize=8, color='#333')

ax1.set_yticks(y_pos)
ax1.set_yticklabels(labels, fontsize=8)
ax1.set_xlabel('Utilization %', fontsize=10)
ax1.set_title('Non-Compute Quota Utilization — Active Resources\n(Subscription: cab7feeb…51ff | May 2026)',
fontsize=11, fontweight='bold')
ax1.set_xlim(0, max(utils) * 1.5 if utils else 10)
ax1.invert_yaxis()
ax1.axvline(x=80, color='red', linestyle='--', alpha=0.5, label='80% threshold')

legend_elements = [Patch(facecolor='#2196F3', label='API-reported limit'), Patch(facecolor='#FF9800',
label='Estimated limit'), plt.Line2D([0], [0], color='red', linestyle='--', alpha=0.5, label='80% risk threshold')]
ax1.legend(handles=legend_elements, fontsize=8, loc='lower right')

plt.tight_layout()
plt.savefig('quota-utilization-comparison.svg', bbox_inches='tight')
plt.close()
