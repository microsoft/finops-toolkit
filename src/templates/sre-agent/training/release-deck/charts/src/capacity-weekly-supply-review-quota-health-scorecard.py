# chart-name: quota-health-scorecard
import matplotlib.pyplot as plt
import numpy as np

categories = ['VM Compute\n(49 regions)', 'Storage\n(all regions)', 'Network\n(all regions)', 'Key Vault\n(subscription)']
green = [10599, 2839, 0, 1]
yellow = [0, 0, 0, 0]
red = [0, 0, 7, 0]

fig, ax = plt.subplots(figsize=(8, 4.5))
x = np.arange(len(categories))
width = 0.55

b1 = ax.bar(x, green, width, label='Healthy (<80%)', color='#2ecc71', edgecolor='white')
b2 = ax.bar(x, yellow, width, bottom=green, label='Warning (80-95%)', color='#f39c12', edgecolor='white')
b3 = ax.bar(x, red, width, bottom=[g + y for g, y in zip(green, yellow)], label='Critical (>95%)', color='#e74c3c',
edgecolor='white')

ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=9)
ax.set_ylabel('Quota Entries', fontsize=10)
ax.set_title('Weekly Quota Health Scorecard — May 2, 2026', fontsize=13, fontweight='bold', pad=12)
ax.legend(loc='upper right', fontsize=8)

ax.annotate('7 Network Watchers\n(cosmetic — auto-provisioned)', xy=(2, 7), xytext=(2.5, 1500), fontsize=7,
color='#999', arrowprops=dict(arrowstyle='->', color='#ccc'), ha='center')

ax.set_ylim(0, max(green) * 1.25)
ax.grid(axis='y', alpha=0.2)
plt.tight_layout()
plt.savefig('quota-health-scorecard.svg', bbox_inches='tight')
plt.close()
