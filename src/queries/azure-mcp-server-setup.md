# Azure MCP Server for FinOps Hub

This document provides guidelines for installing and configuring the Azure MCP Server for use with FinOps Hub and GitHub Copilot.

## 🔍 What is Azure MCP Server?

The Azure MCP Server (Message Control Protocol) is a framework that enables GitHub Copilot to interact with Azure services and data through a standardized interface. When configured for FinOps Hub, it allows Copilot to:

- Query Azure Resource Graph data
- Run KQL queries against FinOps Hub data
- Generate cost analysis reports
- Identify optimization opportunities
- Provide recommendations based on FinOps best practices

## 📋 Prerequisites

Before installing the Azure MCP Server for FinOps Hub, ensure you have:

1. A deployed FinOps Hub instance
2. Visual Studio Code with GitHub Copilot extension installed
3. Azure CLI installed
4. Appropriate Azure permissions (Contributor on the FinOps Hub resources)
5. Git installed for cloning the repository

## 🔧 Installation Steps

### 1. Clone the Azure MCP Server Repository

```bash
git clone https://github.com/Azure/azure-mcp.git
cd azure-mcp
```

### 2. Set Up Configuration

Create a configuration file named `finops-hub-config.json`:

```json
{
  "name": "FinOps Hub MCP",
  "description": "MCP Server for FinOps Hub data analysis",
  "version": "1.0.0",
  "dataSourceConnections": [
    {
      "type": "KustoCluster",
      "name": "FinOpsHubCluster",
      "properties": {
        "clusterUri": "https://{your-cluster-name}.{region}.kusto.windows.net",
        "database": "Hub",
        "authenticationType": "AzureAD"
      }
    }
  ],
  "capabilities": [
    "KQLQuery",
    "CostAnalysis",
    "ResourceGraph"
  ]
}
```

Replace `{your-cluster-name}` and `{region}` with your actual FinOps Hub Data Explorer cluster details.

### 3. Install Dependencies

```bash
npm install
```

### 4. Configure Authentication

```bash
az login
az account set --subscription "Your-Subscription-ID"
```

### 5. Deploy the MCP Server

```bash
npm run deploy -- --config ./finops-hub-config.json
```

### 6. Configure VS Code

1. Open VS Code
2. Go to Settings (Ctrl+, or Cmd+,)
3. Search for "Copilot MCP"
4. Add a new MCP Server:
   - Name: "FinOps Hub MCP"
   - URL: The URL from the deployment output (e.g., `https://{mcp-server-name}.azurewebsites.net`)
5. Save the settings

## 🔒 Security Configuration

For secure operation of the Azure MCP Server:

1. **Restrict access to authorized users only** using Azure AD authentication
2. **Configure appropriate RBAC** for the Data Explorer cluster
3. **Enable audit logging** to track all queries and operations
4. **Set up IP restrictions** to limit access to your organization's network

Example RBAC setup:

```bash
# Assign the "Data Explorer Reader" role to the MCP Server's managed identity
az role assignment create \
  --role "Data Explorer Reader" \
  --assignee "{mcp-server-managed-identity}" \
  --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Kusto/clusters/{cluster-name}"
```

## 🧪 Testing the Installation

To verify the MCP Server is working correctly:

1. Open VS Code
2. Access Copilot Chat (Ctrl+Shift+I or Cmd+Shift+I)
3. Type "@AzureMCP analyze cost data from FinOps Hub"
4. Verify Copilot can access and query the data

Example test query:

```
@AzureMCP What was my total Azure cost last month by service?
```

## 🔄 Updating the MCP Server

When updates to the Azure MCP Server are available:

1. Pull the latest changes from the repository
2. Update your configuration as needed
3. Redeploy the server

```bash
git pull
npm run deploy -- --config ./finops-hub-config.json --update
```

## 📚 Additional Resources

- [Azure MCP Server Documentation](https://github.com/Azure/azure-mcp)
- [Using MCP Servers in VS Code](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)
- [FinOps Hub Documentation](https://aka.ms/finops/hubs/docs)
- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)