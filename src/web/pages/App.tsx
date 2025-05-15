import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import FinOpsHubsPage from './FinOpsHubsPage';
import FinOpsWorkbooksPage from './FinOpsWorkbooksPage';
import GovernanceWorkbookPage from './GovernanceWorkbookPage';
import AzureOptimizationEnginePage from './AzureOptimizationEnginePage';
import PowerShellModulePage from './PowerShellModulePage';
import BicepRegistryModulesPage from './BicepRegistryModulesPage';
import OpenDataPage from './OpenDataPage';
import FluentUIProvider from '../components/FluentUIProvider'; // Use your FluentUIProvider
import PowerBIReportsPage from './PowerBIReportsPage';
import CostOptimizationWorkbookPage from './CostOptimizationWorkbookPage';
// import MainLayout from '../components/MainLayout/MainLayout';
import { HomePage } from '../pages/HomePage';

/**
 * The main component of the application.
 * Renders the routes for different pages.
 */
function App() {
  return (
    <FluentUIProvider>
    <Router basename={window.location.hostname === 'localhost' ? '/' : '/finops-toolkit'}>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/bicep-registry" element={<BicepRegistryModulesPage />} />
          <Route path="/hubs" element={<FinOpsHubsPage />} />
          <Route path="/open-data" element={<OpenDataPage />} />
          <Route path="/optimization-engine" element={<AzureOptimizationEnginePage />} />
          <Route path="/power-bi" element={<PowerBIReportsPage />} />
          <Route path="/powershell" element={<PowerShellModulePage />} />
          {/* <Route path="/tools" element={<SamplePage />} /> */}
          <Route path="/workbooks" element={<FinOpsWorkbooksPage />} />
          <Route path="/workbooks/governance" element={<GovernanceWorkbookPage />} />
          <Route path="/workbooks/optimization" element={<CostOptimizationWorkbookPage />} />
          {/* </Route> */}
        </Routes>
      </Router>
    </FluentUIProvider>
  );
}

export default App;
