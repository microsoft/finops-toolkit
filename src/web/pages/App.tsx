import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import HomePage from './HomePage';
import ToolsLandingPage from './ToolsLandingPage';
import FinOpsHubsPage from './FinOpsHubsPage';
import FinOpsWorkbooksPage from './FinOpsWorkbooksPage';
import GovernanceWorkbookPage from './GovernanceWorkbookPage';
import AzureOptimizationEnginePage from './AzureOptimizationEnginePage';
import PowerShellModulePage from './PowerShellModulePage';
import BicepRegistryModulesPage from './BicepRegistryModulesPage';
import OpenDataPage from './OpenDataPage';
import PowerBIReportsPage from './PowerBIReportsPage';
import CostOptimizationWorkbookPage from './CostOptimizationWorkbookPage';

const App: React.FC = () => {
  return (
    <Router>
      <div>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/tools" element={<ToolsLandingPage />} />
          <Route path="/tools/finops-hubs" element={<FinOpsHubsPage />} />
          <Route path="/tools/power-bi-reports" element={<PowerBIReportsPage />} />
          <Route path="/tools/cost-optimization-workbook" element={<CostOptimizationWorkbookPage />} />
          <Route path="/tools/finops-workbooks" element={<FinOpsWorkbooksPage />} />
          <Route path="/tools/governance-workbook" element={<GovernanceWorkbookPage />} />
          <Route path="/tools/azure-optimization-engine" element={<AzureOptimizationEnginePage />} />
          <Route path="/tools/powershell-module" element={<PowerShellModulePage />} />
          <Route path="/tools/bicep-registry-modules" element={<BicepRegistryModulesPage />} />
          <Route path="/tools/open-data" element={<OpenDataPage />} />
        </Routes>
      </div>
    </Router>
  );
};

export default App;
