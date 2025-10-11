# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-OpenDataRecommendationType
{
    param()
    return [PSCustomObject]@(
        [PSCustomObject]@{ RecommendationTypeId = 'a06456ed-afb7-4d16-86fd-0054e25268ed'; Category = 'Performance'; Impact = 'Medium'; ServiceName = 'Virtual Machines'; ResourceType = 'microsoft.compute/virtualmachines'; DisplayName = 'Enable Accelerated Networking to improve network performance and latency'; LearnMoreLink = 'https://docs.microsoft.com/azure/virtual-network/create-vm-accelerated-networking-cli#enable-accelerated-networking-on-existing-vms'; }
        ,[PSCustomObject]@{ RecommendationTypeId = '9c0c3708-17f6-4108-9aff-f0e052c3cd41'; Category = 'OperationalExcellence'; Impact = 'Low'; ServiceName = 'Azure App Service'; ResourceType = 'microsoft.subscriptions/subscriptions'; DisplayName = 'Eliminate replica staging environments and ship new versions and features with zero downtime using deployment slots'; LearnMoreLink = 'https://docs.microsoft.com/azure/app-service/deploy-staging-slots'; }
        ,[PSCustomObject]@{ RecommendationTypeId = 'a205074f-8049-48b3-903f-556f5e530ae3'; Category = 'Cost'; Impact = 'High'; ServiceName = 'ReservedInstances'; ResourceType = 'microsoft.subscriptions/subscriptions'; DisplayName = 'Buy reserved instance'; LearnMoreLink = 'https://aka.ms/rirecommendations'; }
        ,[PSCustomObject]@{ RecommendationTypeId = '94aea435-ef39-493f-a547-8408092c22a7'; Category = 'Cost'; Impact = 'High'; ServiceName = 'Virtual Machine Scale Sets'; ResourceType = 'microsoft.compute/virtualmachinescalesets'; DisplayName = 'Shut down or resize your virtual machine scale sets'; LearnMoreLink = 'https://aka.ms/aa_lowusagerec_vmss_learnmore'; }
        ,[PSCustomObject]@{ RecommendationTypeId = 'afdf4c1a-e46b-4817-a5d6-4b9909f58e2a'; Category = 'Cost'; Impact = 'Low'; ServiceName = 'Azure Synapse Analytics'; ResourceType = 'microsoft.synapse/workspaces'; DisplayName = 'Consider enabling automatic pause feature on spark compute'; LearnMoreLink = 'https://aka.ms/EnableSynapseSparkComputeAutoPauseGuidance'; }
        ,[PSCustomObject]@{ RecommendationTypeId = 'ed651749-cd37-4fd5-9897-01b416926745'; Category = 'HighAvailability'; Impact = 'Medium'; ServiceName = 'Site Recovery'; ResourceType = 'microsoft.compute/virtualmachines'; DisplayName = 'Enable virtual machine replication'; LearnMoreLink = 'https://aka.ms/azure-site-recovery-dr-azure-vms'; }
    )
}
