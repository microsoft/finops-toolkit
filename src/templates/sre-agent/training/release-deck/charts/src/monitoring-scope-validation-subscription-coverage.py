# chart-name: subscription-coverage
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

fig, ax = plt.subplots(figsize=(6, 4))

categories = ['Monitored by Hub\n(Cost Exports)', 'Hub Infrastructure\nSubscription', 'Empty SubAccountId\nEntries']
values = [24, 1, 1]
colors_bar = ['#2ecc71', '#3498db', '#e74c3c']

bars = ax.bar(categories, values, color=colors_bar, edgecolor='white', linewidth=1.5, width=0.6)
for bar, val in zip(bars, values):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3, str(val), ha='center', va='bottom',
fontweight='bold', fontsize=14)

ax.set_ylabel('Count', fontsize=12)
ax.set_title('FinOps Hub — Subscription Coverage\n2026-05-02 18:28 UTC', fontsize=13, fontweight='bold')
ax.set_ylim(0, 28)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.yaxis.set_major_locator(mticker.MaxNLocator(integer=True))
plt.tight_layout()
plt.savefig('subscription-coverage.svg', bbox_inches='tight')
plt.close()
