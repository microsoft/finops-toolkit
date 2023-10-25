# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Load the function into the current context
. "$PSScriptRoot/../../Private/Split-AzureResourceId.ps1"

$subId = (New-Guid).Guid
$rg = 'testRg'
$rp = 'Microsoft.Cloud'
$type1 = 'hubs'
$name1 = 'hub1'
$type2 = 'scopes'
$name2 = 'scope2'

Describe 'Split-AzureResourceId' {
    It 'Should parse tenant' {
        $id = "/tenants/$subId"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $null
        $result.SubscriptionResourceId | Should -Be $null
        $result.ResourceGroupId | Should -Be $null
        $result.ResourceGroupName | Should -Be $null
        $result.Provider | Should -Be 'Microsoft.Resources'
        $result.Name | Should -Be $subId
        $result.Type | Should -Be "Microsoft.Resources/tenants"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse tenant resource' {
        $id = "/providers/$rp/$type1/$name1"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $null
        $result.SubscriptionResourceId | Should -Be $null
        $result.ResourceGroupId | Should -Be $null
        $result.ResourceGroupName | Should -Be $null
        $result.Provider | Should -Be $rp
        $result.Name | Should -Be $name1
        $result.Type | Should -Be "$rp/$type1"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse tenant nested resource' {
        $id = "/providers/$rp/$type1/$name1/$type2/$name2"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $null
        $result.SubscriptionResourceId | Should -Be $null
        $result.ResourceGroupId | Should -Be $null
        $result.ResourceGroupName | Should -Be $null
        $result.Provider | Should -Be $rp
        $result.Name | Should -Be "$name1/$name2"
        $result.Type | Should -Be "$rp/$type1/$type2"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse subscription' {
        $id = "/subscriptions/$subId"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $subId
        $result.SubscriptionResourceId | Should -Be "/subscriptions/$subId"
        $result.ResourceGroupId | Should -Be $null
        $result.ResourceGroupName | Should -Be $null
        $result.Provider | Should -Be 'Microsoft.Resources'
        $result.Name | Should -Be $subId
        $result.Type | Should -Be "Microsoft.Resources/subscriptions"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse subscription resource' {
        $id = "/subscriptions/$subId/providers/$rp/$type1/$name1"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $subId
        $result.SubscriptionResourceId | Should -Be "/subscriptions/$subId"
        $result.ResourceGroupId | Should -Be $null
        $result.ResourceGroupName | Should -Be $null
        $result.Provider | Should -Be $rp
        $result.Name | Should -Be $name1
        $result.Type | Should -Be "$rp/$type1"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse resource group' {
        $id = "/subscriptions/$subId/resourceGroups/$rg"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $subId
        $result.SubscriptionResourceId | Should -Be "/subscriptions/$subId"
        $result.ResourceGroupId | Should -Be $id.Substring(0, $id.IndexOf("/resourceGroups/$rg") + "/resourceGroups/$rg".Length)
        $result.ResourceGroupName | Should -Be $rg
        $result.Provider | Should -Be 'Microsoft.Resources'
        $result.Name | Should -Be $rg
        $result.Type | Should -Be "Microsoft.Resources/subscriptions/resourceGroups"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse resource group resource' {
        $id = "/subscriptions/$subId/resourceGroups/$rg/providers/$rp/$type1/$name1"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $subId
        $result.SubscriptionResourceId | Should -Be "/subscriptions/$subId"
        $result.ResourceGroupId | Should -Be $id.Substring(0, $id.IndexOf("/resourceGroups/$rg") + "/resourceGroups/$rg".Length)
        $result.ResourceGroupName | Should -Be $rg
        $result.Provider | Should -Be $rp
        $result.Name | Should -Be $name1
        $result.Type | Should -Be "$rp/$type1"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse nested resource group resource' {
        $id = "/subscriptions/$subId/resourceGroups/$rg/providers/$rp/$type1/$name1/$type2/$name2"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $subId
        $result.SubscriptionResourceId | Should -Be "/subscriptions/$subId"
        $result.ResourceGroupId | Should -Be $id.Substring(0, $id.IndexOf("/resourceGroups/$rg") + "/resourceGroups/$rg".Length)
        $result.ResourceGroupName | Should -Be $rg
        $result.Provider | Should -Be $rp
        $result.Name | Should -Be "$name1/$name2"
        $result.Type | Should -Be "$rp/$type1/$type2"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse and fix invalid resource ID' {
        $id = "/subscriptions/$subId/resourceGroups/$rg/providers/$rp/$type1/$name1/$type2/$name2/INVALID"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $subId
        $result.SubscriptionResourceId | Should -Be "/subscriptions/$subId"
        $result.ResourceGroupId | Should -Be $id.Substring(0, $id.IndexOf("/resourceGroups/$rg") + "/resourceGroups/$rg".Length)
        $result.ResourceGroupName | Should -Be $rg
        $result.Provider | Should -Be $rp
        $result.Name | Should -Be "$name1/$name2"
        $result.Type | Should -Be "$rp/$type1/$type2"
        $result.ResourceId | Should -Be ($id.Split('/')[0..($id.Split('/').Count - 2)] -Join '/')
    }

    It 'Should handle empty resource ID' {
        $id = ""
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $null
        $result.SubscriptionResourceId | Should -Be $null
        $result.ResourceGroupId | Should -Be $null
        $result.ResourceGroupName | Should -Be $null
        $result.Provider | Should -Be $null
        $result.Name | Should -Be $null
        $result.Type | Should -Be $null
        $result.ResourceId | Should -Be $null
    }

    It 'Should handle null resource ID' {
        $id = $null
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -Be $null
        $result.SubscriptionResourceId | Should -Be $null
        $result.ResourceGroupId | Should -Be $null
        $result.ResourceGroupName | Should -Be $null
        $result.Provider | Should -Be $null
        $result.Name | Should -Be $null
        $result.Type | Should -Be $null
        $result.ResourceId | Should -Be $null
    }
}
