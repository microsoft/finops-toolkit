function PowerBIReportsPage() {
    return (
        <div>
            <h1>Power BI Reports</h1>
            <p>
                Accelerate your FinOps reporting with Power BI starter kits. These reports allow you to break down your costs, summarize data, and customize reports to meet your needs.
            </p>

            <a href="https://github.com/microsoft/finops-toolkit/releases/latest" target="_blank" rel="noopener noreferrer">
                Download Power BI Reports
            </a>

            <h2>📈 Available Reports</h2>
            <p>
                The FinOps Toolkit includes two sets of reports that connect to different data sources. We recommend using reports connected to Cost Management exports or FinOps Hubs:
            </p>
            <ul>
                <li>
                    <a href="./cost-summary.md">Cost Summary</a> – Overview of amortized costs with common breakdowns.
                </li>
                <li>
                    <a href="./rate-optimization.md">Rate Optimization</a> – Summarizes existing and potential savings from commitment discounts.
                </li>
                <li>
                    <a href="./data-ingestion.md">Data Ingestion</a> – Provides insights into your data ingestion layer.
                </li>
            </ul>
            <p>
                The following reports use the Cost Management connector for Power BI, though it is not recommended for future use:
            </p>
            <ul>
                <li>
                    <a href="./connector.md">Cost Management Connector</a> – Summarizes costs, savings, and commitment discounts for EA and MCA accounts.
                </li>
                <li>
                    <a href="./template-app.md">Cost Management Template App</a> – Original template app for EA accounts, available as a PBIX file.
                </li>
            </ul>

            <h2>⚖️ Help Me Choose</h2>
            <p>
                Microsoft offers several ways to analyze and report on your cloud costs. Depending on your needs and data size, you can use the Cost Management connector, raw exports, or FinOps Hubs for more advanced capabilities. Here's a guide to help you choose the right solution:
            </p>
            <ul>
                <li>Use the Cost Management connector for data under $2-5M/month.</li>
                <li>For larger datasets or more advanced features, use FinOps Hubs with Power BI.</li>
            </ul>

            <h2>✨ Connect to Your Data</h2>
            <p>
                All reports come with sample data to explore without needing to connect to your own data. Follow the in-built tutorials to connect to your data:
            </p>
            <ol>
                <li>Click **Transform data** in the Power BI toolbar.</li>
                <li>Navigate to **Queries** &gt; **🛠️ Setup** &gt; **▶ START HERE** and follow the instructions.</li>
                <li>Click **Close & Apply** to refresh and view your data.</li>
            </ol>
            <p>Make sure you have the appropriate permissions (e.g., Storage Blob Data Reader role) to access your data.</p>

            <h2>🙋‍♀️ Looking for More?</h2>
            <p>
                We'd love to hear your feedback! If there are additional reports or features you'd like to see, please share your ideas with us.
            </p>
            <a href="https://aka.ms/ftk/idea" target="_blank" rel="noopener noreferrer">
                Share feedback
            </a>

            <h2>🧰 Related Tools</h2>
            <p>Explore related tools, such as FinOps Hubs and other optimization resources, to enhance your cloud cost management efforts.</p>
        </div>
    );
}

export default PowerBIReportsPage;