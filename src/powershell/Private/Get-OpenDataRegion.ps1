# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-OpenDataRegion
{
    param()
    return [PSCustomObject]@(
        [PSCustomObject]@{ OriginalValue = 'ae central'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ae north'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'aen'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'aenorth'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'am'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'am2'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'amsterdam'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'ap east'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'ap southeast'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'apeast'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'apsoutheast'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'ase'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'asiaeast'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'asiapacific'; RegionId = 'asiapacific'; RegionName = 'Asia Pacific'; }
        ,[PSCustomObject]@{ OriginalValue = 'asiasoutheast'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'at east'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'ate'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'au central'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'au central 2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'au east'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'au southeast'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'aucentral'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'aucentral2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'aue'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'aueast'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'auh'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ausoutheast'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'australia'; RegionId = 'australia'; RegionName = 'Australia'; }
        ,[PSCustomObject]@{ OriginalValue = 'australia east'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'australia southeast'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'australia_east'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiac'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiac2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiacentral'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiacentral2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiaeast'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiasoutheast'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'austriae'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'austriaeast'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'azure stack'; RegionId = 'azurestack'; RegionName = 'Azure Stack'; }
        ,[PSCustomObject]@{ OriginalValue = 'azurestack'; RegionId = 'azurestack'; RegionName = 'Azure Stack'; }
        ,[PSCustomObject]@{ OriginalValue = 'bd'; RegionId = 'usdodeast'; RegionName = 'USDoD East'; }
        ,[PSCustomObject]@{ OriginalValue = 'be central'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'bec'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'belgiumc'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'belgiumcentral'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'bj'; RegionId = 'chinanorth'; RegionName = 'China North'; }
        ,[PSCustomObject]@{ OriginalValue = 'bjs'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'bl'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'bm'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'bn'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'br south'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'br southeast'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazil south'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilse'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilsouth'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilsoutheast'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brse'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brsouth'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'bso'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'by'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'ca central'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ca east'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'cac'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'cacentral'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'cae'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'caeast'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'canada central'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'canada east'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'canadacentral'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'canadaeast'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'canandacentral'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'canberra2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'cbr'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'cbr2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'cc'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'central india'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'central us'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'centralcanada'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'centralindia'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'centralus'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'centraluseuap'; RegionId = 'centraluseuap'; RegionName = 'Central US EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'ch'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'ch north'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'ch west'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'chicago'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'chilec'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'chilecentral'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinae2'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinae3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinaeast'; RegionId = 'chinaeast'; RegionName = 'China East'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinaeast2'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinaeast3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinan2'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinan3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinanorth'; RegionId = 'chinanorth'; RegionName = 'China North'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinanorth2'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinanorth3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chn'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'chnorth'; RegionId = 'chinanorth'; RegionName = 'China North'; }
        ,[PSCustomObject]@{ OriginalValue = 'chw'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'cl central'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'clc'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'cn east'; RegionId = 'chinaeast'; RegionName = 'China East'; }
        ,[PSCustomObject]@{ OriginalValue = 'cn east 2'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'cn east 3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'cn north'; RegionId = 'chinanorth'; RegionName = 'China North'; }
        ,[PSCustomObject]@{ OriginalValue = 'cn north 2'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'cn north 3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'cne3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'cnn3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'cpt'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'cq'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'cu'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'cus'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'cw'; RegionId = 'ukwest'; RegionName = 'UK West'; }
        ,[PSCustomObject]@{ OriginalValue = 'cy'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'dallas'; RegionId = 'ussouthcentral'; RegionName = 'US South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'db'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'dd'; RegionId = 'usdodcentral'; RegionName = 'USDoD Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'de central'; RegionId = 'germanycentral'; RegionName = 'Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'de north'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'de northeast'; RegionId = 'germanynortheast'; RegionName = 'Germany NorthEast'; }
        ,[PSCustomObject]@{ OriginalValue = 'de west central'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'decentral'; RegionId = 'germanycentral'; RegionName = 'Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'den'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'denmark east'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'denmarke'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'denmarkeast'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'dewc'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'dewestcentral'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'dke'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'dm'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'dubai'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'dublin'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'dwc'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'dxb'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'ea'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'eas'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'east asia'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'east us'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'east us 2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'east_asia'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastasia'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastcanada'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastjapan'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastsu2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastus'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastus2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastus2euap'; RegionId = 'eastus2euap'; RegionName = 'East US 2 EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastus3'; RegionId = 'eastus3'; RegionName = 'East US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'eau'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'es central'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'esc'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'eu'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'eu north'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'eu west'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'eu2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'eunorth'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'europe'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'europenorth'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'europewest'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'eus'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'eus2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'euwest'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'fi central'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'finlandc'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'finlandcentral'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'flc'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'fr'; RegionId = 'germanycentral'; RegionName = 'Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'fr central'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'fr south'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'france central'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'francec'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'francecentral'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'frances'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'francesouth'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'frc'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'frcentral'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'frsouth'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'gbs'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'germany west central'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanycentral'; RegionId = 'germanycentral'; RegionName = 'Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanyn'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanynorth'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanynortheast'; RegionId = 'germanynortheast'; RegionName = 'Germany NorthEast'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanywc'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanywcentral'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanywestcentral'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'global'; RegionId = 'global'; RegionName = 'Global'; }
        ,[PSCustomObject]@{ OriginalValue = 'gr central'; RegionId = 'greececentral'; RegionName = 'Greece Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'greececentral'; RegionId = 'greececentral'; RegionName = 'Greece Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'hk'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'hkg'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'hong kong'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'hongkong'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'id central'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'idc'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'il central'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ilc'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'in central'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'in central jio'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'in south'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'in south central'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'in west'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'in west jio'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'inc'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'incentral'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiacentral'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiasc'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiasouth'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiasouthcentral'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiawest'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'indonesiac'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'indonesiacentral'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ins'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'insc'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'insouth'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'inw'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'inwest'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'israelc'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'israelcentral'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'it north'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'italyn'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'italynorth'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'itn'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'ja east'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'ja west'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jaeast'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'japan'; RegionId = 'japan'; RegionName = 'Japan'; }
        ,[PSCustomObject]@{ OriginalValue = 'japan east'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'japan west'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'japan_east'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'japaneast'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'japanwest'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jawest'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jinc'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'jinw'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioinc'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioindiacentral'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioindiawest'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioinw'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jnb'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'johannesburg'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'jpe'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'jpw'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'korea central'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'korea south'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'koreacentral'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'koreasouth'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'kr central'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'kr south'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'krc'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'krcentral'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'krs'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'krsouth'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'lg'; RegionId = 'germanynortheast'; RegionName = 'Germany NorthEast'; }
        ,[PSCustomObject]@{ OriginalValue = 'ln'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'lo'; RegionId = 'uksouth2'; RegionName = 'UK South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'london'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'ma'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'malaysiasouth'; RegionId = 'malaysiasouth'; RegionName = 'Malaysia South'; }
        ,[PSCustomObject]@{ OriginalValue = 'malaysiaw'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'malaysiawest'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'melbourne'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'mexicoc'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'mexicocentral'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ml'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'mm'; RegionId = 'uknorth'; RegionName = 'UK North'; }
        ,[PSCustomObject]@{ OriginalValue = 'montreal'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'mrs'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'mumbai'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'mumbai2'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'mwh'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'mx central'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'mxc'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'my west'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'myw'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'ncus'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'ne'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'neu'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'newzealandn'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'newzealandnorth'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'no east'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'no west'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'noe'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'noeast'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'north central us'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'north europe'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'north_europe'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'northcentralus'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'northeurope'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwaye'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwayeast'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwayw'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwaywest'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'now'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'nz north'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'nzn'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'os'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'osaka'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'par'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'paris'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'phx'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'pl central'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'plc'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'pn'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'polandc'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'polandcentral'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ps'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'qa central'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'qac'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'qatarc'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'qatarcentral'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'qatarentral'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'quebeccity'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'sa east'; RegionId = 'saudiarabiaeast'; RegionName = 'Saudi Arabia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'san'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'sanantonio'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'sanorth'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'sao paulo'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'saopaulo'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'saudiarabiaeast'; RegionId = 'saudiarabiaeast'; RegionName = 'Saudi Arabia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'sawest'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'sbr'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'scus'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'se'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'se central'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'se south'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'sea'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'seas'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'seattle'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'seau'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'sec'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ses'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'sg'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'sh'; RegionId = 'chinaeast'; RegionName = 'China East'; }
        ,[PSCustomObject]@{ OriginalValue = 'sha'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'silicon valley'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'siliconvalley'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'sin'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'singapore'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'singapore central'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'singaporec'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'singaporecentral'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'singc'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'sn'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'south central us'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'south east asia'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'south india'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafrican'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafricanorth'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafricaw'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafricawest'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'southcentralus'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'southcentralus2'; RegionId = 'southcentralus2'; RegionName = 'South Central US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'southcentralusstg'; RegionId = 'southcentralusstg'; RegionName = 'South Central US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'southeast asia'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'southeast_asia'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'southeastasia'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'southeastus'; RegionId = 'southeastus'; RegionName = 'Southeast US'; }
        ,[PSCustomObject]@{ OriginalValue = 'southindia'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'southsoutheastasia'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'spainc'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'spaincentral'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'sweden central'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedenc'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedencentral'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedens'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedensouth'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandn'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandnorth'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandw'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandwest'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'sy'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'syd'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'sydney'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'taiwann'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'taiwannorth'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'taiwannorthwest'; RegionId = 'taiwannorthwest'; RegionName = 'Taiwan Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'tokyo'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'toronto'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'tw north'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'twn'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'ty'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaec'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaecentral'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaen'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaenorth'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'uk north'; RegionId = 'uknorth'; RegionName = 'UK North'; }
        ,[PSCustomObject]@{ OriginalValue = 'uk south'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'uk south 2'; RegionId = 'uksouth2'; RegionName = 'UK South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'uk west'; RegionId = 'ukwest'; RegionName = 'UK West'; }
        ,[PSCustomObject]@{ OriginalValue = 'uknorth'; RegionId = 'uknorth'; RegionName = 'UK North'; }
        ,[PSCustomObject]@{ OriginalValue = 'uks'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'uksouth'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'uksouth2'; RegionId = 'uksouth2'; RegionName = 'UK South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'ukw'; RegionId = 'ukwest'; RegionName = 'UK West'; }
        ,[PSCustomObject]@{ OriginalValue = 'ukwest'; RegionId = 'ukwest'; RegionName = 'UK West'; }
        ,[PSCustomObject]@{ OriginalValue = 'unassigned'; RegionId = 'global'; RegionName = 'Global'; }
        ,[PSCustomObject]@{ OriginalValue = 'unitedkingdomsouth'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'unitedkingdomsouth2'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'unitedstates'; RegionId = 'unitedstates'; RegionName = 'United States'; }
        ,[PSCustomObject]@{ OriginalValue = 'us central'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'us dod central'; RegionId = 'usdodcentral'; RegionName = 'USDoD Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'us dod east'; RegionId = 'usdodeast'; RegionName = 'USDoD East'; }
        ,[PSCustomObject]@{ OriginalValue = 'us east'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'us east 2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'us east 3'; RegionId = 'eastus3'; RegionName = 'East US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'us gov az'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'us gov iowa'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'us gov tx'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'us gov virginia'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'us north central'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'us sec east'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'us sec west'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'us sec west central'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'us south central'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'us west'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'us west 2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'us west 3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'us west central'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'us2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'us_east'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'us_west'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'usa'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'uscentral'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodcentral'; RegionId = 'usdodcentral'; RegionName = 'USDoD Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodeast'; RegionId = 'usdodeast'; RegionName = 'USDoD East'; }
        ,[PSCustomObject]@{ OriginalValue = 'useast'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'useast2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'useast2euap'; RegionId = 'useast2euap'; RegionName = 'US East 2 EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgov arizona'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgov iowa'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgov south central'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgov texas'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgov virginia'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovarizona'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovaz'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovcentral'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgoveast'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgoviowa'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovsc'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovsouthcentral'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovsouthwest'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovsw'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovtexas'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovtx'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovvirginia'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovwc'; RegionId = 'usgovwyoming'; RegionName = 'USGov Wyoming'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovwyoming'; RegionId = 'usgovwyoming'; RegionName = 'USGov Wyoming'; }
        ,[PSCustomObject]@{ OriginalValue = 'usnorth'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'usnorthcentral'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'usse'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussece'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'usseceast'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecw'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecwc'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecwest'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecwestcentral'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussgovarizona'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussouth'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussouthcentral'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'usstagesc'; RegionId = 'southcentralusstg'; RegionName = 'South Central US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussw'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'usswc'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ustsc'; RegionId = 'southcentralusstg'; RegionName = 'South Central US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'usv'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'usw3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswest'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswest2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswest3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswestcentral'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'wcu'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'wcus'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'we'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'west central us'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'west europe'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'west india'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'west us'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'west us 2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'west_europe'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'westcentralus'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'westeurope'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'westindia'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'westus'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'westus2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'westus3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'weu'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'wu'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'wu2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'wus'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'wus2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'wus3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'yq'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'yt'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'za north'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'za west'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'zanorth'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'zawest'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
    )
}
