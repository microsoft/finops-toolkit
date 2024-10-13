import React from 'react';

const FinOpsHubsPage: React.FC = () => {
  return (
    <div>
      <h1>FinOps Hubs</h1>
      <p>
        Open, extensible, and scalable cost governance for the enterprise. FinOps hubs are a reliable, trustworthy platform for cost analytics, insights, and optimization – virtual command centers for leaders throughout the organization to report on, monitor, and optimize cost based on their organizational needs.
      </p>

      <a href="#create-a-new-hub" target="_blank" rel="noopener noreferrer">
        Deploy the Hub
      </a>
      
      <a href="#why-finops-hubs" target="_blank" rel="noopener noreferrer">
        Learn more
      </a>

      <h2>🙋‍♀️ Why FinOps Hubs?</h2>
      <p>
        Many organizations that use Microsoft Cost Management eventually hit a wall where they need capabilities not natively available. FinOps hubs provide the foundation for custom-built cost management solutions, streamlining the process and offering scalability, extensibility, and alignment with the FinOps Framework.
      </p>

      <h2>🌟 Benefits</h2>
      <ul>
        <li>Clean up duplicated data in daily Cost Management exports (saving on storage).</li>
        <li>Convert exported data to Parquet for faster access.</li>
        <li>Connect Power BI to subscriptions, resource groups, or billing accounts.</li>
        <li>Support for Azure Government and Azure China.</li>
        <li>Integration with Microsoft Online Services Agreement (MOSA) subscriptions.</li>
        <li>Alignment with the FinOps Open Cost and Usage Specification (FOCUS).</li>
      </ul>

      <h2>📦 What's Included</h2>
      <p>The FinOps hub template includes the following resources:</p>
      <ul>
        <li>Storage account (Data Lake Storage Gen2) for cost data.</li>
        <li>Data Factory instance for data ingestion and cleanup.</li>
        <li>Key Vault to store credentials for Data Factory.</li>
      </ul>

      <h2>📚 Explore the FinOps Reports</h2>
      <p>
        Download and explore the FinOps reports available as Power BI files (PBIX or PBIT). These reports come pre-filled with test data and can be customized to meet your needs.
      </p>

      <a href="../power-bi/README.md" target="_blank" rel="noopener noreferrer">
        Browse FinOps Reports
      </a>

      <h2>➕ Create a New Hub</h2>
      <ol>
        <li>Deploy your FinOps hub using the provided template.</li>
        <li>Configure scopes to monitor, including billing accounts, subscriptions, and resource groups.</li>
        <li>Connect to your data using Azure storage, Data Factory, or Power BI starter templates.</li>
      </ol>

      <h2>🔐 Required Permissions</h2>
      <p>Required permissions for deploying or updating FinOps hubs:</p>
      <ul>
        <li>Cost Management Contributor for subscriptions and resource groups.</li>
        <li>Enterprise Reader, Department Reader, or Account Owner for EA billing scopes.</li>
        <li>Contributor role for MCA and MPA billing scopes.</li>
      </ul>

      <h2>🧰 Related Tools</h2>
      <p>Explore related tools such as the Azure Optimization Engine, Power BI, and more for a comprehensive approach to cloud cost optimization.</p>
    </div>
  );
};

export default FinOpsHubsPage;
