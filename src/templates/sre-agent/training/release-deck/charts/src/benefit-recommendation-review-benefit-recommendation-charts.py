# chart-name: benefit-recommendation-charts
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

ri_recs = [
    {"type": "SQL DB BC Gen5", "region": "West US 2", "term": 3, "savings": 2400.11, "cost_before": 4365.44,
"cost_after": 1965.33, "break_even": 16.2, "qty": 10},
    {"type": "SQL DB BC Gen5", "region": "West US 2", "term": 1, "savings": 1524.59, "cost_before": 4365.44,
"cost_after": 2840.85, "break_even": 7.8, "qty": 10},
    {"type": "DSv2 VM", "region": "East US", "term": 1, "savings": 1088.52, "cost_before": 1886.68, "cost_after":
798.16, "break_even": 5.1, "qty": 9},
    {"type": "DSv3 VM", "region": "East US", "term": 3, "savings": 678.32, "cost_before": 1101.08, "cost_after":
422.76, "break_even": 13.8, "qty": 8},
    {"type": "DSv2 VM", "region": "West US", "term": 1, "savings": 622.97, "cost_before": 1605.22, "cost_after":
982.25, "break_even": 7.3, "qty": 2},
    {"type": "Ddv4 VM", "region": "West Central US", "term": 3, "savings": 606.81, "cost_before": 976.40,
"cost_after": 369.59, "break_even": 13.6, "qty": 5},
    {"type": "SQL DB HS Gen5", "region": "West US 2", "term": 3, "savings": 577.52, "cost_before": 1049.20,
"cost_after": 471.68, "break_even": 16.2, "qty": 4},
    {"type": "SQL MI GP Gen5", "region": "West US 2", "term": 3, "savings": 480.02, "cost_before": 873.09,
"cost_after": 393.07, "break_even": 16.2, "qty": 4},
    {"type": "SQL DB GP Gen5", "region": "East US", "term": 3, "savings": 480.02, "cost_before": 873.09,
"cost_after": 393.07, "break_even": 16.2, "qty": 4},
    {"type": "DSv3 VM", "region": "South Central US", "term": 3, "savings": 464.97, "cost_before": 788.43,
"cost_after": 323.46, "break_even": 14.8, "qty": 5},
    {"type": "DSv3 VM", "region": "East US", "term": 1, "savings": 444.06, "cost_before": 1101.08, "cost_after":
657.02, "break_even": 7.2, "qty": 8},
    {"type": "Dv2 HM VM", "region": "West Central US", "term": 1, "savings": 432.53, "cost_before": 1191.51,
"cost_after": 758.98, "break_even": 7.6, "qty": 5},
    {"type": "Dv2 HM VM", "region": "West US", "term": 1, "savings": 406.36, "cost_before": 1097.59, "cost_after":
691.23, "break_even": 7.6, "qty": 4},
    {"type": "Ddv4 VM", "region": "West Central US", "term": 1, "savings": 401.84, "cost_before": 976.40,
"cost_after": 574.56, "break_even": 7.1, "qty": 5},
    {"type": "Dav4 VM", "region": "West US", "term": 3, "savings": 401.51, "cost_before": 664.80, "cost_after":
263.29, "break_even": 14.3, "qty": 4},
    {"type": "DSv3 VM", "region": "Canada Central", "term": 3, "savings": 400.19, "cost_before": 637.56,
"cost_after": 237.37, "break_even": 13.4, "qty": 1},
    {"type": "SQL DB HS Gen5", "region": "West US 2", "term": 1, "savings": 367.26, "cost_before": 1049.20,
"cost_after": 681.94, "break_even": 7.8, "qty": 4},
    {"type": "DSv2 HM VM", "region": "West US 2", "term": 1, "savings": 352.18, "cost_before": 858.71,
"cost_after": 506.53, "break_even": 7.1, "qty": 2},
    {"type": "SQL MI GP Gen5", "region": "West US 2", "term": 1, "savings": 304.59, "cost_before": 873.09,
"cost_after": 568.50, "break_even": 7.8, "qty": 4},
    {"type": "SQL DB GP Gen5", "region": "East US", "term": 1, "savings": 304.59, "cost_before": 873.09,
"cost_after": 568.50, "break_even": 7.8, "qty": 4},
]

ondemand_pct = 96.54
reservation_pct = 3.46
esr = 2.80

savings_by_cat = {
    'SQL DB\nBusiness Critical': sum(r['savings'] for r in ri_recs if 'SQL DB BC' in r['type']),
    'SQL DB\nHyperScale': sum(r['savings'] for r in ri_recs if 'SQL DB HS' in r['type']),
    'SQL DB\nGeneral Purpose': sum(r['savings'] for r in ri_recs if 'SQL DB GP' in r['type']),
    'SQL MI\nGeneral Purpose': sum(r['savings'] for r in ri_recs if 'SQL MI' in r['type']),
    'DSv2\nVMs': sum(r['savings'] for r in ri_recs if r['type'] == 'DSv2 VM'),
    'DSv3\nVMs': sum(r['savings'] for r in ri_recs if r['type'] == 'DSv3 VM'),
    'Ddv4\nVMs': sum(r['savings'] for r in ri_recs if r['type'] == 'Ddv4 VM'),
    'Dv2 HM\nVMs': sum(r['savings'] for r in ri_recs if r['type'] == 'Dv2 HM VM'),
    'Dav4\nVMs': sum(r['savings'] for r in ri_recs if r['type'] == 'Dav4 VM'),
    'DSv2 HM\nVMs': sum(r['savings'] for r in ri_recs if r['type'] == 'DSv2 HM VM'),
}

fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle('Weekly Benefit Recommendation Review — May 2, 2026', fontsize=14, fontweight='bold', y=0.98)

# Panel 1: Savings by resource type
ax1 = axes[0, 0]
cats = list(savings_by_cat.keys())
vals = list(savings_by_cat.values())
colors1 = ['#1a5276' if 'SQL' in c else '#2e86c1' for c in cats]
bars = ax1.barh(cats, vals, color=colors1, edgecolor='white', linewidth=0.5)
ax1.set_xlabel('Projected Savings (USD/month)', fontsize=9)
ax1.set_title('Reservation Savings by Resource Type', fontsize=11, fontweight='bold')
ax1.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax1.invert_yaxis()
for bar, val in zip(bars, vals):
    ax1.text(bar.get_width() + 20, bar.get_y() + bar.get_height()/2, f'${val:,.0f}', va='center', fontsize=8)
ax1.tick_params(axis='y', labelsize=8)

# Panel 2: Cost Before vs After by Term
ax2 = axes[0, 1]
term1_before = sum(r['cost_before'] for r in ri_recs if r['term'] == 1)
term1_after = sum(r['cost_after'] for r in ri_recs if r['term'] == 1)
term3_before = sum(r['cost_before'] for r in ri_recs if r['term'] == 3)
term3_after = sum(r['cost_after'] for r in ri_recs if r['term'] == 3)
x = np.arange(2)
width = 0.35
bars_before = ax2.bar(x - width/2, [term1_before, term3_before], width, label='Cost Before (On-Demand)',
color='#e74c3c', alpha=0.85)
bars_after = ax2.bar(x + width/2, [term1_after, term3_after], width, label='Cost After (w/ RI)', color='#27ae60',
alpha=0.85)
ax2.set_xticks(x)
ax2.set_xticklabels(['1-Year Term', '3-Year Term'])
ax2.set_ylabel('Cost (USD/month)', fontsize=9)
ax2.set_title('RI Cost Impact by Term', fontsize=11, fontweight='bold')
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax2.legend(fontsize=8, loc='upper right')
for i, (b, a) in enumerate([(term1_before, term1_after), (term3_before, term3_after)]):
    savings_val = b - a
    pct = savings_val / b * 100
    ax2.text(i, max(b, a) + 200, f'Save ${savings_val:,.0f}\n({pct:.0f}%)', ha='center', fontsize=8,
fontweight='bold', color='#27ae60')

# Panel 3: Commitment Coverage Pie
ax3 = axes[1, 0]
sizes = [ondemand_pct, reservation_pct]
labels = [f'On-Demand\n{ondemand_pct:.1f}%', f'Reserved\n{reservation_pct:.1f}%']
colors3 = ['#e74c3c', '#27ae60']
explode = (0.05, 0.05)
wedges, texts = ax3.pie(sizes, labels=labels, colors=colors3, explode=explode, startangle=90,
textprops={'fontsize': 10})
ax3.set_title(f'Commitment Coverage (Core-Hours)\nESR: {esr:.1f}%', fontsize=11, fontweight='bold')

# Panel 4: Top 10 Recommendations
ax4 = axes[1, 1]
top10 = sorted(ri_recs, key=lambda x: x['savings'], reverse=True)[:10]
labels4 = [f"{r['type']}\n{r['region']} ({r['term']}yr)" for r in top10]
savings4 = [r['savings'] for r in top10]
break_even4 = [r['break_even'] for r in top10]
colors4 = ['#1a5276' if 'SQL' in r['type'] else '#2e86c1' for r in top10]
bars4 = ax4.barh(range(len(top10)), savings4, color=colors4, edgecolor='white', linewidth=0.5)
ax4.set_yticks(range(len(top10)))
ax4.set_yticklabels(labels4, fontsize=7)
ax4.set_xlabel('Projected Savings (USD/month)', fontsize=9)
ax4.set_title('Top 10 Reservation Recommendations', fontsize=11, fontweight='bold')
ax4.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x:,.0f}'))
ax4.invert_yaxis()
for i, (bar, be) in enumerate(zip(bars4, break_even4)):
    ax4.text(bar.get_width() + 15, bar.get_y() + bar.get_height()/2, f'BE: {be:.0f}mo', va='center', fontsize=7,
color='#666')

plt.tight_layout(rect=[0, 0, 1, 0.95])
plt.savefig('benefit-recommendation-charts.svg', bbox_inches='tight')
plt.close()
