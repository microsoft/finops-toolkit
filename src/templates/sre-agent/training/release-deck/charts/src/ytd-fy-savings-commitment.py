# chart-name: fy-savings-commitment
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4.5))

savings_cats = ['Negotiated\nDiscount', 'Commitment\nDiscount', 'Uncaptured\nOpportunity']
savings_vals = [302, 15180, 423131 - 15441]
bar_colors = ['#50E6FF', '#0078D4', '#FFB900']
ax1.bar(savings_cats, savings_vals, color=bar_colors, edgecolor='white', width=0.5)
ax1.set_ylabel('USD', fontsize=10)
ax1.set_title('Savings Breakdown (FY YTD)', fontsize=11, fontweight='bold')
ax1.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x/1000:,.0f}K'))
ax1.text(1, max(savings_vals)*0.85, 'ESR: 3.5%', fontsize=14, fontweight='bold', color='#D83B01', ha='center',
bbox=dict(boxstyle='round,pad=0.3', facecolor='#FFF4CE', edgecolor='#D83B01'))

commit_labels = ['On-Demand\n91.0%', 'Reservation\n9.0%']
commit_vals = [91.0, 9.0]
commit_colors = ['#D83B01', '#107C10']
ax2.pie(commit_vals, labels=commit_labels, colors=commit_colors, startangle=90, textprops={'fontsize': 10,
'fontweight': 'bold'}, wedgeprops={'edgecolor': 'white', 'linewidth': 2})
ax2.set_title('Compute Commitment Coverage', fontsize=11, fontweight='bold')
plt.tight_layout()
plt.savefig('fy-savings-commitment.svg', bbox_inches='tight')
plt.close()
