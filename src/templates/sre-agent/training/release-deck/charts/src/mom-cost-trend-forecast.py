# chart-name: cost-trend-forecast
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

months = ['May25','Jun25','Jul25','Aug25','Sep25','Oct25','Nov25','Dec25','Jan26','Feb26','Mar26','Apr26']
billed = [72576, 71371, 52009, 38805, 38581, 40446, 40609, 41633, 41826, 37818, 41188, 39632]
effective = [72992, 71754, 53076, 40628, 40335, 42272, 41320, 42330, 42524, 38446, 41893, 40306]

forecast_months = ['May26','Jun26','Jul26']
forecast_values = [41100, 41050, 41000]

fig, ax = plt.subplots(figsize=(12, 5))
x = np.arange(len(months))
ax.bar(x, effective, color='#0078D4', alpha=0.85, label='Effective Cost', width=0.6)
ax.plot(x, billed, color='#E74856', marker='o', linewidth=2, markersize=5, label='Billed Cost')

fx = np.arange(len(months), len(months) + len(forecast_months))
ax.bar(fx, forecast_values, color='#0078D4', alpha=0.35, hatch='//', width=0.6, label='Forecast (Expected)')

fc_arr = np.array(forecast_values)
ax.fill_between(fx, fc_arr * 0.95, fc_arr * 1.05, alpha=0.15, color='#0078D4', label='Forecast ±5%')

all_labels = months + forecast_months
ax.set_xticks(np.arange(len(all_labels)))
ax.set_xticklabels(all_labels, rotation=45, ha='right', fontsize=8)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, p: f'${x/1000:.0f}K'))
ax.set_title('12-Month Cost Trend + 90-Day Forecast', fontsize=14, fontweight='bold')
ax.set_ylabel('Monthly Cost (USD)')
ax.legend(loc='upper right', fontsize=8)
ax.grid(axis='y', alpha=0.3)
ax.set_ylim(0, 85000)
plt.tight_layout()
plt.savefig('cost-trend-forecast.svg', bbox_inches='tight')
plt.close()
