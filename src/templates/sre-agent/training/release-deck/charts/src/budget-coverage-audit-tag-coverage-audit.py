# chart-name: tag-coverage-audit
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

fig, ax = plt.subplots(figsize=(6, 4))
tag_categories = ['Any Tag', 'Environment', 'Owner', 'Cost Center']
tagged = [6, 2, 0, 0]
not_tagged = [14, 18, 20, 20]
total_rgs = 20

x = np.arange(len(tag_categories))
bars_t = ax.barh(x, tagged, height=0.4, label='Tagged', color='#2ecc71', edgecolor='white')
bars_nt = ax.barh(x, not_tagged, height=0.4, left=tagged, label='Not Tagged', color='#e74c3c', edgecolor='white',
alpha=0.8)

for i, (t, nt) in enumerate(zip(tagged, not_tagged)):
    pct = t / total_rgs * 100
    ax.text(total_rgs + 0.5, i, f'{pct:.0f}%', ha='left', va='center', fontweight='bold', fontsize=10,
color='#2ecc71' if pct >= 50 else '#e74c3c')

ax.set_yticks(x)
ax.set_yticklabels(tag_categories, fontsize=11)
ax.set_xlabel('Resource Groups (out of 20)')
ax.set_title('Resource Group Tag Coverage — May 2026', fontsize=13, fontweight='bold')
ax.legend(loc='lower right')
ax.set_xlim(0, 24)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('tag-coverage-audit.svg', bbox_inches='tight')
plt.close()
