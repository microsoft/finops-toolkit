import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import HomePage from './HomePage';
import FinOpsHubsPage from './FinOpsHubsPage';
import FinOpsWorkbooksPage from './FinOpsWorkbooksPage';
import GovernanceWorkbookPage from './GovernanceWorkbookPage';
import AzureOptimizationEnginePage from './AzureOptimizationEnginePage';
import PowerShellModulePage from './PowerShellModulePage';
import BicepRegistryModulesPage from './BicepRegistryModulesPage';
import OpenDataPage from './OpenDataPage';
import PowerBIReportsPage from './PowerBIReportsPage';
import CostOptimizationWorkbookPage from './CostOptimizationWorkbookPage';
import ToolsLandingPage from './ToolsLandingPage';

import './App.css';

function App() {
  return (

    <Router>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/bicep-registry" element={<BicepRegistryModulesPage />} />
          <Route path="/hubs" element={<FinOpsHubsPage />} />
          <Route path="/open-data" element={<OpenDataPage />} />
          <Route path="/optimization-engine" element={<AzureOptimizationEnginePage />} />
          <Route path="/power-bi" element={<PowerBIReportsPage />} />
          <Route path="/powershell" element={<PowerShellModulePage />} />
          <Route path="/tools" element={<ToolsLandingPage />} />
          <Route path="/workbooks" element={<FinOpsWorkbooksPage />} />
          <Route path="/workbooks/governance" element={<GovernanceWorkbookPage />} />
          <Route path="/workbooks/optimization" element={<CostOptimizationWorkbookPage />} />
        </Routes>
    </Router>
  );
};

export default App;
