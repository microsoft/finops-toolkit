function BicepRegistryPage() {
  return (
    <div>
      <h1>Bicep Registry Modules</h1>
      <p>
        Leverage reusable Bicep modules in your templates to accelerate your FinOps efforts.
      </p>

      <div>
        <a href="#referencing-bicep-modules">Use Bicep</a>
      </div>

      <section>
        <h2>📥 Referencing Bicep Modules</h2>
        <p>
          Referencing a module in your Bicep template is as simple as adding the following to the top of your file:
        </p>
        <pre>
          <code>
            module {'<name>'} 'br/public:cost/{'<scope>'}-{'<type>'}:{'<version>'}' {'{'}
            <br />
            {' '} name: {'<name>'}
            <br />
            {' '} params: {'{'}
            <br />
            {'    '} parameterName: {'<parameter-value>'}
            <br />
            {' }'}
            <br />
            {'}'}
          </code>
        </pre>
        <p>
          For details about the parameters for each module, see the module details below.
        </p>
      </section>

      <section>
        <h2>🦾 Modules</h2>
        <ul>
          <li><a href="scheduled-actions.md">Scheduled actions</a> – Send an email on a schedule or when an anomaly is detected.</li>
        </ul>
      </section>

      <section>
        <h2>🙋‍♀️ Looking for more?</h2>
        <p>
          We'd love to hear about any modules or templates you're looking for. Vote up (👍) existing ideas or create a new issue to suggest a new idea. We'll focus on ideas with the most votes.
        </p>
        <a href="https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue+is%3Aopen+label%3A%22Solution%3A+Bicep+Registry%22+sort%3Areactions-%2B1-desc">Vote on ideas</a>
        <a href="https://aka.ms/ftk/idea">Suggest an idea</a>
      </section>

      <section>
        <h2>🧰 Related Tools</h2>
        <p>Here would be the related tools markdown inclusion.</p>
      </section>
    </div>
  );
};

export default BicepRegistryPage;
