# Azure Advisor

Azure Advisor is a personalized cloud consultant that helps you follow best practices to optimize your Azure deployments, including cost optimization recommendations.

## Cost Optimization Recommendations

Azure Advisor provides recommendations in several cost-related categories:

1. **Right-size or shut down underutilized virtual machines**
   - Identifies VMs with low CPU utilization
   - Recommends downsizing or shutting down

2. **Purchase reserved instances to save money over pay-as-you-go costs**
   - Analyzes usage patterns to recommend Reserved Instance purchases
   - Provides estimated savings calculations

3. **Eliminate unprovisioned ExpressRoute circuits**
   - Identifies ExpressRoute circuits in the "provider approval pending" state
   - Recommends removing these to avoid unnecessary charges

4. **Delete or reconfigure idle virtual network gateways**
   - Identifies VNet gateways that have been idle for more than 90 days
   - Recommends reconfiguration or deletion

5. **Use Azure Hybrid Benefit**
   - Identifies where you can save by using Azure Hybrid Benefit
   - Provides licensing optimization guidance

## Integration with FinOps Practices

Azure Advisor supports key FinOps capabilities:

- **Visibility**: Highlights cost optimization opportunities
- **Optimization**: Provides specific recommendations with savings potential
- **Anomaly Detection**: Identifies unusual or unexpected costs

## Best Practices

1. **Regular reviews**: Check Advisor recommendations weekly
2. **Implement high-impact changes first**: Focus on recommendations with the highest estimated savings
3. **Automate when possible**: Use Azure Policy to automatically implement certain recommendations
4. **Track implemented savings**: Document savings achieved from Advisor recommendations

## Additional Resources

- [Azure Advisor documentation](https://learn.microsoft.com/en-us/azure/advisor/advisor-overview)
- [Azure cost optimization best practices](../best-practices/azure-cost-optimization.md)
- [FinOps Workbooks](../toolkit/workbooks.md)

---

_Last updated: May 9, 2025_
