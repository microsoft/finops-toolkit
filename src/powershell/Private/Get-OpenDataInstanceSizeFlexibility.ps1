# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-OpenDataInstanceSizeFlexibility
{
    param()
    return [PSCustomObject]@(
        [PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b0'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b1'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b10'; Ratio = 19.69; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b100'; Ratio = 156; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b1000'; Ratio = 1248; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b150'; Ratio = 235.63; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b20'; Ratio = 39.31; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b250'; Ratio = 315; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b3'; Ratio = 4.06; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b350'; Ratio = 471.25; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b5'; Ratio = 9.75; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b50'; Ratio = 78.56; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b500'; Ratio = 624; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Balanced'; ArmSkuName = 'azure_managed_redis_balanced_b700'; Ratio = 936; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x10'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x100'; Ratio = 31.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x150'; Ratio = 47.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x20'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x250'; Ratio = 63.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x3'; Ratio = 1.5; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x350'; Ratio = 95.8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x50'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x500'; Ratio = 127.7; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Compute Optimized'; ArmSkuName = 'azure_managed_redis_compute_optimized_x700'; Ratio = 159.7; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Flash Optimized'; ArmSkuName = 'azure_managed_redis_flash_optimized_a1000'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Flash Optimized'; ArmSkuName = 'azure_managed_redis_flash_optimized_a1500'; Ratio = 6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Flash Optimized'; ArmSkuName = 'azure_managed_redis_flash_optimized_a2000'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Flash Optimized'; ArmSkuName = 'azure_managed_redis_flash_optimized_a250'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Flash Optimized'; ArmSkuName = 'azure_managed_redis_flash_optimized_a4500'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Flash Optimized'; ArmSkuName = 'azure_managed_redis_flash_optimized_a500'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Flash Optimized'; ArmSkuName = 'azure_managed_redis_flash_optimized_a700'; Ratio = 3; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m10'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m100'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m1000'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m150'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m1500'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m20'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m2000'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m250'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m350'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m50'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m500'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Managed Redis - Memory Optimized'; ArmSkuName = 'azure_managed_redis_memory_optimized_m700'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise'; ArmSkuName = 'azure_redis_cache_enterprise_e1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise'; ArmSkuName = 'azure_redis_cache_enterprise_e10'; Ratio = 12.03; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise'; ArmSkuName = 'azure_redis_cache_enterprise_e100'; Ratio = 94.23; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise'; ArmSkuName = 'azure_redis_cache_enterprise_e20'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise'; ArmSkuName = 'azure_redis_cache_enterprise_e50'; Ratio = 47.13; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise Flash'; ArmSkuName = 'azure_redis_cache_enterprise_flash_f1500'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise Flash'; ArmSkuName = 'azure_redis_cache_enterprise_flash_f300'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Enterprise Flash'; ArmSkuName = 'azure_redis_cache_enterprise_flash_f700'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Premium'; ArmSkuName = 'azure_redis_cache_premium_p1_cache'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Premium'; ArmSkuName = 'azure_redis_cache_premium_p2_cache'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Premium'; ArmSkuName = 'azure_redis_cache_premium_p3_cache'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Premium'; ArmSkuName = 'azure_redis_cache_premium_p4_cache'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Azure Redis Cache Premium'; ArmSkuName = 'azure_redis_cache_premium_p5_cache'; Ratio = 18.14; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B16als_v2'; Ratio = 113.4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B16as_v2'; Ratio = 128.08; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B2als_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B2as_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B2ats_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B32als_v2'; Ratio = 226.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B32as_v2'; Ratio = 255.96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B4als_v2'; Ratio = 28.3; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B4as_v2'; Ratio = 31.92; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B8als_v2'; Ratio = 56.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Basv2 Series'; ArmSkuName = 'Standard_B8as_v2'; Ratio = 64.04; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B16pls_v2'; Ratio = 113.34; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B16ps_v2'; Ratio = 128.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B2pls_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B2ps_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B2pts_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B4pls_v2'; Ratio = 28.34; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B4ps_v2'; Ratio = 31.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B8pls_v2'; Ratio = 56.66; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bpsv2 Series'; ArmSkuName = 'Standard_B8ps_v2'; Ratio = 64.04; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B16ls_v2'; Ratio = 113.27; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B16s_v2'; Ratio = 128.08; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B2ls_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B2s_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B2ts_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B32ls_v2'; Ratio = 226.73; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B32s_v2'; Ratio = 255.96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B4ls_v2'; Ratio = 28.27; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B4s_v2'; Ratio = 31.92; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B8ls_v2'; Ratio = 56.73; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Bsv2 Series'; ArmSkuName = 'Standard_B8s_v2'; Ratio = 64.04; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D16ads_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D2ads_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D32ads_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D48ads_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D4ads_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D64ads_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D8ads_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series'; ArmSkuName = 'Standard_D96ads_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dadsv5 Series DedicatedHost'; ArmSkuName = 'dadsv5_type1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D16as_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D2as_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D32as_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D48as_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D4as_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D64as_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D8as_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series'; ArmSkuName = 'Standard_D96as_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series Dedicated Host'; ArmSkuName = 'dasv4_type1'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv4 Series Dedicated Host'; ArmSkuName = 'dasv4_type2'; Ratio = 99.84; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D16as_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D2as_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D32as_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D48as_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D4as_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D64as_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D8as_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series'; ArmSkuName = 'Standard_D96as_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dasv5 Series DedicatedHost'; ArmSkuName = 'dasv5_type1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D16a_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D2a_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D32a_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D48a_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D4a_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D64a_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D8a_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dav4 Series'; ArmSkuName = 'Standard_D96a_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series DedicatedHost'; ArmSkuName = 'dcadsv5 type 1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC16ads_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC2ads_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC32ads_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC48ads_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC4ads_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC64ads_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC8ads_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCadsv5-series Linux'; ArmSkuName = 'Standard_DC96ads_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series DedicatedHost'; ArmSkuName = 'dcasv5 type 1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC16as_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC2as_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC32as_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC48as_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC4as_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC64as_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC8as_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCasv5-series Linux'; ArmSkuName = 'Standard_DC96as_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series DedicatedHost'; ArmSkuName = 'dcdsv3 type1'; Ratio = 60; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC16ds_v3'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC1ds_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC24ds_v3'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC2ds_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC32ds_v3'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC48ds_v3'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC4ds_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCdsv3 Series Linux'; ArmSkuName = 'Standard_DC8ds_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series DedicatedHost'; ArmSkuName = 'dcsv3 type1'; Ratio = 51; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC16s_v3'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC1s_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC24s_v3'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC2s_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC32s_v3'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC48s_v3'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC4s_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DCsv3 Series Linux'; ArmSkuName = 'Standard_DC8s_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series'; ArmSkuName = 'Standard_D16ds_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series'; ArmSkuName = 'Standard_D2ds_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series'; ArmSkuName = 'Standard_D32ds_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series'; ArmSkuName = 'Standard_D48ds_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series'; ArmSkuName = 'Standard_D4ds_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series'; ArmSkuName = 'Standard_D64ds_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series'; ArmSkuName = 'Standard_D8ds_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series Dedicated Host'; ArmSkuName = 'ddsv4_type 1'; Ratio = 68; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv4 Series Dedicated Host'; ArmSkuName = 'ddsv4_type2'; Ratio = 80.92; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D16ds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D2ds_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D32ds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D48ds_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D4ds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D64ds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D8ds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series'; ArmSkuName = 'Standard_D96ds_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddsv5 Series DedicatedHost'; ArmSkuName = 'ddsv5_type1'; Ratio = 107; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv4 Series'; ArmSkuName = 'Standard_D16d_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv4 Series'; ArmSkuName = 'Standard_D2d_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv4 Series'; ArmSkuName = 'Standard_D32d_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv4 Series'; ArmSkuName = 'Standard_D48d_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv4 Series'; ArmSkuName = 'Standard_D4d_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv4 Series'; ArmSkuName = 'Standard_D64d_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv4 Series'; ArmSkuName = 'Standard_D8d_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D16d_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D2d_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D32d_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D48d_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D4d_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D64d_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D8d_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ddv5 Series'; ArmSkuName = 'Standard_D96d_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D16lds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D2lds_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D32lds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D48lds_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D4lds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D64lds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D8lds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dldsv5 Series'; ArmSkuName = 'Standard_D96lds_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D16ls_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D2ls_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D32ls_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D48ls_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D4ls_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D64ls_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D8ls_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dlsv5 Series'; ArmSkuName = 'Standard_D96ls_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpdsv5 Series'; ArmSkuName = 'Standard_D16pds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpdsv5 Series'; ArmSkuName = 'Standard_D2pds_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpdsv5 Series'; ArmSkuName = 'Standard_D32pds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpdsv5 Series'; ArmSkuName = 'Standard_D48pds_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpdsv5 Series'; ArmSkuName = 'Standard_D4pds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpdsv5 Series'; ArmSkuName = 'Standard_D64pds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpdsv5 Series'; ArmSkuName = 'Standard_D8pds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpldsv5 Series'; ArmSkuName = 'Standard_D16plds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpldsv5 Series'; ArmSkuName = 'Standard_D2plds_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpldsv5 Series'; ArmSkuName = 'Standard_D32plds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpldsv5 Series'; ArmSkuName = 'Standard_D48plds_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpldsv5 Series'; ArmSkuName = 'Standard_D4plds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpldsv5 Series'; ArmSkuName = 'Standard_D64plds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpldsv5 Series'; ArmSkuName = 'Standard_D8plds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dplsv5 Series'; ArmSkuName = 'Standard_D16pls_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dplsv5 Series'; ArmSkuName = 'Standard_D2pls_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dplsv5 Series'; ArmSkuName = 'Standard_D32pls_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dplsv5 Series'; ArmSkuName = 'Standard_D48pls_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dplsv5 Series'; ArmSkuName = 'Standard_D4pls_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dplsv5 Series'; ArmSkuName = 'Standard_D64pls_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dplsv5 Series'; ArmSkuName = 'Standard_D8pls_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpsv5 Series'; ArmSkuName = 'Standard_D16ps_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpsv5 Series'; ArmSkuName = 'Standard_D2ps_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpsv5 Series'; ArmSkuName = 'Standard_D32ps_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpsv5 Series'; ArmSkuName = 'Standard_D48ps_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpsv5 Series'; ArmSkuName = 'Standard_D4ps_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpsv5 Series'; ArmSkuName = 'Standard_D64ps_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dpsv5 Series'; ArmSkuName = 'Standard_D8ps_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series'; ArmSkuName = 'Standard_DS1_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series'; ArmSkuName = 'Standard_DS2_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series'; ArmSkuName = 'Standard_DS3_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series'; ArmSkuName = 'Standard_DS4_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series'; ArmSkuName = 'Standard_DS5_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS11_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS11-1_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS12_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS12-1_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS12-2_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS13_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS13-2_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS13-4_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS14_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS14-4_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS14-8_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv2 Series High Memory'; ArmSkuName = 'Standard_DS15_v2'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv3 Series Dedicated Host'; ArmSkuName = 'dsv3_type3'; Ratio = 85; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv3 Series Dedicated Host'; ArmSkuName = 'dsv3_type4'; Ratio = 106.08; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv4 Series'; ArmSkuName = 'Standard_D16s_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv4 Series'; ArmSkuName = 'Standard_D2s_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv4 Series'; ArmSkuName = 'Standard_D32s_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv4 Series'; ArmSkuName = 'Standard_D48s_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv4 Series'; ArmSkuName = 'Standard_D4s_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv4 Series'; ArmSkuName = 'Standard_D64s_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv4 Series'; ArmSkuName = 'Standard_D8s_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv4 Series Dedicated Host'; ArmSkuName = 'dsv4_type1'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'DSv4 Series Dedicated Host'; ArmSkuName = 'dsv4_type2'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D16s_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D2s_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D32s_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D48s_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D4s_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D64s_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D8s_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series'; ArmSkuName = 'Standard_D96s_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dsv5 Series DedicatedHost'; ArmSkuName = 'dsv5_type1'; Ratio = 107; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv4 Series'; ArmSkuName = 'Standard_D16_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv4 Series'; ArmSkuName = 'Standard_D2_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv4 Series'; ArmSkuName = 'Standard_D32_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv4 Series'; ArmSkuName = 'Standard_D4_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv4 Series'; ArmSkuName = 'Standard_D48_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv4 Series'; ArmSkuName = 'Standard_D64_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv4 Series'; ArmSkuName = 'Standard_D8_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D16_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D2_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D32_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D4_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D48_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D64_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D8_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Dv5 Series'; ArmSkuName = 'Standard_D96_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E112iads_v5'; Ratio = 123.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E16-4ads_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E16-8ads_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E16ads_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E20ads_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E2ads_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E32-16ads_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E32-8ads_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E32ads_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E4-2ads_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E48ads_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E4ads_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E64-16ads_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E64-32ads_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E64ads_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E8-2ads_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E8-4ads_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E8ads_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E96-24ads_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E96-48ads_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series'; ArmSkuName = 'Standard_E96ads_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eadsv5 Series DedicatedHost'; ArmSkuName = 'eadsv5_type1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E16-4as_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E16-8as_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E16as_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E20as_v4'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E2as_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E32-16as_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E32-8as_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E32as_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E4-2as_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E48as_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E4as_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E64-16as_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E64-32as_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E64as_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E8-2as_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E8-4as_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E8as_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E96-24as_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E96-48as_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E96as_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series'; ArmSkuName = 'Standard_E96ias_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series Dedicated Host'; ArmSkuName = 'easv4_type1'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv4 Series Dedicated Host'; ArmSkuName = 'easv4_type2'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E112ias_v5'; Ratio = 123.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E16-4as_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E16-8as_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E16as_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E20as_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E2as_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E32-16as_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E32-8as_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E32as_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E4-2as_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E48as_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E4as_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E64-16as_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E64-32as_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E64as_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E8-2as_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E8-4as_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E8as_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E96-24as_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E96-48as_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series'; ArmSkuName = 'Standard_E96as_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Easv5 Series DedicatedHost'; ArmSkuName = 'easv5_type1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E16a_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E20a_v4'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E2a_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E32a_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E48a_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E4a_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E64a_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E8a_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Eav4 Series'; ArmSkuName = 'Standard_E96a_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E112ibds_v5'; Ratio = 123.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E16bds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E2bds_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E32bds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E48bds_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E4bds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E64bds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E8bds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series'; ArmSkuName = 'Standard_E96bds_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebdsv5 Series Dedicated Host'; ArmSkuName = 'ebdsv5-type1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E112ibs_v5'; Ratio = 123.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E16bs_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E2bs_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E32bs_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E48bs_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E4bs_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E64bs_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E8bs_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series'; ArmSkuName = 'Standard_E96bs_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ebsv5 Series Dedicated Host'; ArmSkuName = 'ebsv5-type1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series DedicatedHost'; ArmSkuName = 'ecadsv5 type 1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC16ads_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC20ads_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC2ads_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC32ads_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC48ads_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC4ads_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC64ads_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC8ads_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC96ads_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECadsv5-series Linux'; ArmSkuName = 'Standard_EC96iads_v5'; Ratio = 105.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series DedicatedHost'; ArmSkuName = 'ecasv5 type 1'; Ratio = 112; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC16as_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC20as_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC2as_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC32as_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC48as_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC4as_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC64as_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC8as_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC96as_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ECasv5-series Linux'; ArmSkuName = 'Standard_EC96ias_v5'; Ratio = 105.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E16-4ds_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E16-8ds_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E16ds_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E20ds_v4'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E2ds_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E32-16ds_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E32-8ds_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E32ds_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E4-2ds_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E48ds_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E4ds_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E64-16ds_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E64-32ds_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E64ds_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E8-2ds_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E8-4ds_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series'; ArmSkuName = 'Standard_E8ds_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series Dedicated Host'; ArmSkuName = 'edsv4_type 1'; Ratio = 68; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series Dedicated Host'; ArmSkuName = 'edsv4_type2'; Ratio = 80.92; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv4 Series Isolated'; ArmSkuName = 'Standard_E80ids_v4'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E16-4ds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E16-8ds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E16ds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E20ds_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E2ds_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E32-16ds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E32-8ds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E32ds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E4-2ds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E48ds_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E4ds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E64-16ds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E64-32ds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E64ds_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E8-2ds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E8-4ds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E8ds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E96-24ds_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E96-48ds_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series'; ArmSkuName = 'Standard_E96ds_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series DedicatedHost'; ArmSkuName = 'edsv5_type1'; Ratio = 107; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edsv5 Series Isolated'; ArmSkuName = 'Standard_E104ids_v5'; Ratio = 104; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E16d_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E20d_v4'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E2d_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E32d_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E48d_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E4d_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E64d_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv4 Series'; ArmSkuName = 'Standard_E8d_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E104id_v5'; Ratio = 114.4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E16d_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E20d_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E2d_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E32d_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E48d_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E4d_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E64d_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E8d_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Edv5 Series'; ArmSkuName = 'Standard_E96d_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epdsv5 Series'; ArmSkuName = 'Standard_E16pds_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epdsv5 Series'; ArmSkuName = 'Standard_E20pds_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epdsv5 Series'; ArmSkuName = 'Standard_E2pds_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epdsv5 Series'; ArmSkuName = 'Standard_E32pds_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epdsv5 Series'; ArmSkuName = 'Standard_E4pds_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epdsv5 Series'; ArmSkuName = 'Standard_E8pds_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epsv5 Series'; ArmSkuName = 'Standard_E16ps_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epsv5 Series'; ArmSkuName = 'Standard_E20ps_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epsv5 Series'; ArmSkuName = 'Standard_E2ps_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epsv5 Series'; ArmSkuName = 'Standard_E32ps_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epsv5 Series'; ArmSkuName = 'Standard_E4ps_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Epsv5 Series'; ArmSkuName = 'Standard_E8ps_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E16-4s_v3'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E16-8s_v3'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E16s_v3'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E20s_v3'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E2s_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E32-16s_v3'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E32-8s_v3'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E32s_v3'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E4-2s_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E48s_v3'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E4s_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E64-16s_v3'; Ratio = 57.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E64-32s_v3'; Ratio = 57.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E64s_v3'; Ratio = 57.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E8-2s_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E8-4s_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series'; ArmSkuName = 'Standard_E8s_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series Dedicated Host'; ArmSkuName = 'esv3_type3'; Ratio = 68.82; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv3 Series Dedicated Host'; ArmSkuName = 'esv3_type4'; Ratio = 93; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E16-4s_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E16-8s_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E16s_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E20s_v4'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E2s_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E32-16s_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E32-8s_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E32s_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E4-2s_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E48s_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E4s_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E64-16s_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E64-32s_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E64s_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E8-2s_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E8-4s_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series'; ArmSkuName = 'Standard_E8s_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv4 Series Dedicated Host'; ArmSkuName = 'esv4_type1'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv4 Series Dedicated Host'; ArmSkuName = 'esv4_type2'; Ratio = 83.84; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'ESv4 Series Dedicated Host'; ArmSkuName = 'standard_e64is_v4_special'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv4 Series Isolated'; ArmSkuName = 'Standard_E80is_v4'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E16-4s_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E16-8s_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E16s_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E20s_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E2s_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E32-16s_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E32-8s_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E32s_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E4-2s_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E48s_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E4s_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E64-16s_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E64-32s_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E64s_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E8-2s_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E8-4s_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E8s_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E96-24s_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E96-48s_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series'; ArmSkuName = 'Standard_E96s_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series DedicatedHost'; ArmSkuName = 'esv5_type1'; Ratio = 107; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Esv5 Series Isolated'; ArmSkuName = 'Standard_E104is_v5'; Ratio = 104; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E16_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E2_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E20_v4'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E32_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E4_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E48_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E64_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev4 Series'; ArmSkuName = 'Standard_E8_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E104i_v5'; Ratio = 114.4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E16_v5'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E2_v5'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E20_v5'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E32_v5'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E4_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E48_v5'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E64_v5'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E8_v5'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Ev5 Series'; ArmSkuName = 'Standard_E96_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F16s_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F2s_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F32s_v2'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F48s_v2'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F4s_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F64s_v2'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F72s_v2'; Ratio = 72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series'; ArmSkuName = 'Standard_F8s_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series Dedicated Host'; ArmSkuName = 'fsv2 type3'; Ratio = 93.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series Dedicated Host'; ArmSkuName = 'fsv2_type2'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FSv2 Series Dedicated Host'; ArmSkuName = 'fsv2_type4'; Ratio = 106.4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FX Series Dedicated Host'; ArmSkuName = 'fxmds type1'; Ratio = 56; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FX Series Linux'; ArmSkuName = 'Standard_FX12mds'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FX Series Linux'; ArmSkuName = 'Standard_FX24mds'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FX Series Linux'; ArmSkuName = 'Standard_FX36mds'; Ratio = 36; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FX Series Linux'; ArmSkuName = 'Standard_FX48mds'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'FX Series Linux'; ArmSkuName = 'Standard_FX4mds'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBrsv3 Series Low Latency'; ArmSkuName = 'Standard_HB120-16rs_v3'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBrsv3 Series Low Latency'; ArmSkuName = 'Standard_HB120-32rs_v3'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBrsv3 Series Low Latency'; ArmSkuName = 'Standard_HB120-64rs_v3'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBrsv3 Series Low Latency'; ArmSkuName = 'Standard_HB120-96rs_v3'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBrsv3 Series Low Latency'; ArmSkuName = 'Standard_HB120rs_v3'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBSv2 Series Low Latency'; ArmSkuName = 'Standard_HB120-16rs_v2'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBSv2 Series Low Latency'; ArmSkuName = 'Standard_HB120-32rs_v2'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBSv2 Series Low Latency'; ArmSkuName = 'Standard_HB120-64rs_v2'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HBSv2 Series Low Latency'; ArmSkuName = 'Standard_HB120-96rs_v2'; Ratio = 120; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HCS Series'; ArmSkuName = 'Standard_HC44-16rs'; Ratio = 44; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HCS Series'; ArmSkuName = 'Standard_HC44-32rs'; Ratio = 44; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'HCS Series'; ArmSkuName = 'Standard_HC44rs'; Ratio = 44; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lasv3 Series DedicatedHost'; ArmSkuName = 'lasv3_type1'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lasv3 Series Linux'; ArmSkuName = 'Standard_L16as_v3'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lasv3 Series Linux'; ArmSkuName = 'Standard_L32as_v3'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lasv3 Series Linux'; ArmSkuName = 'Standard_L48as_v3'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lasv3 Series Linux'; ArmSkuName = 'Standard_L64as_v3'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lasv3 Series Linux'; ArmSkuName = 'Standard_L80as_v3'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lasv3 Series Linux'; ArmSkuName = 'Standard_L8as_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'LSv2 Series Dedicated Host'; ArmSkuName = 'lsv2_type1'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lsv3 Series DedicatedHost'; ArmSkuName = 'lsv3_type1'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lsv3 Series Linux'; ArmSkuName = 'Standard_L16s_v3'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lsv3 Series Linux'; ArmSkuName = 'Standard_L32s_v3'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lsv3 Series Linux'; ArmSkuName = 'Standard_L48s_v3'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lsv3 Series Linux'; ArmSkuName = 'Standard_L64s_v3'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lsv3 Series Linux'; ArmSkuName = 'Standard_L80s_v3'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Lsv3 Series Linux'; ArmSkuName = 'Standard_L8s_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MdSv2 Series 32 Disk'; ArmSkuName = 'Standard_M32dms_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MdSv2 Series 64 Disk'; ArmSkuName = 'Standard_M64ds_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Mdsv2 Series Dedicated Host'; ArmSkuName = 'mdsv2medmem_type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MdSv2 Series Disk'; ArmSkuName = 'Standard_M192idms_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MdSv2 Series Disk 192s'; ArmSkuName = 'Standard_M192ids_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MdSv2 Series Fractional High Memory Disk'; ArmSkuName = 'Standard_M128ds_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MdSv2 Series High Memory Disk'; ArmSkuName = 'Standard_M128dms_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Mdsv2 Series HM Dedicated Host'; ArmSkuName = 'mdmsv2medmem _type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MdSv2 Series Memory Disk'; ArmSkuName = 'Standard_M64dms_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series'; ArmSkuName = 'Standard_M128'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series'; ArmSkuName = 'Standard_M128s'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series'; ArmSkuName = 'Standard_M64'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series'; ArmSkuName = 'Standard_M64s'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Dedicated Host'; ArmSkuName = 'ms_type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M16-4ms'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M16-8ms'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M16ms'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M32-16ms'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M32-8ms'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M32ms'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M8-2ms'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M8-4ms'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional High Memory'; ArmSkuName = 'Standard_M8ms'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional Large'; ArmSkuName = 'Standard_M32ls'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional Large'; ArmSkuName = 'Standard_M64ls'; Ratio = 1.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series Fractional Tiny'; ArmSkuName = 'Standard_M32ts'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M128-32ms'; Ratio = 2.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M128-64ms'; Ratio = 2.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M128m'; Ratio = 2.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M128ms'; Ratio = 2.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M64-16ms'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M64-32ms'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M64m'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series High Memory'; ArmSkuName = 'Standard_M64ms'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MS Series HM Dedicated Host'; ArmSkuName = 'msm_type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series'; ArmSkuName = 'Standard_M208s_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series'; ArmSkuName = 'Standard_M416-208s_v2'; Ratio = 2.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series'; ArmSkuName = 'Standard_M416s_v2'; Ratio = 2.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series 192ms'; ArmSkuName = 'Standard_M192ims_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series 32'; ArmSkuName = 'Standard_M32ms_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series 64'; ArmSkuName = 'Standard_M64s_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series Dedicated Host'; ArmSkuName = 'msv2_type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series Disk 192s'; ArmSkuName = 'Standard_M192is_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series Fractional High Memory 128s'; ArmSkuName = 'Standard_M128s_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series High Memory'; ArmSkuName = 'Standard_M208ms_v2'; Ratio = 4.4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series High Memory'; ArmSkuName = 'Standard_M416-208ms_v2'; Ratio = 9.8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series High Memory'; ArmSkuName = 'Standard_M416ms_v2'; Ratio = 9.8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series High Memory'; ArmSkuName = 'Standard_M416s_10_v2'; Ratio = 8.16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series High Memory'; ArmSkuName = 'Standard_M416s_8_v2'; Ratio = 6.5; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series High Memory'; ArmSkuName = 'Standard_M416s_9_v2'; Ratio = 7.36; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series High Memory 128ms'; ArmSkuName = 'Standard_M128ms_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series HM Dedicated Host'; ArmSkuName = 'msmv2_type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series MedMem Dedicated Host'; ArmSkuName = 'msv2medmem type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series MedMem HM Dedicated Host'; ArmSkuName = 'mmsv2medmem-type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'MSv2 Series Memory'; ArmSkuName = 'Standard_M64ms_v2'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCads A100 v4 Series Linux'; ArmSkuName = 'Standard_NC24ads_A100_v4'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCads A100 v4 Series Linux'; ArmSkuName = 'Standard_NC48ads_A100_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCads A100 v4 Series Linux'; ArmSkuName = 'Standard_NC96ads_A100_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCas T4 v3 Series'; ArmSkuName = 'Standard_NC16as_T4_v3'; Ratio = 9.16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCas T4 v3 Series'; ArmSkuName = 'Standard_NC4as_T4_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCas T4 v3 Series'; ArmSkuName = 'Standard_NC64as_T4_v3'; Ratio = 33.08; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCas T4 v3 Series'; ArmSkuName = 'Standard_NC8as_T4_v3'; Ratio = 5.72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCasA10_v4 Linux'; ArmSkuName = 'Standard_NC16ads_A10_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCasA10_v4 Linux'; ArmSkuName = 'Standard_NC32ads_A10_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NCasA10_v4 Linux'; ArmSkuName = 'Standard_NC8ads_A10_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NDamsr A100 v4 Series'; ArmSkuName = 'ndamsra100v4_type1'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NDamsr A100 v4 Series Linux'; ArmSkuName = 'Standard_ND96amsr_A100_v4'; Ratio = 106.56; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NDasr A100 v4 Series'; ArmSkuName = 'ndasra100v4_type1'; Ratio = 105.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NDasr A100 v4 Series'; ArmSkuName = 'Standard_ND96asr_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NDrSv2 Series Low Latency'; ArmSkuName = 'Standard_ND40rs_v2'; Ratio = 40; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NP Series'; ArmSkuName = 'Standard_NP10s'; Ratio = 10; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NP Series'; ArmSkuName = 'Standard_NP20s'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NP Series'; ArmSkuName = 'Standard_NP40s'; Ratio = 40; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NVadsA10_v5 DedicatedHost'; ArmSkuName = 'nvadsa10v5_type1'; Ratio = 72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NVadsA10_v5 Linux'; ArmSkuName = 'Standard_NV12ads_A10_v5'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NVadsA10_v5 Linux'; ArmSkuName = 'Standard_NV18ads_A10_v5'; Ratio = 21.12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NVadsA10_v5 Linux'; ArmSkuName = 'Standard_NV36adms_A10_v5'; Ratio = 59.76; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NVadsA10_v5 Linux'; ArmSkuName = 'Standard_NV36ads_A10_v5'; Ratio = 42.3; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NVadsA10_v5 Linux'; ArmSkuName = 'Standard_NV6ads_A10_v5'; Ratio = 6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'NVadsA10_v5 Linux'; ArmSkuName = 'Standard_NV72ads_A10_v5'; Ratio = 86.16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D16ads_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D2ads_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D32ads_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D48ads_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D4ads_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D64ads_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D8ads_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv6-series Linux'; ArmSkuName = 'Standard_D96ads_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D128ads_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D160ads_v7'; Ratio = 160; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D16ads_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D2ads_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D32ads_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D48ads_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D4ads_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D64ads_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D8ads_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dadsv7-series Linux'; ArmSkuName = 'Standard_D96ads_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D16alds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D2alds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D32alds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D48alds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D4alds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D64alds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D8alds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv6-series Linux'; ArmSkuName = 'Standard_D96alds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D128alds_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D160alds_v7'; Ratio = 160; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D16alds_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D2alds_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D32alds_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D48alds_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D4alds_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D64alds_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D8alds_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Daldsv7-series Linux'; ArmSkuName = 'Standard_D96alds_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D16als_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D2als_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D32als_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D48als_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D4als_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D64als_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D8als_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv6-series Linux'; ArmSkuName = 'Standard_D96als_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D128als_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D160als_v7'; Ratio = 160; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D16als_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D2als_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D32als_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D48als_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D4als_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D64als_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D8als_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dalsv7-series Linux'; ArmSkuName = 'Standard_D96als_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series DedicatedHost'; ArmSkuName = 'dasv6_type1'; Ratio = 144; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D16as_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D2as_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D32as_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D48as_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D4as_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D64as_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D8as_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv6-series Linux'; ArmSkuName = 'Standard_D96as_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D128as_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D160as_v7'; Ratio = 160; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D16as_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D2as_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D32as_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D48as_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D4as_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D64as_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D8as_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dasv7-series Linux'; ArmSkuName = 'Standard_D96as_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC16ads_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC2ads_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC32ads_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC48ads_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC4ads_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC64ads_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC8ads_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCadsv6-series Linux'; ArmSkuName = 'Standard_DC96ads_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC16as_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC2as_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC32as_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC48as_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC4as_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC64as_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC8as_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCasv6-series Linux'; ArmSkuName = 'Standard_DC96as_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC128eds_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC16eds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC2eds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC32eds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC48eds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC4eds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC64eds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC8eds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCedsv6-series Linux'; ArmSkuName = 'Standard_DC96eds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC128es_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC16es_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC2es_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC32es_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC48es_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC4es_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC64es_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC8es_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines DCesv6-series Linux'; ArmSkuName = 'Standard_DC96es_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series DedicatedHost'; ArmSkuName = 'ddsv6_type1'; Ratio = 192; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D128ds_v6'; Ratio = 127.56; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D16ds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D192ds_v6'; Ratio = 191.36; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D2ds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D32ds_v6'; Ratio = 31.88; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D48ds_v6'; Ratio = 47.84; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D4ds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D64ds_v6'; Ratio = 63.8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D8ds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Ddsv6-series Linux'; ArmSkuName = 'Standard_D96ds_v6'; Ratio = 95.68; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D128lds_v6'; Ratio = 128.36; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D16lds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D2lds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D32lds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D48lds_v6'; Ratio = 48.14; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D4lds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D64lds_v6'; Ratio = 64.18; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D8lds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dldsv6-series Linux'; ArmSkuName = 'Standard_D96lds_v6'; Ratio = 96.28; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D128ls_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D16ls_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D2ls_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D32ls_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D48ls_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D4ls_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D64ls_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D8ls_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dlsv6-Series Linux'; ArmSkuName = 'Standard_D96ls_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D128nds_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D16nds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D2nds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D32nds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D48nds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D4nds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D64nds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D8nds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dndv6-series Linux'; ArmSkuName = 'Standard_D96nds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D128nlds_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D16nlds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D2nlds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D32nlds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D48nlds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D4nlds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D64nlds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D8nlds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnldv6-series Linux'; ArmSkuName = 'Standard_D96nlds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D128nls_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D16nls_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D2nls_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D32nls_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D48nls_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D4nls_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D64nls_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D8nls_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnlv6-series Linux'; ArmSkuName = 'Standard_D96nls_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D128ns_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D16ns_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D2ns_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D32ns_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D48ns_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D4ns_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D64ns_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D8ns_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dnv6-series Linux'; ArmSkuName = 'Standard_D96ns_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D16pds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D2pds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D32pds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D48pds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D4pds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D64pds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D8pds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpdsv6-series Linux'; ArmSkuName = 'Standard_D96pds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D16plds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D2plds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D32plds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D48plds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D4plds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D64plds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D8plds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpldsv6-series Linux'; ArmSkuName = 'Standard_D96plds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D16pls_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D2pls_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D32pls_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D48pls_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D4pls_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D64pls_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D8pls_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dplsv6-series Linux'; ArmSkuName = 'Standard_D96pls_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D16ps_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D2ps_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D32ps_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D48ps_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D4ps_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D64ps_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D8ps_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dpsv6-series Linux'; ArmSkuName = 'Standard_D96ps_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series DedicatedHost'; ArmSkuName = 'dsv6_type1'; Ratio = 192; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D128s_v6'; Ratio = 127.74; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D16s_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D192s_v6'; Ratio = 191.62; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D2s_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D32s_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D48s_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D4s_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D64s_v6'; Ratio = 63.88; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D8s_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Dsv6-series Linux'; ArmSkuName = 'Standard_D96s_v6'; Ratio = 95.8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E16ads_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E20ads_v6'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E2ads_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E32ads_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E48ads_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E4ads_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E64ads_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E8ads_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv6-series Linux'; ArmSkuName = 'Standard_E96ads_v6'; Ratio = 96.14; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E128-32ads_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E128-64ads_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E128ads_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E16-4ads_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E16-8ads_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E160ads_v7'; Ratio = 160; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E16ads_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E2ads_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E32-16ads_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E32-8ads_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E32ads_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E4-2ads_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E48ads_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E4ads_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E64-16ads_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E64-32ads_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E64ads_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E8-2ads_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E8-4ads_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E8ads_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E96-24ads_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E96-48ads_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Eadsv7-series Linux'; ArmSkuName = 'Standard_E96ads_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series DedicatedHost'; ArmSkuName = 'easv6_type1'; Ratio = 144; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E16as_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E20as_v6'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E2as_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E32as_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E48as_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E4as_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E64as_v6'; Ratio = 64.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E8as_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv6-series Linux'; ArmSkuName = 'Standard_E96as_v6'; Ratio = 96.16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E128-32as_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E128-64as_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E128as_v7'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E16-4as_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E16-8as_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E160as_v7'; Ratio = 160; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E16as_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E2as_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E32-16as_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E32-8as_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E32as_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E4-2as_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E48as_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E4as_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E64-16as_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E64-32as_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E64as_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E8-2as_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E8-4as_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E8as_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E96-24as_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E96-48as_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Easv7-series Linux'; ArmSkuName = 'Standard_E96as_v7'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC16ads_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC2ads_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC32ads_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC48ads_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC4ads_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC64ads_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC8ads_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECadsv6-series Linux'; ArmSkuName = 'Standard_EC96ads_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC16as_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC2as_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC32as_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC48as_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC4as_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC64as_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC8as_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECasv6-series Linux'; ArmSkuName = 'Standard_EC96as_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECedsv6-series Linux'; ArmSkuName = 'Standard_EC16eds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECedsv6-series Linux'; ArmSkuName = 'Standard_EC2eds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECedsv6-series Linux'; ArmSkuName = 'Standard_EC32eds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECedsv6-series Linux'; ArmSkuName = 'Standard_EC48eds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECedsv6-series Linux'; ArmSkuName = 'Standard_EC4eds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECedsv6-series Linux'; ArmSkuName = 'Standard_EC64eds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECedsv6-series Linux'; ArmSkuName = 'Standard_EC8eds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECesv6-series Linux'; ArmSkuName = 'Standard_EC16es_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECesv6-series Linux'; ArmSkuName = 'Standard_EC2es_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECesv6-series Linux'; ArmSkuName = 'Standard_EC32es_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECesv6-series Linux'; ArmSkuName = 'Standard_EC48es_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECesv6-series Linux'; ArmSkuName = 'Standard_EC4es_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECesv6-series Linux'; ArmSkuName = 'Standard_EC64es_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ECesv6-series Linux'; ArmSkuName = 'Standard_EC8es_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E128-32ds_v6'; Ratio = 127.62; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E128-64ds_v6'; Ratio = 127.62; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E128ds_v6'; Ratio = 127.62; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E16-4ds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E16-8ds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E16ds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E192ids_v6'; Ratio = 210.58; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E20ds_v6'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E2ds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E32-16ds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E32-8ds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E32ds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E4-2ds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E48ds_v6'; Ratio = 47.86; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E4ds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E64-16ds_v6'; Ratio = 63.82; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E64-32ds_v6'; Ratio = 63.82; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E64ds_v6'; Ratio = 63.82; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E8-2ds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E8-4ds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E8ds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E96-24ds_v6'; Ratio = 95.72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E96-48ds_v6'; Ratio = 95.72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Edsv6-series Linux'; ArmSkuName = 'Standard_E96ds_v6'; Ratio = 95.72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E128nds_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E16nds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E2nds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E32nds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E48nds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E4nds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E64nds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E8nds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Endv6-series Linux'; ArmSkuName = 'Standard_E96nds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E128ns_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E16ns_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E2ns_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E32ns_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E48ns_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E4ns_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E64ns_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E8ns_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Env6-series Linux'; ArmSkuName = 'Standard_E96ns_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E16pds_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E2pds_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E32pds_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E48pds_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E4pds_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E64pds_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E8pds_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epdsv6-series Linux'; ArmSkuName = 'Standard_E96pds_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E16ps_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E2ps_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E32ps_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E48ps_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E4ps_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E64ps_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E8ps_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Epsv6-series Linux'; ArmSkuName = 'Standard_E96ps_v6'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series DedicatedHost'; ArmSkuName = 'esv6_type1'; Ratio = 192; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E128-32s_v6'; Ratio = 128.28; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E128-64s_v6'; Ratio = 128.28; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E128s_v6'; Ratio = 128.28; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E16-4s_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E16-8s_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E16s_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E192is_v6'; Ratio = 211.68; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E20s_v6'; Ratio = 20; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E2s_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E32-16s_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E32-8s_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E32s_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E4-2s_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E48s_v6'; Ratio = 48.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E4s_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E64-16s_v6'; Ratio = 64.16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E64-32s_v6'; Ratio = 64.16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E64s_v6'; Ratio = 64.16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E8-2s_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E8-4s_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E8s_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E96-24s_v6'; Ratio = 96.22; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E96-48s_v6'; Ratio = 96.22; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Esv6-series Linux'; ArmSkuName = 'Standard_E96s_v6'; Ratio = 96.22; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F16ads_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F1ads_v7'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F2ads_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F32ads_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F48ads_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F4ads_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F64ads_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F80ads_v7'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fadsv7-series Linux'; ArmSkuName = 'Standard_F8ads_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F16alds_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F1alds_v7'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F2alds_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F32alds_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F48alds_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F4alds_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F64alds_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F80alds_v7'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Faldsv7-series Linux'; ArmSkuName = 'Standard_F8alds_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv6-series Linux'; ArmSkuName = 'Standard_F16als_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv6-series Linux'; ArmSkuName = 'Standard_F2als_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv6-series Linux'; ArmSkuName = 'Standard_F32als_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv6-series Linux'; ArmSkuName = 'Standard_F48als_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv6-series Linux'; ArmSkuName = 'Standard_F4als_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv6-series Linux'; ArmSkuName = 'Standard_F64als_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv6-series Linux'; ArmSkuName = 'Standard_F8als_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F16als_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F1als_v7'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F2als_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F32als_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F48als_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F4als_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F64als_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F80als_v7'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Falsv7-series Linux'; ArmSkuName = 'Standard_F8als_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F16-4amds_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F16-8amds_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F16amds_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F1amds_v7'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F2-1amds_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F2amds_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F32-16amds_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F32-8amds_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F32amds_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F4-1amds_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F4-2amds_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F48amds_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F4amds_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F64-16amds_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F64-32amds_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F64amds_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F8-2amds_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F8-4amds_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F80amds_v7'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famdsv7-series Linux'; ArmSkuName = 'Standard_F8amds_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv6-series Linux'; ArmSkuName = 'Standard_F16ams_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv6-series Linux'; ArmSkuName = 'Standard_F2ams_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv6-series Linux'; ArmSkuName = 'Standard_F32ams_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv6-series Linux'; ArmSkuName = 'Standard_F48ams_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv6-series Linux'; ArmSkuName = 'Standard_F4ams_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv6-series Linux'; ArmSkuName = 'Standard_F64ams_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv6-series Linux'; ArmSkuName = 'Standard_F8ams_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F16-4ams_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F16-8ams_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F16ams_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F1ams_v7'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F2-1ams_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F2ams_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F32-16ams_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F32-8ams_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F32ams_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F4-1ams_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F4-2ams_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F48ams_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F4ams_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F64-16ams_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F64-32ams_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F64ams_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F8-2ams_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F8-4ams_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F80ams_v7'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Famsv7-series Linux'; ArmSkuName = 'Standard_F8ams_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv6-series Linux'; ArmSkuName = 'Standard_F16as_v6'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv6-series Linux'; ArmSkuName = 'Standard_F2as_v6'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv6-series Linux'; ArmSkuName = 'Standard_F32as_v6'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv6-series Linux'; ArmSkuName = 'Standard_F48as_v6'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv6-series Linux'; ArmSkuName = 'Standard_F4as_v6'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv6-series Linux'; ArmSkuName = 'Standard_F64as_v6'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv6-series Linux'; ArmSkuName = 'Standard_F8as_v6'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F16as_v7'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F1as_v7'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F2as_v7'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F32as_v7'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F48as_v7'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F4as_v7'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F64as_v7'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F80as_v7'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Fasv7-series Linux'; ArmSkuName = 'Standard_F8as_v7'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX12-6mds_v2'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX12mds_v2'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX16-4mds_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX16-8mds_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX16mds_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX24-12mds_v2'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX24-6mds_v2'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX24mds_v2'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX2mds_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX32-16mds_v2'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX32-8mds_v2'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX32mds_v2'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX4-2mds_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX48-12mds_v2'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX48-24mds_v2'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX48mds_v2'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX4mds_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX64-16mds_v2'; Ratio = 63.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX64-32mds_v2'; Ratio = 63.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX64mds_v2'; Ratio = 63.9; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX8-2mds_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX8-4mds_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX8mds_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX96-24mds_v2'; Ratio = 95.84; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX96-48mds_v2'; Ratio = 95.84; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmdsv2-series Linux'; ArmSkuName = 'Standard_FX96mds_v2'; Ratio = 95.84; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX12-6ms_v2'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX12ms_v2'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX16-4ms_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX16-8ms_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX16ms_v2'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX24-12ms_v2'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX24-6ms_v2'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX24ms_v2'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX2ms_v2'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX32-16ms_v2'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX32-8ms_v2'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX32ms_v2'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX4-2ms_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX48-12ms_v2'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX48-24ms_v2'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX48ms_v2'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX4ms_v2'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX64-16ms_v2'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX64-32ms_v2'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX64ms_v2'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX8-2ms_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX8-4ms_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX8ms_v2'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX96-24ms_v2'; Ratio = 96.14; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX96-48ms_v2'; Ratio = 96.14; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines FXmsv2-series Linux'; ArmSkuName = 'Standard_FX96ms_v2'; Ratio = 96.14; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv4-series Linux'; ArmSkuName = 'Standard_HB176-144rs_v4'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv4-series Linux'; ArmSkuName = 'Standard_HB176-24rs_v4'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv4-series Linux'; ArmSkuName = 'Standard_HB176-48rs_v4'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv4-series Linux'; ArmSkuName = 'Standard_HB176-96rs_v4'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv4-series Linux'; ArmSkuName = 'Standard_HB176rs_v4'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368-144rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368-192rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368-240rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368-288rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368-336rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368-48rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368-96rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HBrsv5 Linux'; ArmSkuName = 'Standard_HB368rs_v5'; Ratio = 368; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HXrs Linux'; ArmSkuName = 'Standard_HX176-144rs'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HXrs Linux'; ArmSkuName = 'Standard_HX176-24rs'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HXrs Linux'; ArmSkuName = 'Standard_HX176-48rs'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HXrs Linux'; ArmSkuName = 'Standard_HX176-96rs'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines HXrs Linux'; ArmSkuName = 'Standard_HX176rs'; Ratio = 176; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Laosv4-series Linux'; ArmSkuName = 'Standard_L12aos_v4'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Laosv4-series Linux'; ArmSkuName = 'Standard_L16aos_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Laosv4-series Linux'; ArmSkuName = 'Standard_L24aos_v4'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Laosv4-series Linux'; ArmSkuName = 'Standard_L2aos_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Laosv4-series Linux'; ArmSkuName = 'Standard_L32aos_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Laosv4-series Linux'; ArmSkuName = 'Standard_L4aos_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Laosv4-series Linux'; ArmSkuName = 'Standard_L8aos_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L16as_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L2as_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L32as_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L48as_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L4as_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L64as_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L80as_v4'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L8as_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lasv4 Series Linux'; ArmSkuName = 'Standard_L96as_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L16s_v4'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L2s_v4'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L32s_v4'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L48s_v4'; Ratio = 48; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L4s_v4'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L64s_v4'; Ratio = 64; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L80s_v4'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L8s_v4'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Lsv4 Series Linux'; ArmSkuName = 'Standard_L96s_v4'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M128-64bds_3_v3'; Ratio = 31.5; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M128-64bds_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M128bds_3_v3'; Ratio = 31.5; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M128bds_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M16bds_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176-88bds_4_v3'; Ratio = 43; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176-88bds_v3'; Ratio = 11; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176bds_4_v3'; Ratio = 43; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176bds_v3'; Ratio = 11; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M32bds_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M48bds_v3'; Ratio = 3; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M64-32bds_1_v3'; Ratio = 15.7; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M64bds_1_v3'; Ratio = 15.7; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M64bds_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96-48bds_2_v3'; Ratio = 23.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96bds_2_v3'; Ratio = 23.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96bds_v3'; Ratio = 6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M128-64bs_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M128bs_v3'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M16bs_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176-88bs_v3'; Ratio = 11; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176bs_v3'; Ratio = 11; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M32bs_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M416bs_v3'; Ratio = 34.4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M48bs_v3'; Ratio = 3; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M64bs_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mbsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96bs_v3'; Ratio = 6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416ds_10_v3'; Ratio = 416; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416ds_12_v3'; Ratio = 416; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416ds_6_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416ds_8_v3'; Ratio = 1.33; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416ds_9_v3'; Ratio = 416; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M624ds_12_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M832ds_12_v3'; Ratio = 2.01; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 High Memory Series Linux'; ArmSkuName = 'Standard_M832ids_16_v3'; Ratio = 2.96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series DedicatedHost'; ArmSkuName = 'mdsv3medmem_type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M12ds_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176ds_3_v3'; Ratio = 11.7; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176ds_4_v3'; Ratio = 16.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M24ds_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M48ds_1_v3'; Ratio = 4.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96ds_1_v3'; Ratio = 6.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Mdsv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96ds_2_v3'; Ratio = 8.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416s_10_v3'; Ratio = 416; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416s_12_v3'; Ratio = 416; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416s_6_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416s_8_v3'; Ratio = 1.33; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M416s_9_v3'; Ratio = 416; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M624s_12_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M832is_16_v3'; Ratio = 2.96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 High Memory Series Linux'; ArmSkuName = 'Standard_M832s_12_v3'; Ratio = 2.01; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series DedicatedHost'; ArmSkuName = 'msv3medmem_type1'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M12s_v3'; Ratio = 1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176s_3_v3'; Ratio = 11.6; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M176s_4_v3'; Ratio = 16.2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M24s_v3'; Ratio = 2; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M48s_1_v3'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96s_1_v3'; Ratio = 6.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines Msv3 Medium Memory Series Linux'; ArmSkuName = 'Standard_M96s_2_v3'; Ratio = 8.1; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCadsH100_v5-series Linux'; ArmSkuName = 'Standard_NC40ads_H100_v5'; Ratio = 40; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCadsH100_v5-series Linux'; ArmSkuName = 'Standard_NC80adis_H100_v5'; Ratio = 80; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCCadsH100_v5_series Linux'; ArmSkuName = 'Standard_NCC40ads_H100_v5'; Ratio = 40; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCdsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC144ds_xl_RTXPRO6000BSE_v6'; Ratio = 144; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCdsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC288ds_xl_RTXPRO6000BSE_v6'; Ratio = 288; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCdsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC36ds_xl_RTXPRO6000BSE_v6'; Ratio = 36; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCdsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC72ds_xl_RTXPRO6000BSE_v6'; Ratio = 72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCldsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC144lds_xl_RTXPRO6000BSE_v6'; Ratio = 144; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCldsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC24lds_xl_RTXPRO6000BSE_v6'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCldsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC288lds_xl_RTXPRO6000BSE_v6'; Ratio = 288; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCldsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC36lds_xl_RTXPRO6000BSE_v6'; Ratio = 36; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NCldsxlRTX6kv6 Linux'; ArmSkuName = 'Standard_NC72lds_xl_RTXPRO6000BSE_v6'; Ratio = 72; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ND MI300X v5 Series Linux'; ArmSkuName = 'Standard_ND96is_MI300X_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines ND MI300X v5 Series Linux'; ArmSkuName = 'Standard_ND96isr_MI300X_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NDsr GB200 NDR v6 Series Linux'; ArmSkuName = 'Standard_ND128isr_NDR_GB200_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NDsr GB300 v6-Series Linux'; ArmSkuName = 'Standard_ND128isr_GB300_v6'; Ratio = 128; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NDsr H100 v5-Series Linux'; ArmSkuName = 'Standard_ND96isr_H100_v5'; Ratio = 106.56; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NDsr H200 v5 Series Linux'; ArmSkuName = 'Standard_ND96isr_H200_v5'; Ratio = 96; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NGads_V620_v1  Linux'; ArmSkuName = 'Standard_NG16ads_V620_v1'; Ratio = 16; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NGads_V620_v1  Linux'; ArmSkuName = 'Standard_NG32ads_V620_v1'; Ratio = 32; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NGads_V620_v1  Linux'; ArmSkuName = 'Standard_NG8ads_V620_v1'; Ratio = 8; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NVads_V710_v5 Linux'; ArmSkuName = 'Standard_NV12ads_V710_v5'; Ratio = 12; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NVads_V710_v5 Linux'; ArmSkuName = 'Standard_NV24ads_V710_v5'; Ratio = 24; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NVads_V710_v5 Linux'; ArmSkuName = 'Standard_NV4ads_V710_v5'; Ratio = 4; }
        ,[PSCustomObject]@{ InstanceSizeFlexibilityGroup = 'Virtual Machines NVads_V710_v5 Linux'; ArmSkuName = 'Standard_NV8ads_V710_v5'; Ratio = 8; }
    )
}
