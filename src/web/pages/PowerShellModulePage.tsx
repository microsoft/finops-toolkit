function PowerShellPage() {
  return (
    <div>
      <h1>PowerShell Module</h1>
      <p>
        Automate and scale your FinOps efforts with PowerShell commands that streamline operations and accelerate adoption across projects and teams.
      </p>

      <div>
        <a href="#install-module">Install</a>
        <a href="#commands">Commands</a>
      </div>

      <section>
        <h2>📥 Install the module</h2>
        <p>
          The FinOps toolkit module requires PowerShell 7, which is built into <a href="https://portal.azure.com/#cloudshell">Azure Cloud Shell</a> and supported on all major operating systems.
        </p>
        <pre>
          <code>
            Install-Module -Name Az.Accounts
            Install-Module -Name Az.Resources
            Install-Module -Name FinOpsToolkit
          </code>
        </pre>
        <p>
          After installation, you can sign into your Azure account by running:
        </p>
        <pre>
          <code>Connect-AzAccount</code>
        </pre>
      </section>

      <section>
        <h2>⚡ Commands</h2>
        <h3>General toolkit commands</h3>
        <ul>
          <li><a href="toolkit/Get-FinOpsToolkitVersion.md">Get-FinOpsToolkitVersion</a> – Get details about available FinOps toolkit releases.</li>
        </ul>

        <h3>Cost Management commands</h3>
        <ul>
          <li><a href="cost/Get-FinOpsCostExport.md">Get-FinOpsCostExport</a> – Get details about Cost Management exports.</li>
          <li><a href="cost/New-FinOpsCostExport.md">New-FinOpsCostExport</a> – Create a new Cost Management export.</li>
          <li><a href="cost/Remove-FinOpsCostExport.md">Remove-FinOpsCostExport</a> – Delete a Cost Management export.</li>
          <li><a href="cost/Start-FinOpsCostExport.md">Start-FinOpsCostExport</a> – Initiates a Cost Management export run.</li>
        </ul>

        <h3>FinOps Hubs commands</h3>
        <ul>
          <li><a href="hubs/Deploy-FinOpsHub.md">Deploy-FinOpsHub</a> – Deploy your first hub or update to the latest version.</li>
          <li><a href="hubs/Get-FinOpsHub.md">Get-FinOpsHub</a> – Get details about your FinOps hub instance.</li>
        </ul>

        <h3>Open data commands</h3>
        <ul>
          <li><a href="data/Get-FinOpsPricingUnit.md">Get-FinOpsPricingUnit</a> – Get details about an Azure pricing unit.</li>
          <li><a href="data/Get-FinOpsRegion.md">Get-FinOpsRegion</a> – Get details about an Azure region.</li>
        </ul>
      </section>

      <section>
        <h2>🙋‍♀️ Looking for more?</h2>
        <p>
          We'd love to hear about any commands or scripts you're looking for. Vote up (👍) existing ideas or create a new issue to suggest a new idea. We'll focus on ideas with the most votes.
        </p>
        <a href="https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+label%3A%22Area%3A+PowerShell%22+sort%3Areactions-%2B1-desc">Vote on ideas</a>
        <a href="https://aka.ms/ftk/idea">Suggest an idea</a>
      </section>

      <section>
        <h2>🧰 Related Tools</h2>
        <p>Here would be the related tools markdown inclusion.</p>
      </section>
    </div>
  );
};

export default PowerShellPage;
