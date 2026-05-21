# chart-name: ninety-day-forecast
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime, timedelta

forecast_items = [("Network: Network Interfaces", 12, 65536, "westus"), ("Network: NSGs", 10, 10000, "westus, eastus2"), ("Storage: Storage Accounts", 6, 750, "westus, eastus2, westus2"), ("Network: Private Endpoints", 4,
65536, "westus")]

fig2, axes = plt.subplots(2, 2, figsize=(12, 8))
axes = axes.flatten()

for idx, (name, current, limit, locs) in enumerate(forecast_items):
    ax = axes[idx]
    baseline = np.full(91, current, dtype=float)
    optimistic = np.array([current * (1 + 0.05 * d / 90) for d in range(91)])
    pessimistic = np.array([current * (1 + 0.10 * d / 90) for d in range(91)])

    ax.fill_between(range(91), baseline, pessimistic, alpha=0.15, color='#FF5722', label='High growth (+10%)')
    ax.fill_between(range(91), baseline, optimistic, alpha=0.15, color='#FF9800', label='Moderate growth (+5%)')
    ax.plot(range(91), baseline, color='#2196F3', linewidth=2, label='Baseline (flat)')

    if limit > 0:
        ax.axhline(y=limit, color='red', linestyle='--', alpha=0.4, linewidth=1)
        ax.text(85, limit, f'Limit: {limit}', fontsize=7, color='red', ha='right', va='bottom')

    ax.set_xticks([0, 30, 60, 90])
    ax.set_xticklabels(['Today', '+30d', '+60d', '+90d'], fontsize=8)
    ax.set_title(f'{name}\n({locs})', fontsize=9, fontweight='bold')
    ax.set_ylabel('Count', fontsize=8)
    ax.legend(fontsize=6, loc='upper left')
    ax.grid(True, alpha=0.2)

fig2.suptitle('90-Day Non-Compute Resource Forecast — Baseline Establishment\n(May 2026 | First monthly run — no prior data for trend)', fontsize=11, fontweight='bold')
plt.tight_layout(rect=[0, 0, 1, 0.93])
plt.savefig('ninety-day-forecast.svg', bbox_inches='tight')
plt.close()
