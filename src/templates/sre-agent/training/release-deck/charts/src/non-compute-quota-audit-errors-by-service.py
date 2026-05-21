# chart-name: errors-by-service
import matplotlib.pyplot as plt

error_services = ['Network', 'Storage']
error_counts = [53, 53]

fig, ax = plt.subplots(figsize=(6, 3))
ax.barh(error_services, error_counts, color='#95a5a6', edgecolor='white')
for i, val in enumerate(error_counts):
    ax.text(val + 0.5, i, str(val), va='center', fontsize=9, fontweight='bold')
ax.set_xlabel('Error Count', fontsize=10)
ax.set_title('API Errors by Service\n(Stage/Preview/Canary Regions)', fontsize=11, fontweight='bold')
ax.grid(axis='x', alpha=0.2)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

plt.tight_layout()
plt.savefig('chart_errors_by_service.svg', bbox_inches='tight')
plt.close()
