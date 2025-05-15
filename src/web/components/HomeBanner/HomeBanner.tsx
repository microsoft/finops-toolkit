import { Button, Text } from '@fluentui/react-components';

import './HomeBanner.css';

const HomeBanner = () => {
  function handleGetTheToolsClick() {
    window.open('https://microsoft.github.io/finops-toolkit/#-available-tools', '_blank');
  }

  function handleLearnAboutFinOpsClick() {
    window.open('https://learn.microsoft.com/cloud-computing/finops/toolkit/finops-toolkit-overview', '_blank');
  }

  return (
    <div className="ftk-homeBanner-container">
      <div className="ftk-homeBanner-content">
        <Text size={900}>Kick start your FinOps efforts</Text>
        <Text size={500}>Automate and extend the Microsoft Cloud with starter kits, scripts, and advanced solutions to accelerate your FinOps journey.</Text>
        <div className="ftk-homeBanner-actions">
          <Button size="large" onClick={handleGetTheToolsClick}>
            Get the tools
          </Button>
          <Button size="large" onClick={handleLearnAboutFinOpsClick}>
            Learn FinOps
          </Button>
        </div>
      </div>
    </div>
  );
};

export default HomeBanner;
