# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# culture="en-US"
ConvertFrom-StringData -StringData @'
    Common_ContextNotFound = Could not retrieve Az context. Run Az-Login.
    Common_ErrorResponse = {0} (Code: {1}).

    CostExport_Common_NotFoundFormat = Cost Management export '{0}' not found. Export ID: {1}/providers/Microsoft.CostManagement/exports/{0}.
    CostExport_Remove_DeleteFailedFormat = Unable to delete Cost Management export '{0}': '{1}' (Code: {2}).

    Hub_Deploy_Deploy = Deploying FinOps hub '{0}' to resource group '{1}'.
    Hub_Deploy_TemplateNotFound = Could not find template 'main.bicep' at path '{0}'.
    Hub_Deploy_02to011 = Version 0.2 is not supported for Azure Gov and Azure China due to FOCUS exports not being available in Cost Management yet. Using version 0.1.1 instead.
    Hub_Deploy_02to021 = Version 0.2 is not supported due to a bug in the deployment template. Using version 0.3 instead.
    Hub_Remove_Failed = FinOps hub could not be deleted. {0}.
    Hub_Remove_NotFound = FinOps hub '{0}' not found.

    HubBillingReader_Add_AlreadyAssigned = The FinOps hub managed identity already has the Billing Reader role on billing account '{0}'.
    HubBillingReader_Add_Assigned = Granted the Billing Reader role to the FinOps hub managed identity on billing account '{0}'.
    HubBillingReader_Add_AssignFailed = Could not grant the Billing Reader role on billing account '{0}'. {1}.
    HubBillingReader_Add_DataFactoryNotFound = Could not find a Data Factory for FinOps hub '{0}'. Confirm the hub is deployed and you are connected to the correct subscription.
    HubBillingReader_Add_IdentityNotFound = Data Factory '{0}' does not have a managed identity.
    HubBillingReader_Add_MultipleDataFactories = Found more than one Data Factory for FinOps hub '{0}'. Specify -ResourceGroupName to narrow the search.

    HubLocal_Initialize_AssetEmpty = Downloaded asset '{0}' from '{1}' was empty. The release may be incomplete or the URI may not point to a valid FinOps toolkit release.
    HubLocal_Initialize_DownloadFailed = Could not download asset '{0}' from '{1}'. Check the release URI and network connectivity.
    HubLocal_Initialize_NotReachable = Could not reach the Kusto emulator at '{0}'. Start the local hub container before running this command. See https://aka.ms/finops/hubs/local.
    HubLocal_Initialize_OpenDataEmpty = Open data tables were still empty after {0} attempts: {1}. The emulator's first external data read after setup can return no rows; rerun the command to retry.
    HubLocal_Initialize_ScriptsNotDownloaded = Cannot apply the {0} because release assets were not downloaded. Confirm the "Download release assets" prompt, or run without -Confirm.

    HubProviders_Register_AlreadyRegistered =  Resource provider {0} is already registered.
    HubProviders_Register_Register =  Registering resource provider {0}.
    HubProviders_Register_RegisterError =  Error registering resource provider: {0}.

    HubTemplate_Save_ExpandingZip = Expanding zip '{0}'.
    HubTemplate_Save_FoundAsset = Found asset '{0}'.

    NewDirectory_Execute = Creating directory '{0}'.

    SchemaTransform_Invoke_ActualCostPathNotFound = ActualCostPath not found. Please enter a valid path: {0}.
    SchemaTransform_Invoke_AmortizedCostPathNotFound = AmortizedCostPath not found. Please enter a valid path: {0}.

    ServicePrincipal_AlreadyGrantedMessage = Service principal already has {0} Reader permissions for the specified billing scope.
    ServicePrincipal_BillingAccountNotSpecified = A billing account ID is required.
    ServicePrincipal_BillingAccountNotSpecifiedForDept = Billing account ID is required when billing scope = Department.
    ServicePrincipal_DeptIdNotSpecified = Department ID is required when billing scope = Department.
    ServicePrincipal_InvalidBillingScope = Invalid billing scope: '{0}'.
    ServicePrincipal_SuccessMessage = Successfully granted {0} Reader permissions to the specified service principal.

    ToolkitVersion_Get_FoundLatestRelease = Found latest release '{0}'.
'@
