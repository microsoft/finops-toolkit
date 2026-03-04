(input) =>
let
    // Mapping of old names to new names
    // TODO: Needed? -- _pickSchema = (ea, interim, focus05, focus10) => if _targetSchema = 0 then interim else if _targetSchema = 0.5 then focus05 else if _targetSchema = 1.0 then focus10 else ea,
    _originalColumns = Table.ColumnNames(input),
    _nameChanges = [
        // Passthrough
        AccountName                  = "x_AccountName",
        AccountOwnerId               = "x_AccountOwnerId",
        AdditionalInfo               = "x_SkuDetails",
        AmortizedCost                = "EffectiveCost",
        AmortizedCostInUsd           = "x_EffectiveCostInUsd",
        AmortizedPricingCost         = "x_EffectivePricingCost",
        BilledCost                   = "BilledCost",
        BilledCostInUsd              = "x_BilledCostInUsd",
        BilledPricingCost            = "x_BilledPricingCost",
        BillingAccountId             = "x_BillingAccountId",
        BillingAccountName           = "x_BillingAccountName",
        BillingCurrency              = "BillingCurrency",
        BillingCurrencyCode          = "BillingCurrency",
        BillingProfileId             = "x_BillingProfileId",
        BillingProfileName           = "x_BillingProfileName",
        ConsumedService              = "x_ConsumedService",
        CostAllocationRuleName       = "x_CostAllocationRuleName",
        CostCenter                   = "x_CostCenter",
        Currency                     = "BillingCurrency",
        CustomerName                 = "x_CustomerName",
        CustomerTenantId             = "x_CustomerId",
        DataSet                      = "x_DataSet",
        Date                         = "ChargePeriodStart",
        DepartmentName               = "x_InvoiceSectionName",
        EffectivePrice               = "x_EffectiveUnitPrice",
        InvoiceId                    = "x_InvoiceId",
        InvoiceSection               = "x_InvoiceSectionName",
        InvoiceSectionId             = "x_InvoiceSectionId",
        InvoiceSectionName           = "x_InvoiceSectionName",
        IsAzureCreditEligible        = "x_IsCreditEligible",
        MeterCategory                = "x_SkuMeterCategory",
        MeterId                      = "x_SkuMeterId",
        MeterName                    = "x_SkuMeterName",
        MeterRegion                  = "x_SkuRegion",
        MeterSubCategory             = "x_SkuMeterSubcategory",
        OfferId                      = "x_SkuOfferId",
        PartnerEarnedCreditApplied   = "x_PartnerCreditApplied",
        PartnerEarnedCreditRate      = "x_PartnerCreditRate",
        PartnerName                  = "tmp_InvoiceIssuerName",
        PartnerTenantId              = "x_InvoiceIssuerId",
        PartNumber                   = "x_SkuPartNumber",
        PlanName                     = "x_SkuPlanName",
        PreviousInvoiceId            = "x_PreviousInvoiceId",
        Product                      = "x_SkuDescription",
        ProductCategory              = "x_SkuServiceFamily",
        ProductName                  = "x_SkuDescription",
        ProductId                    = "SkuId",
        ProductOrderId               = "x_SkuOrderId",
        ProductOrderName             = "x_SkuOrderName",
        Provider                     = "x_SkuProvider",
        PublisherId                  = "x_PublisherId",
        PublisherType                = "x_PublisherType",
        Quantity                     = "ConsumedQuantity",
        ResellerMpnId                = "x_ResellerId",
        ResellerName                 = "x_ResellerName",
        ResourceGroup                = "x_ResourceGroupName",
        ResourceGroupName            = "x_ResourceGroupName",
        ResourceId                   = "ResourceId",
        ResourceType                 = "ResourceType",
        ServiceFamily                = "x_SkuServiceFamily",
        ServicePeriodEndDate         = "x_ServicePeriodEnd",
        ServicePeriodStartDate       = "x_ServicePeriodStart",
        SubscriptionGuid             = "x_SubscriptionId",
        SubscriptionId               = "x_SubscriptionId",
        SubscriptionName             = "x_SubscriptionName",
        Tags2                        = "Tags2", // TODO: Confirm whether this ever has a value for MCA; seems to be a bug in the connector or UsageDetails API
        Term                         = "tmp_SkuTerm",
        UnitOfMeasure                = "x_PricingUnitDescription",
        UsageDateTime                = "ChargePeriodStart",
        UsageQuantity                = "ConsumedQuantity",
        // Require cleanup
        BenefitId                    = "tmp_CommitmentDiscountId",
        BenefitName                  = "tmp_CommitmentDiscountName",
        BillingPeriodEndDate         = "tmp_BillingPeriodEnd",
        BillingPeriodStartDate       = "tmp_BillingPeriodStart",
        ChargeType                   = "tmp_ChargeType",
        ExchangeRate                 = "tmp_ExchangeRate",
        ExchangeRateDate             = "tmp_ExchangeRateDate",
        ExchangeRatePricingToBilling = "tmp_ExchangeRate",
        Frequency                    = "tmp_Frequency",
        PaygCostInBillingCurrency    = "tmp_ListCost",
        PaygCostInUsd                = "tmp_ListCostInUsd",
        PayGPrice                    = "tmp_ListUnitPrice",
        PricingCurrency              = "tmp_PricingCurrency",
        PricingModel                 = "tmp_PricingModel",
        PublisherName                = "tmp_PublisherName",
        ReservationId                = "tmp_ReservationId",
        ReservationName              = "tmp_ReservationName",
        ResourceLocation             = "tmp_ResourceLocation",
        ResourceName                 = "tmp_ResourceName",
        ResourceRate                 = "tmp_ContractedUnitPrice",
        ServiceName                  = "tmp_ServiceName",
        Tags                         = "tmp_Tags",
        UnitPrice                    = "tmp_ContractedUnitPrice",
        // Columns to remove
        AvailabilityZone             = "__DELETE_AvailabilityZone",
        Location                     = "__DELETE_Location",
        ResourceLocationNormalized   = "__DELETE_ResourceLocationNormalized",
        ServiceInfo1                 = "__DELETE_ServiceInfo1",
        ServiceInfo2                 = "__DELETE_ServiceInfo2"
    ],
    _unrecognizedColumns = List.Transform(_originalColumns, each Record.FieldOrDefault(_nameChanges, _, "__NEW_" & _)),
    RenameColumns = Table.RenameColumns(input, List.Zip({_originalColumns, _unrecognizedColumns})),

    // Add missing columns + remove unecessary ones
    BackfillAndTrim = Table.SelectColumns(
        RenameColumns,
        List.Sort(List.Distinct(List.Select(List.Union({
            Record.FieldValues(_nameChanges),
            Table.ColumnNames(RenameColumns)
        }), each Text.StartsWith(_, "__DELETE_") = false))),
        MissingField.UseNull
    ),

    // Fix types
    FixTypes = Table.TransformColumnTypes(BackfillAndTrim, {
        // Date columns
        // TODO: Should these be datetimezone?
        {"tmp_BillingPeriodStart", type date},
        {"tmp_BillingPeriodEnd",   type date},
        {"ChargePeriodStart",      type date},
        {"x_ServicePeriodStart",   type date},
        {"x_ServicePeriodEnd",     type date},
        {"tmp_ExchangeRateDate",   type date},
        // Price columns
        {"x_EffectiveUnitPrice",   type number},
        {"tmp_ListUnitPrice",      type number},
        {"tmp_ContractedUnitPrice", type number},
        // Cost columns
        // {"BilledCost",                type number},
        // {"ContractedCost",            type number},
        // {"EffectiveCost",             type number},
        {"x_EffectiveCostInUsd",   type number},
        {"x_EffectivePricingCost", type number},
        {"x_BilledCostInUsd",      type number},
        {"x_BilledPricingCost",    type number},
        {"tmp_ListCost",           type number},
        {"tmp_ListCostInUsd",      type number},
        // Other columns
        {"x_PartnerCreditRate",    type number},
        {"ConsumedQuantity",       type number},
        {"tmp_ExchangeRate",       type number}
        // {"PricingQuantity",           type number},
        // {"x_BillingExchangeRate",     type number},
        // {"x_PricingBlockSize",        type number},
        // {"x_SkuTerm",              type text}  // Text due to a bug in CM data; converted to a number below
        // {"x_SkuIsCreditEligible", type logical}
        // {"x_PartnerCreditApplied",   type logical}
    }),

    // Helper functions
    _exists        = (col) => Table.HasColumns(RenameColumns, col),
    _isMissing     = (col) => _exists(col) = false,
    _isBlank       = (val) => val = null or val = "",
    _isNotBlank    = (val) => _isBlank(val) = false,
    _isPositive    = (val) => val <> null and val > 0,
    _isNotPositive = (val) => val = null or val <= 0,
    _swapCol       = (tbl, oldCol, newCol, newVal, optional newType) => let add = Table.AddColumn(tbl, newCol, newVal, newType), del = if Table.HasColumns(add, oldCol) then Table.RemoveColumns(add, {oldCol}) else add in del,

    // Transform metadata
// TODO: Add more thorough schema/account validation + use real API versions
    Schema =  Table.AddColumn(FixTypes, "x_SchemaVersion",
        each if Table.HasColumns(input, "DepartmentName")   then "MG_2023-09"
        else if Table.HasColumns(input, "SubscriptionGuid") then "MOSA_2023-09"
        else if _isNotBlank([x_InvoiceIssuerId]) or [tmp_InvoiceIssuerName] <> "Microsoft" then "MPA_2023-09"
        else if [x_BillingAccountId] <> [x_BillingProfileId] then "MCA_2023-09"
        else if [x_BillingAccountId] = [x_BillingProfileId] then "EA_2023-09"
        else "Unknown_2023-09"
    ),
    AccountType = Table.AddColumn(Schema, "x_AccountType", each Text.Split([x_SchemaVersion], "_"){0}),

    // Region cleanup
    _regionCleanup = (loc) => Text.Trim(
        Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(
        Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(
        Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(
        Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(
        Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(Text.Replace(
        Text.Lower(
            try
                if Number.FromText(Text.At(loc, Text.Length(loc) - 1)) <> null then
                    Text.Range(loc, 0, Text.Length(loc) - 1) & " " & Text.At(loc, Text.Length(loc) - 1) & " "
                else
                    loc
            otherwise loc
        ),
        "central",     " Central "),
        "north",       " North "),
        "northeast",   " Northeast "),
        "northwest",   " Northwest "),
        "south",       " South "),
        "southeast",   " Southeast "),
        "southwest",   " Southwest "),
        "east",        " East "),
        "west",        " West "),
        "2euap",       " 2 EUAP "),
        "africa",      " Africa "),
        "arizona",     " Arizona "),
        "asia",        " Asia "),
        "australia",   " Australia "),
        "austria",     " Austria "),
        "belgium",     " Belgium "),
        "brazil",      " Brazil "),
        "canada",      " Canada "),
        "chile",       " Chile "),
        "china",       " China "),
        "denmark",     " Denmark "),
        "europe",      " Europe "),
        "finland",     " Finland "),
        "france",      " France "),
        "germany",     " Germany "),
        "greece",      " Greece "),
        "india",       " India "),
        "indonesia",   " Indonesia "),
        "israel",      " Israel "),
        "italy",       " Italy "),
        "japan",       " Japan "),
        "korea",       " Korea "),
        "malaysia",    " Malaysia "),
        "mexico",      " Mexico "),
        "newzealand",  " New Zealand "),
        "norway",      " Norway "),
        "poland",      " Poland "),
        "qatar",       " Qatar "),
        "saudiarabia", " Saudi Arabia "),
        "spain",       " Sweeden "),
        "sweden",      " Sweden "),
        "switzerland", " Switzerland "),
        "taiwan",      " Taiwan "),
        "texas",       " Texas "),
        "uae",         " UAE "),
        "uk",          " UK "),
        "usdod",       " US DoD "),
        "usgov",       " US Gov "),
        "ussec",       " US Sec "),
        "us",          " US "),
        "virginia",    " Virginia "),
        " US  South ", " South US "),
        " US  West ",  " West US "),
        "  ",  " ")
    ),

    tmp_DefenderFor            = Table.AddColumn(AccountType,            "tmp_DefenderFor",        each if Text.StartsWith([x_SkuDescription], "Microsoft Defender for") then Text.Range([x_SkuDescription], 23, Text.PositionOf([x_SkuDescription], "-") - 24) else null),
    tmp_RPName                 = Table.AddColumn(tmp_DefenderFor,        "tmp_RPName",             each Text.Replace(Text.Replace(Text.Lower([x_ConsumedService]), "microsoft.classic", ""), "microsoft.", "")),

    // Parse AddlInfo
    SkuDetailsDict             = Table.AddColumn(tmp_RPName,             "x_SkuDetailsDictionary", each if _isNotBlank([x_SkuDetails]) then Json.Document([x_SkuDetails]) else null),
    SkuDetailsDict_errors      = Table.ReplaceErrorValues(SkuDetailsDict, {{"x_SkuDetailsDictionary", null}}),
    SkuDetailsDict_expand      = Table.ExpandRecordColumn(SkuDetailsDict_errors, "x_SkuDetailsDictionary",
        {"UsageType",      "ImageType",      "ServiceType", "VMName",     "VMProperties",      "VCPUs",       "ReservationOrderId",         "ReservationId",         "VMCapacityReservationId", "AHB",        "vCores"},
        {"x_SkuUsageType", "x_SkuImageType", "x_SkuType",   "tmp_VMName", "x_SkuVMProperties", "tmp_VMvCPUs", "tmp_AddlReservationOrderId", "tmp_AddlReservationId", "x_CapacityCommitmentId",  "tmp_SQLAHB", "tmp_SQLvCores"}
    ),
    SkuDetailsDict_types       = Table.TransformColumnTypes(SkuDetailsDict_expand, {{"tmp_VMvCPUs", Int64.Type}, {"tmp_SQLvCores", Int64.Type}}),

    // Columns from AddlInfo -- Must be after ResourceName cleanup
    ResourceMachineName = _swapCol(SkuDetailsDict_types,       "tmp_VMName",         "x_ResourceMachineName", each if _isNotBlank([tmp_VMName]) then [tmp_VMName] else null),
    ProductCPUs         = Table.AddColumn(ResourceMachineName, "x_SkuCPUs",          each if [tmp_VMvCPUs] <> null then [tmp_VMvCPUs] else if [tmp_SQLvCores] <> null then [tmp_SQLvCores] else null, Int64.Type),
    CPUHours            = Table.AddColumn(ProductCPUs,         "x_UsageCPUHours",    each if [x_SkuCPUs] <> null then [x_SkuCPUs] * [ConsumedQuantity] else null, type number),
    HybridBenefitStatus = Table.AddColumn(CPUHours,            "x_SkuLicenseStatus", each if _isNotBlank([x_SkuMeterSubcategory]) and Text.Contains([x_SkuMeterSubcategory], "Windows") or [tmp_SQLAHB] = "False" then "Not enabled" else if (_isNotBlank([x_SkuImageType]) and Text.Contains([x_SkuImageType], "Windows Server BYOL")) or [tmp_SQLAHB] = "True" or (_isNotBlank([x_SkuMeterSubcategory]) and Text.Contains([x_SkuMeterSubcategory], "Azure Hybrid Benefit")) then "Enabled" else "Not supported"),
    HybridBenefitCPUs   = Table.AddColumn(HybridBenefitStatus, "x_SkuLicenseCPUs",   each if [x_SkuCPUs] = null then 0 else if [x_SkuCPUs] <= 8 then 8 else if [x_SkuCPUs] <= 16 then 16 else if [x_SkuCPUs] = 20 then 24 else if [x_SkuCPUs] > 20 then [x_SkuCPUs] else 0, type number),
// TODO: Add SQL AHB handling
    AHB = HybridBenefitCPUs,

    // Transform commitment columns before others due to bug making PricingModel empty
    CommitmentDiscountId       = _swapCol(AHB,                           "tmp_CommitmentDiscountId",   "CommitmentDiscountId",   each if _isNotBlank([tmp_CommitmentDiscountId])   then [tmp_CommitmentDiscountId]   else if _isNotBlank([tmp_ReservationId])   then (if _isMissing("tmp_AddlReservationId") or [tmp_ReservationId] <> [tmp_AddlReservationId] then [tmp_ReservationId] else "/providers/Microsoft.Capacity/reservationOrders/" & [tmp_AddlReservationOrderId] & "/reservations/" & [tmp_AddlReservationId]) else null),
    CommitmentDiscountName     = _swapCol(CommitmentDiscountId,          "tmp_CommitmentDiscountName", "CommitmentDiscountName", each if _isNotBlank([tmp_CommitmentDiscountName]) then [tmp_CommitmentDiscountName] else if _isNotBlank([tmp_ReservationName]) then [tmp_ReservationName] else null),
    _isReservation = (ct, pm, cdi, ri) => pm = "Reservation" or ct = "UnusedReservation" or _isNotBlank(ri) or (_isNotBlank(cdi) and Text.Contains(Text.Lower(cdi), "/microsoft.capacity/")),
    _isSavingsPlan = (ct, pm, cdi) => pm = "SavingsPlan" or ct = "UnusedSavingsPlan" or (_isNotBlank(cdi) and Text.Contains(Text.Lower(cdi), "/microsoft.billingbenefits/")),
    _isCommitmentDiscount = (ct, pm, cdi, ri) => _isReservation(ct, pm, cdi, ri) or _isSavingsPlan(ct, pm, cdi),
    CommitmentDiscountType     = Table.AddColumn(CommitmentDiscountName, "CommitmentDiscountType",     each 
        if _isReservation([tmp_ChargeType], [tmp_PricingModel], [CommitmentDiscountId], [tmp_ReservationId]) then "Reservation" 
        else if _isSavingsPlan([tmp_ChargeType], [tmp_PricingModel], [CommitmentDiscountId]) then "Savings Plan" else null
    ),
    CommitmentDiscountCategory = Table.AddColumn(CommitmentDiscountType,     "CommitmentDiscountCategory", each if [CommitmentDiscountType] = "Reservation" then "Usage" else if [CommitmentDiscountType] = "Savings Plan" then "Spend" else null),
    CommitmentDiscountStatus   = Table.AddColumn(CommitmentDiscountCategory, "CommitmentDiscountStatus",   each if [CommitmentDiscountCategory] = null then null else if Text.StartsWith([tmp_ChargeType], "Unused") then "Unused" else "Used"),

    // Transform placeholder columns
    BillingAccountId           = Table.AddColumn(CommitmentDiscountStatus,   "BillingAccountId",   each if [x_AccountType] = "MCA" then [x_BillingProfileId]   else if [x_AccountType] = "EA" then [x_BillingAccountId]   else [x_SubscriptionId]),
    BillingAccountName         = Table.AddColumn(BillingAccountId,           "BillingAccountName", each if [x_AccountType] = "MCA" then [x_BillingProfileName] else if [x_AccountType] = "EA" then [x_BillingAccountName] else [x_SubscriptionName]),
    BillingAccountType         = Table.AddColumn(BillingAccountName,         "BillingAccountType", each if [x_AccountType] = "MCA" then "Billing Profile" else if [x_AccountType] = "EA" then "Billing Account" else "Subscription"),
    BillingPeriodEnd           = _swapCol(BillingAccountType,                "tmp_BillingPeriodEnd",   "BillingPeriodEnd",          each if _isMissing("tmp_BillingPeriodEnd") then Date.StartOfMonth(Date.AddDays([ChargePeriodStart], 31)) else Date.AddDays([tmp_BillingPeriodEnd], 1), type date),
    BillingPeriodStart         = _swapCol(BillingPeriodEnd,                  "tmp_BillingPeriodStart", "BillingPeriodStart",        each if _isBlank([tmp_BillingPeriodStart]) then Date.StartOfMonth([ChargePeriodStart]) else [tmp_BillingPeriodStart], type date),
    CapacityReservationId      = Table.AddColumn(BillingPeriodStart,         "CapacityReservationId",  each if _isNotBlank([x_CapacityCommitmentId]) then [x_CapacityCommitmentId] else null),
    CapacityReservationStatus  = Table.AddColumn(CapacityReservationId,      "CapacityReservationStatus", each if _isBlank([CapacityReservationId]) then null else if _isNotBlank([x_ResourceType]) and Text.Lower([x_ResourceType]) = "microsoft.compute/capacityreservationgroups/capacityreservations" then "Unused" else "Used"),
    ChargeCategory             = Table.AddColumn(CapacityReservationStatus,  "ChargeCategory",     each if _isBlank([tmp_ChargeType]) then "Usage" else if [tmp_ChargeType] = "Usage" or [tmp_ChargeType] = "Purchase" or [tmp_ChargeType] = "Tax" then [tmp_ChargeType] else if Text.StartsWith([tmp_ChargeType], "Unused") then "Usage" else if [tmp_ChargeType] = "Refund" then "Purchase" else "Adjustment"),
    ChargeClass                = Table.AddColumn(ChargeCategory,             "ChargeClass",        each if [tmp_ChargeType] = "Refund" then "Correction" else null),
    ChargeDescription          = Table.AddColumn(ChargeClass,                "ChargeDescription",  each [x_SkuDescription]),
// TODO: PricingQuantity,SkuId,SkuPriceId
// TODO: x_BilledUnitPrice,x_EffectiveCostInUsd,x_EffectiveUnitPrice,ContractedCost,ContractedCostInUsd,x_PricingBlockSize
    ChargeFrequency            = _swapCol(ChargeDescription,                "tmp_Frequency",         "ChargeFrequency",             each if _isMissing("tmp_Frequency") or [tmp_Frequency] = "UsageBased" then "Usage-Based" else if [tmp_Frequency] = "OneTime" then "One-Time" else if [tmp_Frequency] = "Recurring" then "Recurring" else "Other"),
    ChargePeriodEnd            = Table.AddColumn(ChargeFrequency,           "ChargePeriodEnd",       each Date.AddDays([ChargePeriodStart], 1), type date),
    ExchangeRate               = _swapCol(ChargePeriodEnd,                  "tmp_ExchangeRate",      "x_BillingExchangeRate",       each if _isMissing("tmp_ExchangeRate")      or _isBlank([tmp_ExchangeRate])      then 1                    else [tmp_ExchangeRate],       type number),
    ExchangeRateDate           = _swapCol(ExchangeRate,                     "tmp_ExchangeRateDate",  "x_BillingExchangeRateDate",   each if _isMissing("tmp_ExchangeRateDate")  or _isBlank([tmp_ExchangeRateDate])  then [BillingPeriodStart] else [tmp_ExchangeRateDate],   type date),
    InvoiceIssuerName          = _swapCol(ExchangeRateDate,                 "tmp_InvoiceIssuerName", "InvoiceIssuerName",           each if _isMissing("tmp_InvoiceIssuerName") or _isBlank([tmp_InvoiceIssuerName]) then "Microsoft"          else [tmp_InvoiceIssuerName]),
    PricingCurrency            = _swapCol(InvoiceIssuerName,                "tmp_PricingCurrency",   "x_PricingCurrency",           each if _isBlank([tmp_PricingCurrency])                                          then [BillingCurrency]    else [tmp_PricingCurrency]),
    PricingCategory            = Table.AddColumn(PricingCurrency,           "PricingCategory",       each 
        if _isCommitmentDiscount([tmp_ChargeType], [tmp_PricingModel], [CommitmentDiscountId], [tmp_ReservationId]) or _isNotBlank([CommitmentDiscountId]) then "Committed"
        else if [tmp_PricingModel] = "Spot" then "Dynamic"
        else if [tmp_PricingModel] = "OnDemand" or [tmp_ChargeType] = "Usage" then "Standard"
        else if [ChargeCategory] = "Adjustment" or [ChargeCategory] = "Tax" then null
        else "Other"
    ),
    PricingSubcategory    = Table.AddColumn(PricingCategory,                "x_PricingSubcategory",  each 
        if [PricingCategory] = null then null
        else if [PricingCategory] = "On-Demand" then "Standard"
        else if [tmp_PricingModel] = "Spot" then "Spot"
        else if _isNotBlank([CommitmentDiscountCategory]) then "Committed " & [CommitmentDiscountCategory]
        else "Other"
    ),
    ProviderName               = Table.AddColumn(PricingSubcategory,        "ProviderName",          each "Microsoft"),
    PublisherName              = _swapCol(ProviderName,                     "tmp_PublisherName",     "PublisherName", each if _isNotBlank([tmp_PublisherName]) then [tmp_PublisherName]      else "Microsoft"),
    RegionName                 = Table.AddColumn(PublisherName,             "RegionName",                each
// TODO: Region = Unassigned
        if Text.StartsWith([tmp_ChargeType], "Unused") and [tmp_ResourceLocation] = "Unassigned" then "Global"
        else if [tmp_ChargeType] = "RoundingAdjustment"                                          then "Global"
        else if [tmp_ResourceLocation] = "All Regions"                                           then "Global"
        else if _isNotBlank([tmp_DefenderFor]) and _isBlank([tmp_ResourceLocation])              then "Global"
        else if _isBlank([tmp_ResourceLocation])                                                 then null
        else _regionCleanup([tmp_ResourceLocation])
    ),
// TODO: Parse ResourceName
// TODO: VMName???
    RegionId                   = Table.AddColumn(RegionName,                "RegionId",               each Text.Lower(Text.Replace([RegionName], " ", ""))),
    ResourceName               = _swapCol(RegionId,                         "tmp_ResourceName",       "ResourceName",              each if _isNotBlank([tmp_ResourceName])  then [tmp_ResourceName]       else if _isNotBlank([tmp_DefenderFor])      then "Microsoft Defender for " & [tmp_DefenderFor] else if [tmp_ChargeType] = "Purchase" and [tmp_ReservationName] <> "" then [tmp_ReservationName] else null),
// TODO: Parse ResourceType
    SkuTerm                    = Table.AddColumn(ResourceName,              "x_SkuTerm",              each if _isBlank([tmp_SkuTerm]) then null else if [tmp_SkuTerm] = "1Year" or [tmp_SkuTerm] = "12" then 12 else if [tmp_SkuTerm] = "3Years" or [tmp_SkuTerm] = "36" then 36 else if [tmp_SkuTerm] = "5Years" or [tmp_SkuTerm] = "60" then 60 else [tmp_SkuTerm], type number),
    SubAccountId               = Table.AddColumn(SkuTerm,                   "SubAccountId",           each [x_SubscriptionId]),
    SubAccountName             = Table.AddColumn(SubAccountId,              "SubAccountName",         each [x_SubscriptionName]),
    SubAccountType             = Table.AddColumn(SubAccountName,            "SubAccountType",         each "Subscription"),
    Tags                       = _swapCol(SubAccountType,                   "tmp_Tags",               "Tags",                      each if _isNotBlank([tmp_Tags])          then if Text.StartsWith([tmp_Tags], "{") then [tmp_Tags] else "{" & [tmp_Tags] & "}" else null),
// TODO: Map x_PricingUnitDescription to ConsumedUnit/PricingUnit/PricingBlockSize
    ConsumedUnit               = Table.AddColumn(Tags,                      "ConsumedUnit",           each [x_PricingUnitDescription]),
    PricingUnit                = Table.AddColumn(ConsumedUnit,              "PricingUnit",            each [x_PricingUnitDescription]),

    // Parse tags
    TagsDictionary             = Table.AddColumn(PricingUnit,               "x_TagsDictionary",       each if _isNotBlank([Tags]) then Json.Document([Tags]) else null),
    TagsDictionary_errors      = Table.ReplaceErrorValues(TagsDictionary, {{"x_TagsDictionary", null}}),

    // Commitment columns -- Must be after AHB and PricingModel cleanup
    CommitmentDiscountKey          = Table.AddColumn(TagsDictionary_errors,          "x_CommitmentDiscountKey",          each [x_SkuType] & [x_SkuMeterId]),
    CommitmentUtilizationPotential = Table.AddColumn(CommitmentDiscountKey,          "x_CommitmentUtilizationPotential", each if [CommitmentDiscountCategory] = "Usage" then [ConsumedQuantity] else if [CommitmentDiscountCategory] = "Spend" then [EffectiveCost] else 0, type number),
    CommitmentUtilizationAmount    = Table.AddColumn(CommitmentUtilizationPotential, "x_CommitmentUtilizationAmount",    each if [CommitmentDiscountStatus] = "Used" then [x_CommitmentUtilizationPotential] else 0, type number),
    
    // Price + cost columns
    ContractedUnitPrice      = _swapCol(CommitmentUtilizationAmount,     "tmp_ContractedUnitPrice",    "ContractedUnitPrice", each (if [tmp_ContractedUnitPrice] <> null and [tmp_ContractedUnitPrice] > 0.0 then [tmp_ContractedUnitPrice] else [x_EffectiveUnitPrice]),     type number),
    ListUnitPrice            = _swapCol(ContractedUnitPrice,             "tmp_ListUnitPrice",          "ListUnitPrice",       each (if [tmp_ListUnitPrice]     <> null and [tmp_ListUnitPrice]     > 0.0 then [tmp_ListUnitPrice]     else [ContractedUnitPrice]),        type number),
    ListCost                 = _swapCol(ListUnitPrice,                   "tmp_ListCost",               "ListCost",            each (if [tmp_ListCost]          <> null and [tmp_ListCost]          > 0.0 then [tmp_ListCost]          else [ListUnitPrice] * [ConsumedQuantity]),   type number),
    ListCostInUsd            = _swapCol(ListCost,                        "tmp_ListCostInUsd",          "x_ListCostInUsd",     each (if [tmp_ListCostInUsd]     <> null and [tmp_ListCostInUsd]     > 0.0 then [tmp_ListCostInUsd]     else [ListCost] * [x_BillingExchangeRate]),  type number),
    ContractedCost             = Table.AddColumn(ListCostInUsd,          "ContractedCost",             each [ConsumedQuantity] * [ContractedUnitPrice],               type number),
    ContractedUnitPriceSavings = Table.AddColumn(ContractedCost,         "ContractedUnitPriceSavings", each [ContractedUnitPrice] - [x_EffectiveUnitPrice], type number),
    ListUnitPriceSavings     = Table.AddColumn(ContractedUnitPriceSavings, "x_ListUnitPriceSavings",   each [ListUnitPrice] - [x_EffectiveUnitPrice],       type number),
    CommitmentSavings        = Table.AddColumn(ListUnitPriceSavings,     "x_CommitmentSavings",        each if _isBlank([CommitmentDiscountCategory]) then 0 else [ContractedCost] - [EffectiveCost], type number),
    NegotiatedSavings        = Table.AddColumn(CommitmentSavings,        "x_NegotiatedSavings",        each [ListCost] - [ContractedCost], type number),
    DiscountSavings          = Table.AddColumn(NegotiatedSavings,        "x_DiscountSavings",          each [ListCost] - [EffectiveCost], type number),

    // Unique names -- Must be after ResourceName cleanup and Commitment columns
// TODO: Only add differentiators when the name is not unique
    CommitmentDiscountNameUnique = Table.AddColumn(DiscountSavings,              "CommitmentDiscountNameUnique", each if _isBlank([CommitmentDiscountName]) then null else [CommitmentDiscountName] & " (" & [CommitmentDiscountType] & ")"),
// TODO: Change ResourceName differentiator to be the type
    ResourceNameUnique           = Table.AddColumn(CommitmentDiscountNameUnique, "ResourceNameUnique",           each if _isBlank([ResourceName])           then null else [ResourceName] & " (" & [ResourceId] & ")"),
    ResourceGroupNameUnique      = Table.AddColumn(ResourceNameUnique,           "x_ResourceGroupNameUnique",    each if _isBlank([x_ResourceGroupName])    then null else [x_ResourceGroupName] & " (" & [x_SubscriptionName] & ")"),
    SubscriptionNameUnique       = Table.AddColumn(ResourceGroupNameUnique,      "SubAccountNameUnique",         each if _isBlank([x_SubscriptionName])     then null else [x_SubscriptionName] & " (" & [x_SubscriptionId] & ")"),

    // Month column
    Month = Table.AddColumn(SubscriptionNameUnique, "x_Month", each Date.StartOfMonth([ChargePeriodStart]), type date),

    // Unique key for the record -- WARNING: This increases the data size significantly.
    /*
    _addIdSegment = (val) => (if _isNotBlank(val) then "-" & val else ""),
    ChargeId = Table.AddColumn(Month, "x_ChargeId", each Text.Combine(List.RemoveItems({
        Date.ToText([ChargePeriodStart]),
        [x_BillingAccountId],
        if [x_BillingProfileId] = [x_BillingAccountId] then null else [x_BillingProfileId], // Only add BP if not the same as the BA (all EA)
        [x_InvoiceSectionId],
        if _isNotBlank([ResourceId]) and Text.Contains([ResourceId], [x_SubscriptionId]) then null else [x_SubscriptionId], // Only add sub if not in the resource ID
        [ResourceId],
        [tmp_ResourceLocation],
        [x_SkuOfferId],
        [SkuId],
        [x_SkuMeterId],
        [x_SkuPartNumber],
        if _isBlank([CommitmentDiscountId]) then null else List.Last(Text.Split([CommitmentDiscountId], "/")),
        [x_CostAllocationRuleName],
        [x_CostCenter],
        if _isBlank([Tags])                 then null else Text.Remove([Tags], {"{","""","}"}),
        if _isBlank([x_SkuDetails])         then null else Text.Remove([x_SkuDetails], {"{","""","}"})
    }, {null, ""}), "-")),
    */

    // Cleanup
    // FOCUS ServiceName
    ServiceName = Table.AddColumn(Month, "ServiceName", each
        if [tmp_DefenderFor] <> null then (
            if [tmp_DefenderFor] = "DNS"                   then "Azure DNS"
            else if [tmp_DefenderFor] = "MySQL"            then "Azure Database for MySQL"
            else if [tmp_DefenderFor] = "Resource Manager" then "Azure Resource Manager"
            else if [tmp_DefenderFor] = "Servers"          then "Virtual Machines"
            else if [tmp_DefenderFor] = "SQL"              then "Azure SQL Database"
            else [tmp_DefenderFor]
        )
// TODO: Need a better check for AKS RG names
        else if _isNotBlank([x_ResourceGroupName]) and ((Text.StartsWith(Text.Lower([x_ResourceGroupName]), "mc_") and Text.EndsWith(Text.Lower([x_ResourceGroupName]), "_"&Text.Lower(Text.Replace([tmp_ResourceLocation], " ", "")))) or (_isNotBlank([x_SkuVMProperties]) and Text.Contains([x_SkuVMProperties], "Microsoft.AKS"))) then "Azure Kubernetes Service"
        else if [tmp_RPName] = "capacity"                then if Text.StartsWith(Text.Lower([ResourceId]), "/providers/microsoft.billingbenefits/savingsplan") then "Azure Savings Plans for Compute" else if [x_SkuMeterCategory] <> "" then [x_SkuMeterCategory] else "Azure Reservations"
        else if [tmp_RPName] = "compute"                 then "Virtual Machines"
        else if [tmp_RPName] = "dbformariadb"            then "Azure Database for MariaDB"
        else if [tmp_RPName] = "dbformysql"              then "Azure Database for MySQL"
        else if [tmp_RPName] = "dbforpostgresql"         then "Azure Database for PostgreSQL"
        else if [tmp_RPName] = "insights"                then "Azure Monitor"
        else if [tmp_RPName] = "keyvault"                then "Key Vault"
        else if [tmp_RPName] = "machinelearningservices" then "Azure Machine Learning"
        else if [tmp_RPName] = "operationalinsights"     then "Azure Monitor"
        else if [tmp_RPName] = "sql"                     then [x_SkuMeterCategory]
        else if [tmp_RPName] = "storage"                 then "Storage Accounts"
        else if [tmp_RPName] = "synapse"                 then "Azure Synapse Analytics"
        else if [tmp_RPName] = "web"                     then "App Service"
        else if [x_PublisherType] = "Marketplace" and ([x_SkuMeterCategory] = "SaaS" or [x_SkuMeterCategory] = "Azure Applications") then [x_SkuMeterSubcategory]
        else if _exists("tmp_ServiceName") then [tmp_ServiceName]
        else [x_SkuMeterCategory]
    ),

    // FOCUS ServiceCategory
    ServiceCategory = Table.AddColumn(ServiceName, "ServiceCategory", each
        if [ServiceName] = "Functions"                               then "Compute"
        else if [ServiceName] = "App Service"                        then "Web"
        else if [ServiceName] = "Azure DNS"                          then "Networking"
        else if [ServiceName] = "Azure Kubernetes Service"           then "Compute"
        else if [ServiceName] = "Azure Resource Manager"             then "Management and Governance"
        else if [ServiceName] = "Azure Savings Plans for Compute"    then "Compute"
        else if [ServiceName] = "Backup"                             then "Storage"
        else if [ServiceName] = "Microsoft Fabric"                   then "Analytics"
        else if [ServiceName] = "Virtual Machines"                   then "Compute"
        else if [tmp_RPName] = "api management"                      then "Integration"
        else if [tmp_RPName] = "appconfiguration"                    then "Web"
        else if [tmp_RPName] = "compute"                             then "Compute"
        else if [tmp_RPName] = "containerinstance"                   then "Compute"
        else if [tmp_RPName] = "containerregistry"                   then "Compute"
        else if [tmp_RPName] = "containerservice"                    then "Compute"
        else if [tmp_RPName] = "datafactory"                         then "Integration"
        else if [tmp_RPName] = "dbformysql"                          then "Databases"
        else if [tmp_RPName] = "dbforpostgressql"                    then "Databases"
        else if [tmp_RPName] = "digitaltwins"                        then "Internet of Things"
        else if [tmp_RPName] = "eventgrid"                           then "Integration"
        else if [tmp_RPName] = "insights"                            then "Management and Governance"
        else if [tmp_RPName] = "keyvault"                            then "Security"
        else if [tmp_RPName] = "loadtestservice"                     then "Developer Tools"
        else if [tmp_RPName] = "logic"                               then "Integration"
        else if [tmp_RPName] = "machinelearningservices"             then "AI and Machine Learning"
        else if [tmp_RPName] = "network"                             then "Networking"
        else if [tmp_RPName] = "operationalinsights"                 then "Management and Governance"
        else if [tmp_RPName] = "recoveryservices"                    then "Management and Governance"
        else if [tmp_RPName] = "search"                              then "Web"
        else if [tmp_RPName] = "security"                            then "Security"
        else if [tmp_RPName] = "servicebus"                          then "Integration"
        else if [tmp_RPName] = "storagesync"                         then "Storage"
        else if [tmp_RPName] = "sql"                                 then "Databases"
        else if [tmp_RPName] = "storage"                             then "Storage"
        else if [tmp_RPName] = "synapse"                             then "Analytics"
        else if [tmp_RPName] = "virtual network"                     then "Networking"
        else if [tmp_RPName] = "web"                                 then "Web"
        else if Text.Contains(Text.Lower([ServiceName]), "quantum")  then "Compute"
        else if Text.Contains(Text.Lower([ServiceName]), "redis")    then "Storage"
        else if Text.Contains(Text.Lower([ServiceName]), "sendgrid") then "Web"
        else if [x_SkuMeterCategory] = "RoundingAdjustment"          then "Other"
        else "Other"
    ),

    // Clean up temp columns and re-sort
    RemoveColumns = Table.RemoveColumns(ServiceCategory, {
        // Original columns
        "tmp_ChargeType",
        "tmp_PricingModel",
        "tmp_ReservationId",
        "tmp_ReservationName",
        "tmp_ResourceLocation",
        "tmp_ServiceName",
        "tmp_SkuTerm",
        // AdditionalInfo
        "tmp_AddlReservationOrderId", 
        "tmp_AddlReservationId",
        "tmp_SQLAHB",
        "tmp_SQLvCores",
        "tmp_VMvCPUs",
        // Helpers
        "tmp_DefenderFor",
        "tmp_RPName"
    }),
    Output = Table.ReorderColumns(RemoveColumns, List.Sort(Table.ColumnNames(RemoveColumns)))
in
    Output