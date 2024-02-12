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
        // TODO: {"x_SkuIsCreditEligible", type logical}
        // TODO: {"x_PartnerCreditApplied",  type logical}
    }),

    // Helper functions
    _exists     = (col) => Table.HasColumns(rawData, col),
    _isMissing  = (col) => _exists(col) = false,
    _isBlank    = (val) => val = null or val = "",
    _isNotBlank = (val) => _isBlank(val) = false,
    _swapCol    = (tbl, oldCol, newCol, newVal, optional newType) => let add = Table.AddColumn(tbl, newCol, newVal, newType), del = if Table.HasColumns(add, oldCol) then Table.RemoveColumns(add, {oldCol}) else add in del,
    _resetCol   = (tbl, col, newVal, optional newType) => let tmpCol = Text.Combine({"tmp_", col}), tmp = _swapCol(tbl, col, tmpCol, newVal, newType), ren = Table.RenameColumns(tmp, {{tmpCol, col}}) in ren,
    _armResourceName = (id) => List.Last(Text.Split(id, "/")),

    // FOCUS "1.0-preview (v1)" bugs
    SkuTerm = _resetCol(FixTypes, "x_SkuTerm", each if [x_SkuTerm] = "1Year" then 12 else if [x_SkuTerm] = "3Years" then 36 else if [x_SkuTerm] = "5Years" then 60 else Number.FromText([x_SkuTerm]), type number),

    // Parse arrays
    SkuDetailsDict        = Table.AddColumn(SkuTerm, "x_SkuDetailsDictionary", each if _isNotBlank([x_SkuDetails]) then Json.Document([x_SkuDetails]) else null),
    SkuDetailsDict_errors = Table.ReplaceErrorValues(SkuDetailsDict, {{"x_SkuDetailsDictionary", null}}),
    TagsDictionary        = Table.AddColumn(SkuDetailsDict_errors, "x_TagsDictionary", each if _isNotBlank([Tags]) then Json.Document([Tags]) else null),
    TagsDictionary_errors = Table.ReplaceErrorValues(TagsDictionary, {{"x_TagsDictionary", null}}),
    ParsedArrays = TagsDictionary_errors,

    // AHB columns
    SkuDetails_expand   = Table.ExpandRecordColumn(ParsedArrays, "x_SkuDetailsDictionary",
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
    ListUnitPriceSavings     = Table.AddColumn(Commitments,              "x_ListUnitPriceSavings",     each [ListUnitPrice] - [x_EffectiveUnitPrice],       type number),
    OnDemandUnitPriceSavings = Table.AddColumn(ListUnitPriceSavings,     "x_OnDemandUnitPriceSavings", each [x_OnDemandUnitPrice] - [x_EffectiveUnitPrice], type number),
    CommitmentSavings        = Table.AddColumn(OnDemandUnitPriceSavings, "x_CommitmentSavings",        each if _isBlank([CommitmentDiscountCategory]) then 0 else [x_OnDemandCost] - [EffectiveCost], type number),
    NegotiatedSavings        = Table.AddColumn(CommitmentSavings,        "x_NegotiatedSavings",        each [ListCost] - [x_OnDemandCost], type number),
    DiscountSavings          = Table.AddColumn(NegotiatedSavings,        "x_DiscountSavings",          each [ListCost] - [EffectiveCost], type number),
    Savings = DiscountSavings,

    // Data cleansing
    // TODO: BUG: SkuId == SkuPriceId for EA???

    // Unique names -- Must be after ResourceName cleanup and Commitment columns
// TODO: Only add differentiators when the name is not unique
    CommitmentDiscountNameUnique = Table.AddColumn(Savings,                      "CommitmentDiscountNameUnique", each if _isBlank([CommitmentDiscountId]) then null else [CommitmentDiscountName] & " (" & [CommitmentDiscountType] & ")"),
    ResourceNameUnique           = Table.AddColumn(CommitmentDiscountNameUnique, "ResourceNameUnique",           each if _isBlank([ResourceId])           then null else [ResourceName] & " (" & [ResourceType] & ")"),
    ResourceGroupNameUnique      = Table.AddColumn(ResourceNameUnique,           "x_ResourceGroupNameUnique",    each if _isBlank([x_ResourceGroupName])  then null else [x_ResourceGroupName] & " (" & [SubAccountName] & ")"),
    SubscriptionNameUnique       = Table.AddColumn(ResourceGroupNameUnique,      "SubAccountNameUnique",         each if _isBlank([SubAccountId])         then null else [SubAccountName] & " (" & _armResourceName([SubAccountId]) & ")"),
    Names = SubscriptionNameUnique,

    // Month column
    Month = Table.AddColumn(Names, "x_Month", each Date.StartOfMonth([ChargePeriodStart]), type datetimezone),

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