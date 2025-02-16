import { Button, Text } from '@fluentui/react-components';

import './Showcase.css';

const Showcase = () => {
  function handleGetTheToolsClick() {
    window.open('https://microsoft.github.io/finops-toolkit/#-available-tools', '_blank');
  }

  function handleLearnAboutFinOpsClick() {
    window.open('https://learn.microsoft.com/cloud-computing/finops/toolkit/finops-toolkit-overview', '_blank');

  }

  return (
    <div className="ftk-showcase-container">
      <div className="ftk-showcase-content">
        <Text size={900}>Kick start your FinOps efforts</Text>
        <Text size={500}>Automate and extend the Microsoft Cloud with tools and learning resources to accelerate your FinOps journey.</Text>
        <div className="ftk-showcase-actions">
          <Button size="large" onClick={handleGetTheToolsClick}>
            Get the tools
          </Button>
          <Button size="large" onClick={handleLearnAboutFinOpsClick}>
            Learn about FinOps
          </Button>
        </div>
      </div>
    </div>
  );
};

export default Showcase;
