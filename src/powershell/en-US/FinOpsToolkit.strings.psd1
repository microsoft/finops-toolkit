# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# culture="en-US"
ConvertFrom-StringData -StringData @'
    DeployFinOpsHub = Deploying FinOps hub '{0}' to resource group '{1}'.
    ExpandingZip = Expanding zip '{0}'.
    FoundAsset = Found asset '{0}'.
    FoundLatestRelease = Found latest release '{0}'.
    NewDirectory = Creating directory '{0}'.
    TemplateNotFound = Could not find template 'main.bicep' at path '{0}'.
    ContextNotFound = Could not retrieve Az context. Run Az-Login.
    RegisterProvider =  Registering resource provider {0}.
    ResourceProviderRegistered =  Resource provider {0} is already registered.
    ErrorRegisteringProvider =  Error registering resource provider: {0}.
    DeleteCostExportFailed = Delete Cost Management export operation failed with message: '{0}' (Code: {1}).
    GetCostExportNotFound = Cost Management export not found. Operation failed with message: '{0}' (Code: {1}).
    DeleteCostExportFilesFailed = Delete export files operation failed.
    DeleteFinOpsHub = FinOps hub could not be deleted. {0}.
    ErrorResponse = {0} (Code: {1}).
    FinOpsHubNotFound = FinOps hub '{0}' not found.
'@
