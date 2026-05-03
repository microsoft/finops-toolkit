# chart-name: suppression-health-scorecard
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(5, 5))
labels = ['Orphaned\n(Remove)', 'Active &\nCurrent']
sizes_display = [1, 0.01]
colors_pie = ['#e74c3c', '#2ecc71']
explode = (0.05, 0)
wedges, texts, autotexts = ax.pie(sizes_display, explode=explode, labels=labels, colors=colors_pie, autopct=lambda
p: f'{int(round(p / 100 * 1))}' if p > 5 else '', startangle=90, textprops={'fontsize': 11})
ax.set_title('Suppression Health\nScorecard', fontsize=13, fontweight='bold', pad=15)
centre_circle = plt.Circle((0, 0), 0.50, fc='white')
ax.add_artist(centre_circle)
ax.text(0, 0, '100%\nOrphaned', ha='center', va='center', fontsize=14, fontweight='bold', color='#e74c3c')
plt.tight_layout()
plt.savefig('suppression-health-scorecard.svg', bbox_inches='tight')
plt.close()
