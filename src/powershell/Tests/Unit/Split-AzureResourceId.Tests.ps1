# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Describe 'Split-AzureResourceId' {
    BeforeAll {
        . "$PSScriptRoot/../../Private/Split-AzureResourceId.ps1"
        $subId = (New-Guid).Guid
        $rg = 'testRg'
        $rp = 'Microsoft.Cloud'
        $type1 = 'hubs'
        $name1 = 'hub1'
        $type2 = 'scopes'
        $name2 = 'scope2'
    }
    It 'Should parse tenant' {
        $id = "/tenants/$subId"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -BeNullOrEmpty -Because "tenants have no subscription ID"
        $result.SubscriptionResourceId | Should -BeNullOrEmpty -Because "tenants have no subscription resource ID"
        $result.ResourceGroupId | Should -BeNullOrEmpty -Because "tenants have no resource group ID"
        $result.ResourceGroupName | Should -BeNullOrEmpty -Because "tenants have no resource group name"
        $result.Provider | Should -Be 'Microsoft.Resources'
        $result.Name | Should -Be $subId
        $result.Type | Should -Be "Microsoft.Resources/tenants"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse tenant resource' {
        $id = "/providers/$rp/$type1/$name1"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -BeNullOrEmpty -Because "tenant resources have no subscription ID"
        $result.SubscriptionResourceId | Should -BeNullOrEmpty -Because "tenant resources have no subscription resource ID"
        $result.ResourceGroupId | Should -BeNullOrEmpty -Because "tenant resources have no resource group ID"
        $result.ResourceGroupName | Should -BeNullOrEmpty -Because "tenant resources have no resource group name"
        $result.Provider | Should -Be $rp
        $result.Name | Should -Be $name1
        $result.Type | Should -Be "$rp/$type1"
        $result.ResourceId | Should -Be $id
    }

    It 'Should parse tenant nested resource' {
        $id = "/providers/$rp/$type1/$name1/$type2/$name2"
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -BeNullOrEmpty -Because "nested tenant resources have no subscription ID"
        $result.SubscriptionResourceId | Should -BeNullOrEmpty -Because "nested tenant resources have no subscription resource ID"
        $result.ResourceGroupId | Should -BeNullOrEmpty -Because "nested tenant resources have no resource group ID"
        $result.ResourceGroupName | Should -BeNullOrEmpty -Because "nested tenant resources have no resource group name"
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
        $result.ResourceGroupId | Should -BeNullOrEmpty -Because "subscriptions have no resource group ID"
        $result.ResourceGroupName | Should -BeNullOrEmpty -Because "subscriptions have no resource group name"
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
        $result.ResourceGroupId | Should -BeNullOrEmpty -Because "subscription resources have no resource group ID"
        $result.ResourceGroupName | Should -BeNullOrEmpty -Because "subscription resources have no resource group name"
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
        $result.ResourceId | Should -Be ($id.Split('/')[0..($id.Split('/').Count - 2)] -join '/')
    }

    It 'Should handle empty resource ID' {
        $id = ""
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -BeNullOrEmpty
        $result.SubscriptionResourceId | Should -BeNullOrEmpty
        $result.ResourceGroupId | Should -BeNullOrEmpty
        $result.ResourceGroupName | Should -BeNullOrEmpty
        $result.Provider | Should -BeNullOrEmpty
        $result.Name | Should -BeNullOrEmpty
        $result.Type | Should -BeNullOrEmpty
        $result.ResourceId | Should -BeNullOrEmpty
    }

    It 'Should handle null resource ID' {
        $id = $null
        $result = Split-AzureResourceId -Id $id
        $result.SubscriptionId | Should -BeNullOrEmpty
        $result.SubscriptionResourceId | Should -BeNullOrEmpty
        $result.ResourceGroupId | Should -BeNullOrEmpty
        $result.ResourceGroupName | Should -BeNullOrEmpty
        $result.Provider | Should -BeNullOrEmpty
        $result.Name | Should -BeNullOrEmpty
        $result.Type | Should -BeNullOrEmpty
        $result.ResourceId | Should -BeNullOrEmpty
    }
}
