# chart-name: quarterly-maturity-radar
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

categories = ['Forecast', 'Procure', 'Allocate', 'Monitor']
current_scores = [1, 1, 1, 2]
target_scores = [2, 2, 2, 3]

angles = np.linspace(0, 2*np.pi, len(categories), endpoint=False).tolist()
current_scores_r = current_scores + [current_scores[0]]
target_scores_r = target_scores + [target_scores[0]]
angles += angles[:1]

fig, ax = plt.subplots(figsize=(5, 5), subplot_kw=dict(polar=True))
ax.fill(angles, current_scores_r, alpha=0.25, color='#EF5350')
ax.plot(angles, current_scores_r, 'o-', color='#EF5350', linewidth=2, label='Current (Q2 2026)')
ax.fill(angles, target_scores_r, alpha=0.15, color='#66BB6A')
ax.plot(angles, target_scores_r, 'o--', color='#66BB6A', linewidth=2, label='Target (Q3 2026)')

ax.set_xticks(angles[:-1])
ax.set_xticklabels(categories, fontsize=12, fontweight='bold')
ax.set_yticks([1, 2, 3])
ax.set_yticklabels(['Crawl', 'Walk', 'Run'], fontsize=9)
ax.set_ylim(0, 3.5)
ax.set_title('Supply Chain Maturity Scorecard', fontsize=13, fontweight='bold', pad=20)
ax.legend(loc='lower right', fontsize=9, bbox_to_anchor=(1.2, -0.05))

fig.tight_layout()
fig.savefig('quarterly-maturity-radar.svg', bbox_inches='tight')
plt.close()
