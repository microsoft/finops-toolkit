import React from 'react';

const OpenDataPage: React.FC = () => {
  return (
    <div>
      <h1>Open Data</h1>
      <p>
        Leverage open data to normalize and enhance your FinOps reporting.
      </p>

      <a href="https://github.com/microsoft/finops-toolkit/releases/latest" target="_blank" rel="noopener noreferrer" className="btn btn-primary mb-4">
        Download
      </a>
      <a href="#looking-for-more" target="_blank" rel="noopener noreferrer" className="btn mb-4">
        Share feedback
      </a>

      {/* Pricing Units Section */}
      <section id="pricing-units">
        <h2>📏 Pricing Units</h2>
        <p>
          Microsoft Cost Management uses the `UnitOfMeasure` column to indicate how each charge is measured. Pricing units help normalize and compare the pricing of various cost-related datasets.
        </p>
        <p>Sample data:</p>
        <table>
          <thead>
            <tr>
              <th>UnitOfMeasure</th>
              <th>AccountTypes</th>
              <th>PricingBlockSize</th>
              <th>DistinctUnits</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>1 Hour</td>
              <td>MCA, EA</td>
              <td>1</td>
              <td>Hours</td>
            </tr>
            <tr>
              <td>10000 GB</td>
              <td>EA</td>
              <td>10000</td>
              <td>GB</td>
            </tr>
          </tbody>
        </table>
        <a href="https://github.com/microsoft/finops-toolkit/releases/latest/download/PricingUnits.csv" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Download Pricing Units CSV
        </a>
      </section>

      {/* Regions Section */}
      <section id="regions">
        <h2>🗺️ Regions</h2>
        <p>
          Microsoft Cost Management provides various values for resource locations. The Regions file lists region IDs and names for cost-related datasets, ensuring consistency.
        </p>
        <a href="https://github.com/microsoft/finops-toolkit/releases/latest/download/Regions.csv" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Download Regions CSV
        </a>
      </section>

      {/* Resource Types Section */}
      <section id="resource-types">
        <h2>📚 Resource Types</h2>
        <p>
          Azure resource types represent specific kinds of resources. This dataset includes resource type values, display names, descriptions, and icon links for better reporting and normalization.
        </p>
        <a href="https://github.com/microsoft/finops-toolkit/releases/latest/download/ResourceTypes.csv" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Download Resource Types CSV
        </a>
        <a href="https://github.com/microsoft/finops-toolkit/releases/latest/download/ResourceTypes.json" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Download Resource Types JSON
        </a>
      </section>

      {/* Services Section */}
      <section id="services">
        <h2>🎛️ Services</h2>
        <p>
          In Microsoft Cost Management, `ConsumedService` represents the service providing the resource. This dataset maps `ConsumedService` values to services, categories, and subcategories to help with FOCUS alignment.
        </p>
        <a href="https://github.com/microsoft/finops-toolkit/releases/latest/download/Services.csv" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Download Services CSV
        </a>
      </section>

      {/* Dataset Examples Section */}
      <section id="dataset-examples">
        <h2>⬇️ Dataset Examples</h2>
        <p>
          Example files from Microsoft Cost Management's exports are provided for understanding the structure and format of cost data. These examples are from an Enterprise Agreement (EA) demo account and are not for ingestion or reporting.
        </p>
        <a href="https://github.com/microsoft/finops-toolkit/releases/latest/download/dataset-examples.zip" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Download Dataset Examples
        </a>
      </section>

      {/* Dataset Metadata Section */}
      <section id="dataset-metadata">
        <h2>📃 Dataset Metadata</h2>
        <p>
          Each dataset uses different columns and data types. FOCUS metadata describes the structure and format of the data, including schema versions and column information.
        </p>
        <a href="https://github.com/microsoft/finops-toolkit/releases/latest/download/dataset-metadata.zip" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Download Dataset Metadata
        </a>
      </section>

      {/* Looking for More Section */}
      <section id="looking-for-more">
        <h2>🙋‍♀️ Looking for More?</h2>
        <p>
          We'd love to hear about any datasets you're looking for. Create a new issue with details you'd like to see included in existing or new datasets.
        </p>
        <a href="https://aka.ms/ftk/idea" target="_blank" rel="noopener noreferrer" className="btn mb-4">
          Share feedback
        </a>
      </section>

      {/* Related Tools Section */}
      <section id="related-tools">
        <h2>🧰 Related Tools</h2>
        <p>
          Explore related tools like Power BI and PowerShell scripts to enhance your FinOps reporting.
        </p>
      </section>
    </div>
  );
};

export default OpenDataPage;
