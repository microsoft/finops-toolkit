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
    BillingAccountNotSpecifiedForDept = Billing account ID is required when billing scope = Department.
    DeptIdNotSpecified = Department ID is required when billing scope = Department.
    InvalidBillingScope = Invalid billing scope: '{0}'.
    SuccessMessage1 = Successfully granted {0} Reader permissions to the specified Service Principal.
    AlreadyGrantedMessage1 = Service Principal already has {0} Reader permissions for the specified billing scope.
'@