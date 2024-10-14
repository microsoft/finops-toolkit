function CostOptimizationWorkbookPage() {
  return (
    <div>
      <h1>Cost Optimization Workbook</h1>
      <p>
        Give your engineers a single pane of glass for cost optimization with this handy Azure Monitor workbook, modeled after the Well-Architected Framework guidance.
      </p>

      <a
        href="https://portal.azure.com/#blade/AppInsightsExtension/UsageNotebookBlade/ComponentId/Azure%20Advisor/ConfigurationId/community-Workbooks%2FAzure%20Advisor%2FCost%20Optimization/Type/workbook/WorkbookTemplateName/Cost%20Optimization%20(Preview)"
        target="_blank"
        rel="noopener noreferrer"
      >
        Try now
      </a>

      <h2>➕ Deploy the Workbook</h2>
      <p>
        Follow these steps to deploy the cost optimization workbook:
      </p>
      <ol>
        <li>Ensure you have the following least-privileged roles to deploy and use the workbook:</li>
        <ul>
          <li><strong>Workbook Contributor</strong> – allows you to deploy the workbook.</li>
          <li><strong>Reader</strong> – view all of the workbook tabs.</li>
        </ul>
        <blockquote>
          If you only have read access, you can still import your workbook directly into Azure Monitor. You will not be able to save it, but you can view all tabs.
        </blockquote>
        <li>
          Deploy the <strong>optimization-workbook</strong> template.{' '}
          <a href="../../../_resources/deploy.md" target="_blank" rel="noopener noreferrer">
            Learn more
          </a>
        </li>
      </ol>

      <h2>🧰 Related Tools</h2>
      <p>
        Explore related tools such as FinOps Hubs, Governance Workbook, and the Azure Optimization Engine to further improve your cloud cost management strategies.
      </p>
    </div>
  );
};

export default CostOptimizationWorkbookPage;
