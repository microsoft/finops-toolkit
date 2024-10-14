function GovernanceWorkbookPage() {
  return (
    <div>
      <h1>Governance Workbook</h1>
      <p>
        Monitor the governance posture of your Azure environment. Leverage recommendations to address compliance issues using this Azure Monitor workbook.
      </p>

      <a href="#deploy-the-workbook" target="_blank" rel="noopener noreferrer">
        Deploy the Workbook
      </a>

      <h2>Overview</h2>
      <p>
        The Governance Workbook provides a comprehensive overview of your Azure environment's governance posture. It aligns with the Cloud Adoption Framework and includes metrics for various disciplines, helping you identify non-compliant resources and apply recommendations to address governance issues.
      </p>

      <img
        src="https://github.com/microsoft/finops-toolkit/assets/399533/1710cf38-b0ef-4cdf-a30f-dde03dc7f1bf"
        alt="Screenshot of the Governance workbook"
      />

      <h2>➕ Deploy the Workbook</h2>
      <ol>
        <li>Ensure you have the following least-privileged roles to deploy and use the workbook:</li>
        <ul>
          <li><strong>Workbook Contributor</strong> – allows you to deploy and make changes to the workbook.</li>
          <li><strong>Cost Management Reader</strong> – allows you to view the costs in the Cost Management tab.</li>
          <li><strong>Reader</strong> – allows you to view all tabs.</li>
        </ul>
        <blockquote>
          If you only have read access, you can still import your workbook directly into Azure Monitor. You will not be able to save it, but you can view all tabs.
        </blockquote>
        <li>
          Deploy the <strong>governance-workbook</strong> template.{' '}
          <a href="../../../_resources/deploy.md" target="_blank" rel="noopener noreferrer">
            Learn more
          </a>
        </li>
      </ol>

      <h2>🧰 Related Tools</h2>
      <p>
        Explore related tools like the Cost Optimization Workbook and Azure Optimization Engine to further manage and optimize your cloud environment.
      </p>
    </div>
  );
};

export default GovernanceWorkbookPage;
