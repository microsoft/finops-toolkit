# chart-name: budget-coverage-audit
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

fig, ax = plt.subplots(figsize=(6, 4))
categories = ['Subscription-Level\nBudget', 'RG-Level\nBudgets', 'Budget\nEnforcement Policy']
covered = [1, 0, 0]
total = [1, 20, 1]
uncovered = [t - c for c, t in zip(covered, total)]

x = np.arange(len(categories))
width = 0.35

bars1 = ax.bar(x - width/2, covered, width, label='Covered', color='#2ecc71', edgecolor='white')
bars2 = ax.bar(x + width/2, uncovered, width, label='Not Covered', color='#e74c3c', edgecolor='white')

for bar in bars1:
    h = bar.get_height()
    if h > 0:
        ax.text(bar.get_x() + bar.get_width()/2., h + 0.2, f'{int(h)}', ha='center', va='bottom',
fontweight='bold', fontsize=11)
for bar in bars2:
    h = bar.get_height()
    if h > 0:
        ax.text(bar.get_x() + bar.get_width()/2., h + 0.2, f'{int(h)}', ha='center', va='bottom',
fontweight='bold', fontsize=11)

ax.set_ylabel('Count')
ax.set_title('Budget Coverage Audit — May 2026', fontsize=13, fontweight='bold')
ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=10)
ax.legend(loc='upper right')
ax.set_ylim(0, max(total) + 3)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
plt.tight_layout()
plt.savefig('budget-coverage-audit.svg', bbox_inches='tight')
plt.close()
