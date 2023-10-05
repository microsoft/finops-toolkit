# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

@{
    PSDependOptions = @{
        DependencyType = 'PSGalleryModule'
        SkipPublisherCheck = $true
        Force = $true
        AllowClobber = $true
    }
    
    InvokeBuild      = 'latest'
    PSScriptAnalyzer = 'latest'
    Pester           = 'latest'
    'Az.Accounts'    = '2.11.1'
    'Az.Resources'   = '6.5.1'
}
