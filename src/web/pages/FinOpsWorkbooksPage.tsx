import React from 'react';

const FinOpsWorkbooksPage: React.FC = () => {
  return (
    <div>
      <h1>FinOps Workbooks</h1>
      <p>
        A customizable home for engineers to maximize cloud ROI through FinOps. Leverage Azure Monitor workbooks to manage and optimize cost, usage, and carbon efficiency for your Azure resources and services.
      </p>

      <a href="#deploy-the-workbooks" target="_blank" rel="noopener noreferrer">
        Deploy the Workbooks
      </a>

      <h2>Overview</h2>
      <p>
        FinOps workbooks are Azure Monitor workbooks that provide a series of tools to help engineers perform targeted FinOps capabilities, modeled after the Well-Architected Framework guidance.
      </p>
      <p>This template includes the following workbooks:</p>
      <ul>
        <li><a href="./optimization/README.md">Optimization</a></li>
        <li><a href="./governance/README.md">Governance</a></li>
      </ul>

      <h2>➕ Deploy the Workbooks</h2>
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
          Deploy the <strong>finops-workbooks</strong> template.{' '}
          <a href="../../_resources/deploy.md" target="_blank" rel="noopener noreferrer">
            Learn more
          </a>
        </li>
      </ol>

      <h2>🙋‍♀️ Looking for More?</h2>
      <p>
        We'd love to hear about any workbooks or questions you're looking to answer. Create a new issue with the details that you'd like to see either included in existing or new workbooks.
      </p>
      <a href="https://aka.ms/ftk/idea" target="_blank" rel="noopener noreferrer">
        Share feedback
      </a>

      <h2>🧰 Related Tools</h2>
      <p>
        Explore related tools like the Azure Optimization Engine and FinOps Hubs to further optimize your cloud cost management strategies.
      </p>
    </div>
  );
};

export default FinOpsWorkbooksPage;
