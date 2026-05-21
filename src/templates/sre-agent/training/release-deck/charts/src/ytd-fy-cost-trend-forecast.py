# chart-name: fy-cost-trend-forecast
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

months = ['Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May*', 'Jun*']
billed = [52009, 38805, 38581, 40446, 40609, 41633, 41826, 37818, 41188, 39632, None, None]
effective = [53076, 40628, 40335, 42272, 41320, 42330, 42524, 38446, 41893, 40306, None, None]
forecast_may = 38099
forecast_jun = 36060

fig, ax = plt.subplots(figsize=(10, 5))
ax.plot(months[:10], effective[:10], 'o-', color='#0078D4', linewidth=2.5, markersize=7, label='Effective Cost (Actual)', zorder=5)
ax.plot(months[:10], billed[:10], 's--', color='#50E6FF', linewidth=1.5, markersize=5, label='Billed Cost (Actual)', alpha=0.7, zorder=4)
ax.plot(months[9:], [effective[9], forecast_may, forecast_jun], 'o--', color='#FF8C00', linewidth=2, markersize=7,
label='Forecast (Expected)', zorder=5)
ax.fill_between(months[9:], [effective[9]*0.95, forecast_may*0.95, forecast_jun*0.95], [effective[9]*1.05,
forecast_may*1.05, forecast_jun*1.05], color='#FF8C00', alpha=0.15, label='Forecast Range (±5%)')
ax.annotate('Jul spike\n$53.1K', xy=(0, 53076), xytext=(1.5, 50000), arrowprops=dict(arrowstyle='->', color='red',
lw=1.5), fontsize=8, color='red', fontweight='bold')
ax.set_ylabel('Monthly Cost (USD)', fontsize=11)
ax.set_title('FY25-26 Monthly Cost Trend & End-of-Year Forecast', fontsize=13, fontweight='bold')
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x/1000:,.0f}K'))
ax.legend(loc='upper right', fontsize=8)
ax.grid(True, alpha=0.3)
ax.set_ylim(30000, 58000)
plt.tight_layout()
plt.savefig('fy-cost-trend-forecast.svg', bbox_inches='tight')
plt.close()
