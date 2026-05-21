# chart-name: limit-type-distribution
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

services = ['App Service plans', 'Key Vault vaults', 'Network', 'SQL servers', 'Service Bus namespaces', 'Storage']
api_reported = [0, 0, 2793, 0, 0, 49]
estimated = [1, 1, 0, 1, 1, 0]

fig, ax = plt.subplots(figsize=(8, 4))
x = np.arange(len(services))
width = 0.35

bars1 = ax.bar(x - width/2, api_reported, width, label='API-Reported', color='#3498db', edgecolor='white')
bars2 = ax.bar(x + width/2, estimated, width, label='Estimated', color='#e67e22', edgecolor='white')

ax.set_ylabel('Number of Quota Entries', fontsize=10)
ax.set_title('Quota Entries by Service and Limit Type', fontsize=12, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(services, rotation=25, ha='right', fontsize=9)
ax.legend(fontsize=9)
ax.grid(axis='y', alpha=0.2)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_yscale('log')
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'{int(x):,}'))

plt.tight_layout()
plt.savefig('chart_limit_type_distribution.svg', bbox_inches='tight')
plt.close()
