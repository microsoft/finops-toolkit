# chart-name: capacity-quota-utilization
import json
import matplotlib.pyplot as plt
import numpy as np

labels = [
    "[Net/Stor] Storage Accounts",
    "[Net/Stor] Route Tables",
    "[Net/Stor] Public IP Addresses",
    "[Net/Stor] Public IPv4 Addresses - S...",
    "[Net/Stor] Load Balancers",
    "[Net/Stor] Standard Sku Load Balancers",
    "[Net/Stor] Virtual Networks",
    "[Net/Stor] Network Security Groups",
    "[Compute] Total Regional Low-priority",
    "[Compute] Total Regional",
    "[Compute] Basic A Family",
    "[Compute] A0-A7 Family",
    "[Compute] A8-A11 Family",
]
values = [1.2, 0.5, 0.3, 0.3, 0.3, 0.3, 0.2, 0.18, 0.0, 0.0, 0.0, 0.0, 0.0]
colors_list = ['#28a745'] * len(values)

fig, ax = plt.subplots(figsize=(10, 6))
y_pos = np.arange(len(labels))
bars = ax.barh(y_pos, values, color=colors_list, edgecolor='white', height=0.6)
ax.set_yticks(y_pos)
ax.set_yticklabels(labels, fontsize=9)
ax.set_xlabel('Utilization %', fontsize=11)
ax.set_title('Capacity Quota Utilization — westus\n2026-05-02 18:29 UTC', fontsize=13, fontweight='bold')
ax.set_xlim(0, max(max(values) * 1.3 if values else 10, 10))
ax.axvline(x=80, color='#ffc107', linestyle='--', alpha=0.7, label='Warning (80%)')
ax.axvline(x=95, color='#dc3545', linestyle='--', alpha=0.7, label='Critical (95%)')
ax.legend(loc='lower right', fontsize=9)
ax.invert_yaxis()
for bar, val in zip(bars, values):
    ax.text(bar.get_width() + 0.15, bar.get_y() + bar.get_height() / 2, f'{val:.1f}%', va='center', fontsize=9)
plt.tight_layout()
plt.savefig('capacity-quota-utilization.svg', bbox_inches='tight')
plt.close()
