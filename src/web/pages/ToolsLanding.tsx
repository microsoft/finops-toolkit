import React from 'react';
import { Link } from 'react-router-dom';
import { HashLink } from 'react-router-hash-link';

const ToolsLanding: React.FC = () => {
  return (
    <div>
      <h1>FinOps Toolkit - Available Tools</h1>
      <p>
        Welcome to the FinOps Toolkit. Explore the following tools to help manage and optimize your cloud costs.
      </p>
      <ul>
        <li><Link to="/tools/finops-hubs">🏦 FinOps Hubs – Open, extensible, and scalable cost reporting.</Link></li>
        <li><Link to="/tools/power-bi-reports">📊 Power BI Reports – Accelerate your reporting with Power BI starter kits.</Link></li>
        <li><Link to="/tools/finops-workbooks">📒 FinOps Workbooks – Customizable home for engineers to maximize cloud ROI.</Link></li>
        <li><Link to="/tools/cost-optimization-workbook">📒 Optimization Workbook – Central hub for cost optimization.</Link></li>
        <li><Link to="/tools/governance-workbook">📒 Governance Workbook – Central hub for governance.</Link></li>
        <li><Link to="/tools/azure-optimization-engine">🔍 Azure Optimization Engine – Extensible solution for optimization recommendations.</Link></li>
        <li><Link to="/tools/powershell-module">🖥️ PowerShell Module – Automate and manage FinOps solutions.</Link></li>
        <li><Link to="/tools/bicep-registry-modules">🦾 Bicep Registry Modules – Repository for Bicep modules.</Link></li>
        <li><Link to="/tools/open-data">🌐 Open Data – Freely accessible data for cloud cost management.</Link></li>

        {/* OpenData Sections */}
        <li><HashLink to="/tools/open-data#pricing-units">📏 Pricing Units – Microsoft pricing units and scaling factors.</HashLink></li>
        <li><HashLink to="/tools/open-data#regions">🗺️ Regions – Microsoft Commerce locations and Azure regions.</HashLink></li>
        <li><HashLink to="/tools/open-data#resource-types">📚 Resource Types – Azure resource types, display names, and icons.</HashLink></li>
        <li><HashLink to="/tools/open-data#services">🎛️ Services – Microsoft consumed services, resource types, and FOCUS service categories.</HashLink></li>
        <li><HashLink to="/tools/open-data#dataset-examples">⬇️ Sample Exports – Files from Cost Management exports.</HashLink></li>
      </ul>
    </div>
  );
};

export default ToolsLanding;
