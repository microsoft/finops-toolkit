(optional start as datetime, optional end as datetime) =>
let
    // Get the data
    rawData = ftk_Hub("focuscost", start, end),

    // Fix types
    FixTypes = Table.TransformColumnTypes(rawData, {
        // Date columns
        {"BillingPeriodEnd",          type datetimezone},
        {"BillingPeriodStart",        type datetimezone},
        {"ChargePeriodEnd",           type datetimezone},
        {"ChargePeriodStart",         type datetimezone},
        {"x_BillingExchangeRateDate", type datetimezone},
        {"x_ServicePeriodStart",      type datetimezone},
        {"x_ServicePeriodEnd",        type datetimezone},
        // Cost/price columns
        {"BilledCost",                type number},
        {"EffectiveCost",             type number},
        {"ListCost",                  type number},
        {"ListUnitPrice",             type number},
        {"x_BilledCostInUsd",         type number},
        {"x_BilledUnitPrice",         type number},
        {"x_EffectiveCostInUsd",      type number},
        {"x_EffectiveUnitPrice",      type number},
        {"x_OnDemandCost",            type number},
        {"x_OnDemandCostInUsd",       type number},
        {"x_OnDemandUnitPrice",       type number},
        // Other columns
        {"PricingQuantity",           type number},
        {"UsageQuantity",             type number},
        {"x_BillingExchangeRate",     type number},
        {"x_PartnerCreditRate",       type number},
        {"x_PricingBlockSize",        type number},
        {"x_SkuTerm",                 type text}  // Text due to a bug in CM data; converted to a number below
        // TODO: {"x_SkuIsCreditEligible",   type logical}
        // TODO: {"x_PartnerCreditApplied",  type logical}
    }),

    // Helper functions
    _exists     = (col) => Table.HasColumns(rawData, col),
    _isMissing  = (col) => _exists(col) = false,
    _isBlank    = (val) => val = null or val = "",
    _isNotBlank = (val) => _isBlank(val) = false,
    _swapCol    = (tbl, oldCol, newCol, newVal, optional newType) => let add = Table.AddColumn(tbl, newCol, newVal, newType), del = if Table.HasColumns(add, oldCol) then Table.RemoveColumns(add, {oldCol}) else add in del,
    _resetCol   = (tbl, col, newVal, optional newType) => let tmpCol = Text.Combine({"tmp_", col}), tmp = _swapCol(tbl, col, tmpCol, newVal, newType), ren = Table.RenameColumns(tmp, {{tmpCol, col}}) in ren,
    _parseResourceId = (id, getName) => if _isBlank(id) then null else 
        let
            // Handle implicit Microsoft.Resources RP names
            updatedId = if Text.StartsWith(id, "/subscriptions/") or Text.StartsWith(id, "/tenants/") then "/providers/Microsoft.Resources" & id else id,

            // Parse resource ID segments separately
            allSegments = Text.Split(List.Last(Text.Split(updatedId, "/providers/")), "/"),
            provider = allSegments{0},
            _parseId = (evenOrOdd) => List.RemoveNulls(List.Transform({1..List.Count(allSegments)-1}, each if Number.Mod(_, 2) = evenOrOdd then allSegments{_} else null)),
            nameSegments = _parseId(0),
            typeSegments = _parseId(1),
            
            // Remove the sub ID if it's a child resource of the subscription
            isChildOfSubscription = provider = "Microsoft.Resources" and Text.Lower(typeSegments{0}) = "subscriptions" and List.Count(typeSegments) > 1,
            fullName = Text.Combine((if isChildOfSubscription then List.RemoveFirstN(nameSegments, 1) else nameSegments), "/"),

            fullType = provider & "/" & Text.Combine(typeSegments, "/"),
            result = if getName then fullName else fullType
        in
            result
    ,
    _parseResourceName = (id) => _parseResourceId(id, true),
    _parseResourceType = (id) => _parseResourceId(id, false),
    
    // FOCUS "1.0-preview(v1)" bugs
    SkuTerm = _resetCol(FixTypes, "x_SkuTerm", each if [x_SkuTerm] = "1Year" then 12 else if [x_SkuTerm] = "3Years" then 36 else if [x_SkuTerm] = "5Years" then 60 else Number.FromText([x_SkuTerm]), type number),

    // Parse arrays
    SkuDetailsDict        = Table.AddColumn(SkuTerm,        "x_SkuDetailsDictionary", each if _isNotBlank([x_SkuDetails]) then Json.Document([x_SkuDetails]) else null),
    SkuDetailsDict_copy   = Table.AddColumn(SkuDetailsDict, "tmp_SkuDetails",         each [x_SkuDetailsDictionary]),
    SkuDetailsDict_errors = Table.ReplaceErrorValues(SkuDetailsDict_copy, {{"tmp_SkuDetails", null}}),
    Tags_backfill         = _resetCol(SkuDetailsDict_errors, "Tags", each if _isBlank([Tags]) then "{}" else [Tags]),
    TagsDictionary        = Table.AddColumn(Tags_backfill,  "x_TagsDictionary", each if _isNotBlank([Tags]) then Json.Document([Tags]) else null),
    TagsDictionary_copy   = Table.AddColumn(TagsDictionary, "tmp_Tags",         each [x_TagsDictionary]),
    TagsDictionary_errors = Table.ReplaceErrorValues(TagsDictionary_copy, {{"tmp_Tags", null}}),
    ParsedArrays = TagsDictionary_errors,

    // FTK columns
    Tags_expand  = Table.ExpandRecordColumn(ParsedArrays, "tmp_Tags",
        {"cm-resource-parent", "ms-resource-parent", "hidden-managedby", "costanalysis-parent", "ftk-version",      "ftk-tool"},
        {"tmp_cmParent",       "tmp_msParent",       "tmp_ManagedBy",    "tmp_caParent",        "x_ToolkitVersion", "tmp_ToolkitTool"}
    ),
    ResourceParentId   = Table.AddColumn(Tags_expand,        "x_ResourceParentId",   
        each Text.Replace("/" & (if _isNotBlank([tmp_cmParent])  then [tmp_cmParent] 
        else if _isNotBlank([tmp_msParent])  then [tmp_msParent] 
        else if _isNotBlank([tmp_ManagedBy]) then [tmp_ManagedBy] 
        else if _isNotBlank([tmp_caParent])  then [tmp_caParent] 
        else null), "//", "/")),
    ResourceParentId_backfill = _resetCol(ResourceParentId,         "x_ResourceParentId",   each if _isBlank([x_ResourceParentId]) then null else [x_ResourceParentId]),
    ResourceParentType = Table.AddColumn(ResourceParentId_backfill, "x_ResourceParentType", each _parseResourceType([x_ResourceParentId])),
    ResourceParentName = Table.AddColumn(ResourceParentType,        "x_ResourceParentName", each _parseResourceName([x_ResourceParentId])),
    Tool = _swapCol(ResourceParentName, "tmp_ToolkitTool", "x_ToolkitTool", 
        each if _isNotBlank([tmp_ToolkitTool]) then [tmp_ToolkitTool] 
        else if _isBlank([x_ResourceParentId]) then null 
        else if Text.Contains(Text.Lower([x_ResourceParentId]), "/providers/microsoft.cloud/hubs/") then "FinOps hubs"
        else null),
    ExpandedTags = Table.RemoveColumns(Tool, { "tmp_cmParent", "tmp_msParent", "tmp_caParent", "tmp_ManagedBy" }),

    // AHB columns
    SkuDetails_expand   = Table.ExpandRecordColumn(ExpandedTags, "tmp_SkuDetails",
        {"UsageType",      "ImageType",      "ServiceType", "VMName",     "VMProperties",      "VCPUs",       "ReservationOrderId",         "ReservationId",         "VMCapacityReservationId", "AHB",        "vCores"},
        {"x_SkuUsageType", "x_SkuImageType", "x_SkuType",   "tmp_VMName", "x_SkuVMProperties", "tmp_VMvCPUs", "tmp_AddlReservationOrderId", "tmp_AddlReservationId", "x_CapacityCommitmentId",  "tmp_SQLAHB", "tmp_SQLvCores"}
    ),
    SkuDetails_types    = Table.TransformColumnTypes(SkuDetails_expand, {{"tmp_VMvCPUs", Int64.Type}, {"tmp_SQLvCores", Int64.Type}}),
    ResourceMachineName = _swapCol(SkuDetails_types,           "tmp_VMName",         "x_ResourceMachineName", each if _isNotBlank([tmp_VMName]) then [tmp_VMName] else null),
    ProductCPUs         = Table.AddColumn(ResourceMachineName, "x_SkuCPUs",          each if [tmp_VMvCPUs] <> null then [tmp_VMvCPUs] else if [tmp_SQLvCores] <> null then [tmp_SQLvCores] else null, Int64.Type),
    CPUHours            = Table.AddColumn(ProductCPUs,         "x_UsageCPUHours",    each if [x_SkuCPUs] <> null then [x_SkuCPUs] * [UsageQuantity] else null, type number),
    HybridBenefitStatus = Table.AddColumn(CPUHours,            "x_SkuLicenseStatus", each if _isNotBlank([x_SkuMeterSubcategory]) and Text.Contains([x_SkuMeterSubcategory], "Windows") or [tmp_SQLAHB] = "False" then "Not enabled" else if (_isNotBlank([x_SkuImageType]) and Text.Contains([x_SkuImageType], "Windows Server BYOL")) or [tmp_SQLAHB] = "True" or (_isNotBlank([x_SkuMeterSubcategory]) and Text.Contains([x_SkuMeterSubcategory], "Azure Hybrid Benefit")) then "Enabled" else "Not supported"),
    HybridBenefitCPUs   = Table.AddColumn(HybridBenefitStatus, "x_SkuLicenseCPUs",   each if [x_SkuCPUs] = null then 0 else if [x_SkuCPUs] <= 8 then 8 else if [x_SkuCPUs] <= 16 then 16 else if [x_SkuCPUs] = 20 then 24 else if [x_SkuCPUs] > 20 then [x_SkuCPUs] else 0, type number),
// TODO: Add SQL AHB handling
    AHB = Table.RemoveColumns(HybridBenefitCPUs, { "tmp_AddlReservationOrderId", "tmp_AddlReservationId", "tmp_SQLAHB", "tmp_SQLvCores", "tmp_VMvCPUs" }),

    // Commitment metadata
    CommitmentDiscountKey          = Table.AddColumn(AHB,                            "x_CommitmentDiscountKey",          each [x_SkuType] & [x_SkuMeterId]),
    CommitmentUtilizationPotential = Table.AddColumn(CommitmentDiscountKey,          "x_CommitmentUtilizationPotential", each if [CommitmentDiscountCategory] = "Usage" then [UsageQuantity] else if [CommitmentDiscountCategory] = "Spend" then [EffectiveCost] else 0, type number),
    CommitmentUtilizationAmount    = Table.AddColumn(CommitmentUtilizationPotential, "x_CommitmentUtilizationAmount",    each if [ChargeSubcategory] = "Used Commitment" then [x_CommitmentUtilizationPotential] else 0, type number),
    Commitments = CommitmentUtilizationAmount,

    // Savings calculations
    CommitmentUnitPriceSavings = Table.AddColumn(Commitments,                "x_CommitmentUnitPriceSavings", each if [x_OnDemandUnitPrice] > 0 and [x_OnDemandUnitPrice] >= [x_EffectiveUnitPrice] then [x_OnDemandUnitPrice] - [x_EffectiveUnitPrice] else null, type number),
    NegotiatedUnitPriceSavings = Table.AddColumn(CommitmentUnitPriceSavings, "x_NegotiatedUnitPriceSavings", each if [ListUnitPrice]       > 0 and [ListUnitPrice]       >= [x_OnDemandUnitPrice]  then [ListUnitPrice]       - [x_OnDemandUnitPrice]  else null, type number),
    DiscountUnitPriceSavings   = Table.AddColumn(NegotiatedUnitPriceSavings, "x_DiscountUnitPriceSavings",   each if [ListUnitPrice]       > 0 and [ListUnitPrice]       >= [x_EffectiveUnitPrice] then [ListUnitPrice]       - [x_EffectiveUnitPrice] else null, type number),
    CommitmentCostSavings      = Table.AddColumn(DiscountUnitPriceSavings,   "x_CommitmentCostSavings",      each if _isBlank([CommitmentDiscountCategory]) then 0 else if [x_OnDemandCost] > 0 and [x_OnDemandCost] >= [EffectiveCost] then [x_OnDemandCost] - [EffectiveCost] else null, type number),
    NegotiatedCostSavings      = Table.AddColumn(CommitmentCostSavings,      "x_NegotiatedCostSavings",      each if [ListCost]            > 0 and [ListCost]            >= [x_OnDemandCost]       then [ListCost]            - [x_OnDemandCost] else null, type number),
    DiscountCostSavings        = Table.AddColumn(NegotiatedCostSavings,      "x_DiscountCostSavings",        each if [ListCost]            > 0 and [ListCost]            >= [EffectiveCost]        then [ListCost]            - [EffectiveCost]  else if [x_OnDemandCost] > 0 and [x_OnDemandCost] >= [EffectiveCost] then [x_OnDemandCost] - [EffectiveCost] else null, type number),
    Savings = DiscountCostSavings,

    // Data cleansing
    FreeReason = Table.AddColumn(Savings, "x_FreeReason", 
        each if [BilledCost] <> 0.0 or [EffectiveCost] <> 0.0 then null
        else if [PricingCategory] = "Commitment-Based" then "Unknown " & [ChargeSubcategory]
        else if [x_BilledUnitPrice] = 0.0 and [x_EffectiveUnitPrice] = 0.0 and [x_OnDemandUnitPrice] = 0.0 and [ListUnitPrice] = 0.0 and _isBlank([CommitmentDiscountType]) then (
            if _isNotBlank([x_SkuDescription]) and Text.Contains([x_SkuDescription], "Trial") then "Trial" else if _isNotBlank([x_SkuDescription]) and Text.Contains([x_SkuDescription], "Preview") then "Preview" else "Other"
        )
        else if [x_BilledUnitPrice] > 0.0 or [x_EffectiveUnitPrice] > 0.0 then (
            if [PricingQuantity] > 0.0 then "Low Usage" else if [PricingQuantity] = 0.0 then "No Usage" else "Unknown Negative Quantity"
        )
        else "Unknown"),
    // TODO: BUG: SkuId == SkuPriceId for EA???

    // Unique names -- Must be after ResourceName cleanup and Commitment columns
// TODO: Only add differentiators when the name is not unique
    CommitmentDiscountNameUnique = Table.AddColumn(FreeReason,                   "CommitmentDiscountNameUnique", each if _isBlank([CommitmentDiscountId]) then null else [CommitmentDiscountName] & " (" & [CommitmentDiscountType] & ")"),
    ResourceNameUnique           = Table.AddColumn(CommitmentDiscountNameUnique, "ResourceNameUnique",           each if _isBlank([ResourceId])           then null else [ResourceName] & " (" & [ResourceType] & ")"),
    ResourceGroupNameUnique      = Table.AddColumn(ResourceNameUnique,           "x_ResourceGroupNameUnique",    each if _isBlank([x_ResourceGroupName])  then null else [x_ResourceGroupName] & " (" & [SubAccountName] & ")"),
    SubscriptionNameUnique       = Table.AddColumn(ResourceGroupNameUnique,      "SubAccountNameUnique",         each if _isBlank([SubAccountId])         then null else [SubAccountName] & " (" & _parseResourceName([SubAccountId]) & ")"),
    Names = SubscriptionNameUnique,

    // Month column
    Month = Table.AddColumn(Names, "x_Month", each DateTime.Date(Date.StartOfMonth([ChargePeriodStart])), type date),

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
        [SkuPriceId],
        [x_SkuMeterId],
        [x_SkuPartNumber],
        if _isBlank([CommitmentDiscountId]) then null else List.Last(Text.Split([CommitmentDiscountId], "/")),
        [x_CostAllocationRuleName],
        [x_CostCenter],
        if _isBlank([Tags])                 then null else Text.Remove([Tags], {"{","""","}"}),
        if _isBlank([x_SkuDetails])         then null else Text.Remove([x_SkuDetails], {"{","""","}"})
    }, {null, ""}), "-")),
    */

    // Sort columns alphabetically
    Output = Table.ReorderColumns(Month, List.Sort(Table.ColumnNames(Month)))
in
    Output
