function OptimizationEnginePage() {
  return (
    <div>
      <h1>Azure Optimization Engine</h1>
      <p>
        The Azure Optimization Engine (AOE) is an extensible solution designed to generate optimization recommendations for your Azure environment. See it like a fully customizable Azure Advisor.
      </p>

      <h2>🙋‍♀️ Why an Optimization Engine?</h2>
      <p>
        The Azure Optimization Engine (AOE) was initially developed to augment Virtual Machine right-size recommendations coming from Azure Advisor with additional metrics and properties. 
        It quickly evolved into a generic framework for Well-Architected Framework-inspired optimizations of all kinds, developed by the community.
      </p>

      <h2>🌟 Benefits</h2>
      <p>Besides collecting all Azure Advisor recommendations, AOE includes other custom recommendations, such as:</p>
      <ul>
        <li>💰 Cost: VM right-sizing, underutilized resources, orphaned disks, etc.</li>
        <li>☔ High availability: VM and scale set high availability.</li>
        <li>🎯 Performance: Resource constraints for VMs, SQL databases, and App Service plans.</li>
        <li>👮 Security: Service principal credentials without expiration dates, NSG rules for removed resources, etc.</li>
        <li>🏅 Operational excellence: Empty subnets, expired service principal credentials, and more.</li>
      </ul>

      <h2>📦 What's Included</h2>
      <p>AOE includes the following resources:</p>
      <ul>
        <li>Storage account for raw data exports.</li>
        <li>Log Analytics workspace for data processing.</li>
        <li>Azure Automation for recommendations generation.</li>
        <li>Azure SQL database for recommendations history.</li>
        <li>Several Azure Workbooks for in-depth analysis and insights.</li>
        <li>A Power BI report with the latest recommendations.</li>
      </ul>

      <h2>📋 Requirements</h2>
      <p>The requirements for deploying AOE include:</p>
      <ul>
        <li>A supported Azure subscription.</li>
        <li>Owner permissions over the chosen subscription.</li>
        <li>Azure PowerShell 9.0.0+.</li>
        <li>Optional: Permissions for identity and RBAC governance features.</li>
      </ul>

      <h2>➕ Deployment Instructions</h2>
      <p>The simplest method for deploying AOE is using the Azure Cloud Shell (PowerShell). Follow these steps:</p>
      <ol>
        <li>Open Azure Cloud Shell.</li>
        <li>Run `git clone https://github.com/microsoft/finops-toolkit.git`.</li>
        <li>Run `cd finops-toolkit/src/optimization-engine`.</li>
        <li>Run `./Deploy-AzureOptimizationEngine.ps1` and follow the prompts.</li>
      </ol>

      <h2>🛫 Get Started with AOE</h2>
      <p>After deploying AOE, explore the available Azure Workbooks and Power BI reports for deeper insights. Customize AOE as needed for your environment.</p>

      <h2>🧰 Related Tools</h2>
      <p>Explore other related tools in the FinOps Toolkit, such as FinOps Hubs, Cost Management, and more.</p>

      <a href="https://github.com/microsoft/finops-toolkit/blob/dev/docs/_optimize/optimization-engine/README.md" target="_blank" rel="noopener noreferrer">
        View the full documentation here
      </a>
    </div>
  );
};

export default OptimizationEnginePage;
