# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-FinOpsRegionsData {
    return [PSCustomObject]@(
        [PSCustomObject]@{ OriginalValue = 'AE Central'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'AE North'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'am'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'AP East'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'AP Southeast'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'apacsoutheast2'; RegionId = 'apacsoutheast2'; RegionName = 'APAC Southeast 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'arlem'; RegionId = 'arlem'; RegionName = 'Arlem'; }
        ,[PSCustomObject]@{ OriginalValue = 'asiaeast'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'asiasoutheast'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'asiasoutheast2'; RegionId = 'apacsoutheast2'; RegionName = 'APAC Southeast 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'AT East'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'ate'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'AU Central'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'AU Central 2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'AU East'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'AU Southeast'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'auh'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiac'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiac2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiacentral'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiacentral2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiaeast'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'australiasoutheast'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'austriae'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'austriaeast'; RegionId = 'austriaeast'; RegionName = 'Austria East'; }
        ,[PSCustomObject]@{ OriginalValue = 'bd'; RegionId = 'usdodeast'; RegionName = 'USDoD East'; }
        ,[PSCustomObject]@{ OriginalValue = 'BE Central'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'bec'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'belgiumc'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'belgiumcentral'; RegionId = 'belgiumcentral'; RegionName = 'Belgium Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'bj'; RegionId = 'chinanorth'; RegionName = 'China North'; }
        ,[PSCustomObject]@{ OriginalValue = 'bjs'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'bl'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'Bleu France Central'; RegionId = 'bleufrancecentral'; RegionName = 'Bleu France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'Bleu France South'; RegionId = 'bleufrancesouth'; RegionName = 'Bleu France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'bleuc'; RegionId = 'bleufrancecentral'; RegionName = 'Bleu France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'bleufrancecentral'; RegionId = 'bleufrancecentral'; RegionName = 'Bleu France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'bleufrancesouth'; RegionId = 'bleufrancesouth'; RegionName = 'Bleu France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'bleus'; RegionId = 'bleufrancesouth'; RegionName = 'Bleu France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'bm'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'bn'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'bn'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'BR South'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'BR Southeast'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilne'; RegionId = 'brazilnortheast'; RegionName = 'Brazil Northeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilnortheast'; RegionId = 'brazilnortheast'; RegionName = 'Brazil Northeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilse'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilsouth'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'brazilsoutheast'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brne'; RegionId = 'brazilnortheast'; RegionName = 'Brazil Northeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'brse'; RegionId = 'brazilsoutheast'; RegionName = 'Brazil Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'by'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'CA Central'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'CA East'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'canadacentral'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'canadaeast'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'cbn'; RegionId = 'eastus2euap'; RegionName = 'East US 2 EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'cbr'; RegionId = 'australiacentral'; RegionName = 'Australia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'cbr2'; RegionId = 'australiacentral2'; RegionName = 'Australia Central 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'cdm'; RegionId = 'centraluseuap'; RegionName = 'Central US EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'centralindia'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'centralus'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'centraluseuap'; RegionId = 'centraluseuap'; RegionName = 'Central US EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'ch'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'CH North'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'CH West'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'chilec'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'chilecentral'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'chilenc'; RegionId = 'chilenorthcentral'; RegionName = 'Chile North Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'chilenorthcentral'; RegionId = 'chilenorthcentral'; RegionName = 'Chile North Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinae2'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinae3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinaeast'; RegionId = 'chinaeast'; RegionName = 'China East'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinaeast2'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinaeast3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinan10'; RegionId = 'chinanorth10'; RegionName = 'China North 10'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinan2'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinan3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinanorth'; RegionId = 'chinanorth'; RegionName = 'China North'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinanorth10'; RegionId = 'chinanorth10'; RegionName = 'China North 10'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinanorth2'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'chinanorth3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'chn'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'chw'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'CL Central'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'CL North Central'; RegionId = 'chilenorthcentral'; RegionName = 'Chile North Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'clc'; RegionId = 'chilecentral'; RegionName = 'Chile Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'clnc'; RegionId = 'chilenorthcentral'; RegionName = 'Chile North Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'CN East'; RegionId = 'chinaeast'; RegionName = 'China East'; }
        ,[PSCustomObject]@{ OriginalValue = 'CN East 2'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'CN East 3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'CN North'; RegionId = 'chinanorth'; RegionName = 'China North'; }
        ,[PSCustomObject]@{ OriginalValue = 'CN North 2'; RegionId = 'chinanorth2'; RegionName = 'China North 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'CN North 3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'cne3'; RegionId = 'chinaeast3'; RegionName = 'China East 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'cnn10'; RegionId = 'chinanorth10'; RegionName = 'China North 10'; }
        ,[PSCustomObject]@{ OriginalValue = 'cnn3'; RegionId = 'chinanorth3'; RegionName = 'China North 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'cpt'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'cq'; RegionId = 'brazilsouth'; RegionName = 'Brazil South'; }
        ,[PSCustomObject]@{ OriginalValue = 'cw'; RegionId = 'ukwest'; RegionName = 'UK West'; }
        ,[PSCustomObject]@{ OriginalValue = 'cy'; RegionId = 'usgovwyoming'; RegionName = 'USGov Wyoming'; }
        ,[PSCustomObject]@{ OriginalValue = 'cy'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'db'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'dd'; RegionId = 'usdodcentral'; RegionName = 'USDoD Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'DE Central'; RegionId = 'germanycentral'; RegionName = 'Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'DE North'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'DE Northeast'; RegionId = 'germanynortheast'; RegionName = 'Germany NorthEast'; }
        ,[PSCustomObject]@{ OriginalValue = 'DE West Central'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'delc'; RegionId = 'deloscloudgermanycentral'; RegionName = 'Delos Cloud Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'deln'; RegionId = 'deloscloudgermanynorth'; RegionName = 'Delos Cloud Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'Delos Cloud Germany Central'; RegionId = 'deloscloudgermanycentral'; RegionName = 'Delos Cloud Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'Delos Cloud Germany North'; RegionId = 'deloscloudgermanynorth'; RegionName = 'Delos Cloud Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'delosc'; RegionId = 'deloscloudgermanycentral'; RegionName = 'Delos Cloud Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'deloscloudgermanycentral'; RegionId = 'deloscloudgermanycentral'; RegionName = 'Delos Cloud Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'deloscloudgermanynorth'; RegionId = 'deloscloudgermanynorth'; RegionName = 'Delos Cloud Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'delosn'; RegionId = 'deloscloudgermanynorth'; RegionName = 'Delos Cloud Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'den'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'Denmark East'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'denmarke'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'denmarkeast'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'dewc'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'dke'; RegionId = 'denmarkeast'; RegionName = 'Denmark East'; }
        ,[PSCustomObject]@{ OriginalValue = 'dm'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'dm'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'dxb'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastasia'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'easteurope'; RegionId = 'easteurope'; RegionName = 'East Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastus'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastus2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastus2euap'; RegionId = 'eastus2euap'; RegionName = 'East US 2 EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastusslv'; RegionId = 'eastusslv'; RegionName = 'East US SLV'; }
        ,[PSCustomObject]@{ OriginalValue = 'eastusstg'; RegionId = 'eastusstg'; RegionName = 'East US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'ES Central'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'esc'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'EU North'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'EU West'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'europeeast'; RegionId = 'easteurope'; RegionName = 'East Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'europenorth'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'europenorth2'; RegionId = 'northeurope2'; RegionName = 'North Europe 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'europewest'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'eusslv'; RegionId = 'eastusslv'; RegionName = 'East US SLV'; }
        ,[PSCustomObject]@{ OriginalValue = 'FI Central'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'finlandc'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'finlandcentral'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'flc'; RegionId = 'finlandcentral'; RegionName = 'Finland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'fr'; RegionId = 'germanycentral'; RegionName = 'Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'FR Central'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'FR South'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'francec'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'francecentral'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'frances'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'francesouth'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanycentral'; RegionId = 'germanycentral'; RegionName = 'Germany Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanyn'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanynorth'; RegionId = 'germanynorth'; RegionName = 'Germany North'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanynortheast'; RegionId = 'germanynortheast'; RegionName = 'Germany NorthEast'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanywc'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'germanywestcentral'; RegionId = 'germanywestcentral'; RegionName = 'Germany West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'grn'; RegionId = 'usnatwest'; RegionName = 'USNat West'; }
        ,[PSCustomObject]@{ OriginalValue = 'hel'; RegionId = 'northeurope2'; RegionName = 'North Europe 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'hk'; RegionId = 'eastasia'; RegionName = 'East Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'ID Central'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'idc'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'IL Central'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'IL Northwest'; RegionId = 'israelnorthwest'; RegionName = 'Israel Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'ilc'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ilnw'; RegionId = 'israelnorthwest'; RegionName = 'Israel Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'IN Central'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'IN Central Jio'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'IN South'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'IN South Central'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'IN West'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'IN West Jio'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiacentral'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiasc'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiasouth'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiasouthcentral'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'indiawest'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'indonesiac'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'indonesiacentral'; RegionId = 'indonesiacentral'; RegionName = 'Indonesia Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'insc'; RegionId = 'indiasouthcentral'; RegionName = 'India South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'israelc'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'israelcentral'; RegionId = 'israelcentral'; RegionName = 'Israel Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'israelnorthwest'; RegionId = 'israelnorthwest'; RegionName = 'Israel Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'israelnw'; RegionId = 'israelnorthwest'; RegionName = 'Israel Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'IT North'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'italyn'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'italynorth'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'itn'; RegionId = 'italynorth'; RegionName = 'Italy North'; }
        ,[PSCustomObject]@{ OriginalValue = 'JA East'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'JA West'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'japaneast'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'japanwest'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jinc'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'jinw'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioinc'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioindiacentral'; RegionId = 'jioindiacentral'; RegionName = 'Jio India Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioindiawest'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jioinw'; RegionId = 'jioindiawest'; RegionName = 'Jio India West'; }
        ,[PSCustomObject]@{ OriginalValue = 'jnb'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'koreacentral'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'koreas2'; RegionId = 'koreasouth2'; RegionName = 'Korea South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'koreasouth'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'koreasouth2'; RegionId = 'koreasouth2'; RegionName = 'Korea South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'KR Central'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'KR South'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'krs2'; RegionId = 'koreasouth2'; RegionName = 'Korea South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'kul'; RegionId = 'apacsoutheast2'; RegionName = 'APAC Southeast 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'lg'; RegionId = 'germanynortheast'; RegionName = 'Germany NorthEast'; }
        ,[PSCustomObject]@{ OriginalValue = 'ln'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'lo'; RegionId = 'uksouth2'; RegionName = 'UK South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'ma'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'malaysias'; RegionId = 'malaysiasouth'; RegionName = 'Malaysia South'; }
        ,[PSCustomObject]@{ OriginalValue = 'malaysiasouth'; RegionId = 'malaysiasouth'; RegionName = 'Malaysia South'; }
        ,[PSCustomObject]@{ OriginalValue = 'malaysiaw'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'malaysiawest'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'mexicoc'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'mexicocentral'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ml'; RegionId = 'australiasoutheast'; RegionName = 'Australia Southeast'; }
        ,[PSCustomObject]@{ OriginalValue = 'mm'; RegionId = 'uknorth'; RegionName = 'UK North'; }
        ,[PSCustomObject]@{ OriginalValue = 'mrs'; RegionId = 'francesouth'; RegionName = 'France South'; }
        ,[PSCustomObject]@{ OriginalValue = 'mwh'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'MX Central'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'mxc'; RegionId = 'mexicocentral'; RegionName = 'Mexico Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'MY South'; RegionId = 'malaysiasouth'; RegionName = 'Malaysia South'; }
        ,[PSCustomObject]@{ OriginalValue = 'MY West'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'mys'; RegionId = 'malaysiasouth'; RegionName = 'Malaysia South'; }
        ,[PSCustomObject]@{ OriginalValue = 'myw'; RegionId = 'malaysiawest'; RegionName = 'Malaysia West'; }
        ,[PSCustomObject]@{ OriginalValue = 'newzealandn'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'newzealandnorth'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'NO East'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'NO West'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'noe'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'northcentralus'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'northeurope'; RegionId = 'northeurope'; RegionName = 'North Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'northeurope2'; RegionId = 'northeurope2'; RegionName = 'North Europe 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwaye'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwayeast'; RegionId = 'norwayeast'; RegionName = 'Norway East'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwayw'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'norwaywest'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'now'; RegionId = 'norwaywest'; RegionName = 'Norway West'; }
        ,[PSCustomObject]@{ OriginalValue = 'NZ North'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'nzn'; RegionId = 'newzealandnorth'; RegionName = 'New Zealand North'; }
        ,[PSCustomObject]@{ OriginalValue = 'ocave'; RegionId = 'ocave'; RegionName = 'Ocave'; }
        ,[PSCustomObject]@{ OriginalValue = 'os'; RegionId = 'japanwest'; RegionName = 'Japan West'; }
        ,[PSCustomObject]@{ OriginalValue = 'par'; RegionId = 'francecentral'; RegionName = 'France Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'phx'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'phxd'; RegionId = 'usdodsouthwest'; RegionName = 'USDoD Southwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'PL Central'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'plc'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'pn'; RegionId = 'centralindia'; RegionName = 'Central India'; }
        ,[PSCustomObject]@{ OriginalValue = 'polandc'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'polandcentral'; RegionId = 'polandcentral'; RegionName = 'Poland Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ps'; RegionId = 'koreasouth'; RegionName = 'Korea South'; }
        ,[PSCustomObject]@{ OriginalValue = 'QA Central'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'qac'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'qatarc'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'qatarcentral'; RegionId = 'qatarcentral'; RegionName = 'Qatar Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'red'; RegionId = 'usnateast'; RegionName = 'USNat East'; }
        ,[PSCustomObject]@{ OriginalValue = 'se'; RegionId = 'koreacentral'; RegionName = 'Korea Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'SE Central'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'SE South'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'sec'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ses'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'sg'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'SG Gov'; RegionId = 'singaporegov'; RegionName = 'Singapore Gov'; }
        ,[PSCustomObject]@{ OriginalValue = 'sgg'; RegionId = 'singaporegov'; RegionName = 'Singapore Gov'; }
        ,[PSCustomObject]@{ OriginalValue = 'sh'; RegionId = 'chinaeast'; RegionName = 'China East'; }
        ,[PSCustomObject]@{ OriginalValue = 'sha'; RegionId = 'chinaeast2'; RegionName = 'China East 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'Singapore Central'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'Singapore North'; RegionId = 'singaporenorth'; RegionName = 'Singapore North'; }
        ,[PSCustomObject]@{ OriginalValue = 'singaporec'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'singaporecentral'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'singaporegov'; RegionId = 'singaporegov'; RegionName = 'Singapore Gov'; }
        ,[PSCustomObject]@{ OriginalValue = 'singaporen'; RegionId = 'singaporenorth'; RegionName = 'Singapore North'; }
        ,[PSCustomObject]@{ OriginalValue = 'singaporenorth'; RegionId = 'singaporenorth'; RegionName = 'Singapore North'; }
        ,[PSCustomObject]@{ OriginalValue = 'singc'; RegionId = 'singaporecentral'; RegionName = 'Singapore Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'singn'; RegionId = 'singaporenorth'; RegionName = 'Singapore North'; }
        ,[PSCustomObject]@{ OriginalValue = 'sn'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'sn'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafrican'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafricanorth'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafricaw'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'southafricawest'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
        ,[PSCustomObject]@{ OriginalValue = 'southcentralus'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'southcentralusstg'; RegionId = 'southcentralusstg'; RegionName = 'South Central US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'southeastasia'; RegionId = 'southeastasia'; RegionName = 'Southeast Asia'; }
        ,[PSCustomObject]@{ OriginalValue = 'southindia'; RegionId = 'southindia'; RegionName = 'South India'; }
        ,[PSCustomObject]@{ OriginalValue = 'spainc'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'spaincentral'; RegionId = 'spaincentral'; RegionName = 'Spain Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedenc'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedencentral'; RegionId = 'swedencentral'; RegionName = 'Sweden Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedens'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'swedensouth'; RegionId = 'swedensouth'; RegionName = 'Sweden South'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandn'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandnorth'; RegionId = 'switzerlandnorth'; RegionName = 'Switzerland North'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandw'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'switzerlandwest'; RegionId = 'switzerlandwest'; RegionName = 'Switzerland West'; }
        ,[PSCustomObject]@{ OriginalValue = 'sy'; RegionId = 'australiaeast'; RegionName = 'Australia East'; }
        ,[PSCustomObject]@{ OriginalValue = 'taiwann'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'taiwannorth'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'taiwannorthwest'; RegionId = 'taiwannorthwest'; RegionName = 'Taiwan Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'taiwannw'; RegionId = 'taiwannorthwest'; RegionName = 'Taiwan Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'TW North'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'TW Northwest'; RegionId = 'taiwannorthwest'; RegionName = 'Taiwan Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'twn'; RegionId = 'taiwannorth'; RegionName = 'Taiwan North'; }
        ,[PSCustomObject]@{ OriginalValue = 'twnw'; RegionId = 'taiwannorthwest'; RegionName = 'Taiwan Northwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'ty'; RegionId = 'japaneast'; RegionName = 'Japan East'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaec'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaecentral'; RegionId = 'uaecentral'; RegionName = 'UAE Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaen'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'uaenorth'; RegionId = 'uaenorth'; RegionName = 'UAE North'; }
        ,[PSCustomObject]@{ OriginalValue = 'UK North'; RegionId = 'uknorth'; RegionName = 'UK North'; }
        ,[PSCustomObject]@{ OriginalValue = 'UK South'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'UK South 2'; RegionId = 'uksouth2'; RegionName = 'UK South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'UK West'; RegionId = 'ukwest'; RegionName = 'UK West'; }
        ,[PSCustomObject]@{ OriginalValue = 'uknorth'; RegionId = 'uknorth'; RegionName = 'UK North'; }
        ,[PSCustomObject]@{ OriginalValue = 'uksouth'; RegionId = 'uksouth'; RegionName = 'UK South'; }
        ,[PSCustomObject]@{ OriginalValue = 'uksouth2'; RegionId = 'uksouth2'; RegionName = 'UK South 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'ukwest'; RegionId = 'ukwest'; RegionName = 'UK West'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Central'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Central'; RegionId = 'centraluseuap'; RegionName = 'Central US EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'US DoD'; RegionId = 'usdodcentral'; RegionName = 'USDoD Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'US DoD'; RegionId = 'usdodeast'; RegionName = 'USDoD East'; }
        ,[PSCustomObject]@{ OriginalValue = 'US East'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'US East 2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'US East 2'; RegionId = 'eastus2euap'; RegionName = 'East US 2 EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Gov'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Gov'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Gov AZ'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Gov TX'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Nat East'; RegionId = 'usnateast'; RegionName = 'USNat East'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Nat West'; RegionId = 'usnatwest'; RegionName = 'USNat West'; }
        ,[PSCustomObject]@{ OriginalValue = 'US North Central'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Sec Central'; RegionId = 'usseccentral'; RegionName = 'USSec Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Sec East'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Sec West'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'US Sec West Central'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'US South Central'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'US West'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'US West 2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'US West 3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'US West Central'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'uscentral'; RegionId = 'centralus'; RegionName = 'Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'uscentraleuap'; RegionId = 'centraluseuap'; RegionName = 'Central US EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodcentral'; RegionId = 'usdodcentral'; RegionName = 'USDoD Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodeast'; RegionId = 'usdodeast'; RegionName = 'USDoD East'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodsc'; RegionId = 'usdodsouthcentral'; RegionName = 'USDoD South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodsouthcentral'; RegionId = 'usdodsouthcentral'; RegionName = 'USDoD South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodsouthwest'; RegionId = 'usdodsouthwest'; RegionName = 'USDoD Southwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodsw'; RegionId = 'usdodsouthwest'; RegionName = 'USDoD Southwest'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodwc'; RegionId = 'usdodwestcentral'; RegionName = 'USDoD West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdodwestcentral'; RegionId = 'usdodwestcentral'; RegionName = 'USDoD West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdsc'; RegionId = 'usdodsouthcentral'; RegionName = 'USDoD South Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usdwc'; RegionId = 'usdodwestcentral'; RegionName = 'USDoD West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'use'; RegionId = 'eastusslv'; RegionName = 'East US SLV'; }
        ,[PSCustomObject]@{ OriginalValue = 'useast'; RegionId = 'eastus'; RegionName = 'East US'; }
        ,[PSCustomObject]@{ OriginalValue = 'useast2'; RegionId = 'eastus2'; RegionName = 'East US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'useast2euap'; RegionId = 'eastus2euap'; RegionName = 'East US 2 EUAP'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovarizona'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovcentral'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgoveast'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgoviowa'; RegionId = 'usgoviowa'; RegionName = 'USGov Iowa'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovsc'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovsw'; RegionId = 'usgovarizona'; RegionName = 'USGov Arizona'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovtexas'; RegionId = 'usgovtexas'; RegionName = 'USGov Texas'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovvirginia'; RegionId = 'usgovvirginia'; RegionName = 'USGov Virginia'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovwc'; RegionId = 'usgovwyoming'; RegionName = 'USGov Wyoming'; }
        ,[PSCustomObject]@{ OriginalValue = 'usgovwyoming'; RegionId = 'usgovwyoming'; RegionName = 'USGov Wyoming'; }
        ,[PSCustomObject]@{ OriginalValue = 'usnate'; RegionId = 'usnateast'; RegionName = 'USNat East'; }
        ,[PSCustomObject]@{ OriginalValue = 'usnateast'; RegionId = 'usnateast'; RegionName = 'USNat East'; }
        ,[PSCustomObject]@{ OriginalValue = 'usnatw'; RegionId = 'usnatwest'; RegionName = 'USNat West'; }
        ,[PSCustomObject]@{ OriginalValue = 'usnatwest'; RegionId = 'usnatwest'; RegionName = 'USNat West'; }
        ,[PSCustomObject]@{ OriginalValue = 'usnorth'; RegionId = 'northcentralus'; RegionName = 'North Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussc'; RegionId = 'usseccentral'; RegionName = 'USSec Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usse'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecc'; RegionId = 'usseccentral'; RegionName = 'USSec Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'usseccentral'; RegionId = 'usseccentral'; RegionName = 'USSec Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussece'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'usseceast'; RegionId = 'usseceast'; RegionName = 'USSec East'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecw'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecwc'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecwest'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussecwestcentral'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussouth'; RegionId = 'southcentralus'; RegionName = 'South Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'usstagee'; RegionId = 'eastusstg'; RegionName = 'East US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'usstagesc'; RegionId = 'southcentralusstg'; RegionName = 'South Central US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'ussw'; RegionId = 'ussecwest'; RegionName = 'USSec West'; }
        ,[PSCustomObject]@{ OriginalValue = 'usswc'; RegionId = 'ussecwestcentral'; RegionName = 'USSec West Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'uste'; RegionId = 'eastusstg'; RegionName = 'East US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'ustsc'; RegionId = 'southcentralusstg'; RegionName = 'South Central US STG'; }
        ,[PSCustomObject]@{ OriginalValue = 'usw3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswest'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswest2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswest3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'uswestcentral'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'westcentralus'; RegionId = 'westcentralus'; RegionName = 'West Central US'; }
        ,[PSCustomObject]@{ OriginalValue = 'westeurope'; RegionId = 'westeurope'; RegionName = 'West Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'westindia'; RegionId = 'westindia'; RegionName = 'West India'; }
        ,[PSCustomObject]@{ OriginalValue = 'westus'; RegionId = 'westus'; RegionName = 'West US'; }
        ,[PSCustomObject]@{ OriginalValue = 'westus2'; RegionId = 'westus2'; RegionName = 'West US 2'; }
        ,[PSCustomObject]@{ OriginalValue = 'westus3'; RegionId = 'westus3'; RegionName = 'West US 3'; }
        ,[PSCustomObject]@{ OriginalValue = 'yq'; RegionId = 'canadaeast'; RegionName = 'Canada East'; }
        ,[PSCustomObject]@{ OriginalValue = 'yt'; RegionId = 'canadacentral'; RegionName = 'Canada Central'; }
        ,[PSCustomObject]@{ OriginalValue = 'yyy'; RegionId = 'easteurope'; RegionName = 'East Europe'; }
        ,[PSCustomObject]@{ OriginalValue = 'ZA North'; RegionId = 'southafricanorth'; RegionName = 'South Africa North'; }
        ,[PSCustomObject]@{ OriginalValue = 'ZA West'; RegionId = 'southafricawest'; RegionName = 'South Africa West'; }
    )
}
