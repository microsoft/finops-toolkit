(input, optional SchemaVersion) =>
let
//     DataSet = Schema, // Table.AddColumn(AccountType, "DataSet", each "AmortizedCost"),

    // What version should we generate? Allowed values: -1 = EA, 0 = Interim, 0.5 = FOCUS 0.5, 1.0 = FOCUS 1.0
    _targetSchema = if SchemaVersion = null then -1 else SchemaVersion,

    // Known schemas
    // _unifiedSchema = {"AccountName",    "AccountOwnerId",    "AdditionalInfo",     "AvailabilityZone", "BenefitId",                "BenefitName",                "BillingAccountId",    "BillingAccountName",    "BillingCurrency",     "BillingPeriodEndDate", "BillingPeriodStartDate", "BillingProfileId",    "BillingProfileName",    "ChargeType",     "ConsumedService",     "CostAllocationRuleName",    "CostCenter",    "CostInBillingCurrency",     "CostInPricingCurrency", "CostInUsd",     "CustomerName",    "CustomerTenantId",    "Date",              "EffectivePrice",     "ExchangeRatePricingToBilling", "ExchangeRateDate",     "Frequency",          "InvoiceId",    "InvoiceSectionId",    "InvoiceSectionName",    "IsAzureCreditEligible",    "MeterCategory",    "MeterId",    "MeterName",    "MeterRegion",    "MeterSubCategory",    "OfferId",    "PartNumber",    "PartnerEarnedCreditApplied", "PartnerEarnedCreditRate", "PartnerName",           "PartnerTenantId",     "PaygCostInBillingCurrency", "PaygCostInUsd",     "PayGPrice",     "PlanName",    "PreviousInvoiceId",    "PricingCurrency",     "PricingModel",     "ProductId",    "ProductName",    "ProductOrderId",    "ProductOrderName",    "Provider",    "PublisherId",    "PublisherName", "PublisherType",     "Quantity",      "ResellerMpnId",    "ResellerName",    "ReservationId",     "ReservationName",     "ResourceGroup",        "ResourceId", "ResourceLocation",     "ResourceName",     "ResourceType",     "ServiceFamily",    "ServicePeriodEndDate",     "ServicePeriodStartDate",    "SubscriptionId",     "SubscriptionName",     "Tags",     "Term",    "UnitOfMeasure",    "UnitPrice"},
    // _eaSchema      = {"AccountName",    "AccountOwnerId",    "AdditionalInfo",     "AvailabilityZone", "benefitId",                "benefitName",                "BillingAccountId",    "BillingAccountName",    "BillingCurrencyCode", "BillingPeriodEndDate", "BillingPeriodStartDate", "BillingProfileId",    "BillingProfileName",    "ChargeType",     "ConsumedService",     "CostAllocationRuleName",    "CostCenter",    "CostInBillingCurrency",     "PricingCost",           "costInUsd",     "CustomerName",    "CustomerTenantId",    "Date",              "EffectivePrice",     "tmp_ExchangeRate",             "tmp_ExchangeRateDate", "Frequency",          "InvoiceId",    "InvoiceSectionId",    "InvoiceSectionName",    "IsAzureCreditEligible",    "MeterCategory",    "MeterId",    "MeterName",    "MeterRegion",    "MeterSubCategory",    "OfferId",    "PartNumber",    "PartnerEarnedCreditApplied", "PartnerEarnedCreditRate", "PartnerName",           "PartnerTenantId",     "tmp_ListCost",              "paygCostInUsd",     "PayGPrice",     "PlanName",    "PreviousInvoiceId",    "tmp_PricingCurrency", "PricingModel",     "ProductId",    "ProductName",    "ProductOrderId",    "ProductOrderName",    "Provider",    "PublisherId",    "PublisherName", "PublisherType",     "Quantity",      "ResellerMpnId",    "ResellerName",    "ReservationId",     "ReservationName",     "ResourceGroup",        "ResourceId", "ResourceLocation",     "ResourceName",     "ResourceType",     "ServiceFamily",    "ServicePeriodEndDate",     "ServicePeriodStartDate",    "SubscriptionId",     "SubscriptionName",     "Tags",     "Term",    "UnitOfMeasure",    "UnitPrice"},
    // _mcaSchema     = {"AccountName",    "AccountOwnerId",    "additionalInfo",     "AvailabilityZone", "benefitId",                "benefitName",                "billingAccountId",    "billingAccountName",    "billingCurrency",     "billingPeriodEndDate", "billingPeriodStartDate", "billingProfileId",    "billingProfileName",    "chargeType",     "consumedService",     "costAllocationRuleName",    "costCenter",    "costInBillingCurrency",     "costInPricingCurrency", "costInUsd",     "customerName",    "customerTenantId",    "date",              "effectivePrice",     "exchangeRatePricingToBilling", "exchangeRateDate",     "frequency",          "invoiceId",    "invoiceSectionId",    "invoiceSectionName",    "isAzureCreditEligible",    "meterCategory",    "meterId",    "meterName",    "meterRegion",    "meterSubCategory",    "OfferId",    "PartNumber",    "partnerEarnedCreditApplied", "partnerEarnedCreditRate", "partnerName",           "partnerTenantId",     "paygCostInBillingCurrency", "paygCostInUsd",     "PayGPrice",     "PlanName",    "previousInvoiceId",    "pricingCurrency",     "pricingModel",     "ProductId",    "ProductName",    "productOrderId",    "productOrderName",    "provider",    "publisherId",    "publisherName", "publisherType",     "quantity",      "resellerMpnId",    "resellerName",    "reservationId",     "reservationName",     "resourceGroupName",    "ResourceId", "resourceLocation",     "ResourceName",     "ResourceType",     "serviceFamily",    "servicePeriodEndDate",     "servicePeriodStartDate",    "SubscriptionId",     "subscriptionName",     "tags",     "term",    "unitOfMeasure",    "unitPrice"},
    // _otherSchema   = {"AccountName",    "AccountOwnerId",    "AdditionalInfo",     "AvailabilityZone", "BenefitId",                "BenefitName",                "BillingAccountId",    "BillingAccountName",    "Currency",            "BillingPeriodEndDate", "BillingPeriodStartDate", "BillingProfileId",    "BillingProfileName",    "ChargeType",     "ConsumedService",     "CostAllocationRuleName",    "CostCenter",    "PreTaxCost",                "PricingCost",           "CostInUsd",     "CustomerName",    "CustomerTenantId",    "UsageDateTime",     "EffectiveUnitPrice", "ExchangeRatePricingToBilling", "ExchangeRateDate",     "Frequency",          "InvoiceId",    "InvoiceSectionId",    "DepartmentName",        "IsAzureCreditEligible",    "MeterCategory",    "MeterId",    "MeterName",    "MeterRegion",    "MeterSubcategory",    "OfferId",    "PartNumber",    "PartnerEarnedCreditApplied", "PartnerEarnedCreditRate", "PartnerName",           "PartnerTenantId",     "tmp_ListCost",              "paygCostInUsd",     "PayGPrice",     "PlanName",    "PreviousInvoiceId",    "PricingCurrency",     "PricingModel",     "ProductId",    "ProductName",    "ProductOrderId",    "ProductOrderName",    "Provider",    "PublisherId",    "PublisherName", "PublisherType",     "UsageQuantity", "ResellerMpnId",    "ResellerName",    "ReservationId",     "ReservationName",     "ResourceGroup",        "ResourceId", "ResourceLocation",     "ResourceName",     "ResourceType",     "ProductCategory",  "ServicePeriodEndDate",     "ServicePeriodStartDate",    "SubscriptionGuid",   "SubscriptionName",     "Tags",     "Term",    "UnitOfMeasure",    "ResourceRate"},
    // _interimSchema = {"AccountName",    "AccountOwnerId",    "tmp_AdditionalInfo", "AvailabilityZone", "tmp_CommitmentDiscountId", "tmp_CommitmentDiscountName", "BillingAccountId",    "BillingAccountName",    "BillingCurrency",     "BillingPeriodEnd",     "BillingPeriodStart",     "BillingProfileId",    "BillingProfileName",    "ChargeType",     "ConsumedService",     "CostAllocationRuleName",    "CostCenter",    "tmp_CostInBillingCurrency", "PricingCost",           "tmp_CostInUsd", "CustomerName",    "CustomerTenantId",    "Date",              "EffectivePrice", "tmp_ExchangeRate",             "tmp_ExchangeRateDate", "Frequency",          "InvoiceId",    "InvoiceSectionId",    "InvoiceSectionName",    "IsAzureCreditEligible",    "MeterCategory",    "MeterId",    "MeterName",    "MeterRegion",    "MeterSubCategory",    "OfferId",    "PartNumber",    "PartnerCreditApplied",       "PartnerCreditRate",       "PartnerName",           "PartnerId",           "tmp_ListCost",              "tmp_ListCostInUsd", "tmp_ListPrice", "PlanName",    "PreviousInvoiceId",    "tmp_PricingCurrency", "tmp_PricingModel", "ProductId",    "ProductName",    "ProductOrderId",    "ProductOrderName",    "Provider",    "PublisherId",    "PublisherName", "tmp_PublisherType", "Quantity",      "ResellerMpnId",    "ResellerName",    "tmp_ReservationId", "tmp_ReservationName", "ResourceGroupName",    "ResourceId", "tmp_ResourceLocation", "tmp_ResourceName", "tmp_ResourceType", "ServiceFamily",    "ServicePeriodEndDate",     "ServicePeriodStartDate",    "tmp_SubscriptionId", "tmp_SubscriptionName", "tmp_Tags", "Term",    "UnitOfMeasure",    "tmp_OnDemandUnitPrice"},
    // _focus05       = {"ms_AccountName", "ms_AccountOwnerId", "tmp_AdditionalInfo", "AvailabilityZone", "tmp_CommitmentDiscountId", "tmp_CommitmentDiscountName", "ms_BillingAccountId", "ms_BillingAccountName", "BillingCurrency",     "tmp_BillingPeriodEnd", "BillingPeriodStart",     "ms_BillingProfileId", "ms_BillingProfileName", "ms_ChargeType",  "ms_ConsumedService",  "ms_CostAllocationRuleName", "ms_CostCenter", "tmp_CostInBillingCurrency", "tmp_PricingCost",       "tmp_CostInUsd", "ms_CustomerName", "ms_CustomerTenantId", "ChargePeriodStart", "EffectivePrice", "tmp_ExchangeRate",             "tmp_ExchangeRateDate", "ms_Frequency",       "ms_InvoiceId", "ms_InvoiceSectionId", "ms_InvoiceSectionName", "ms_IsAzureCreditEligible", "ms_MeterCategory", "ms_MeterId", "ms_MeterName", "ms_MeterRegion", "ms_MeterSubCategory", "ms_OfferId", "ms_PartNumber", "ms_PartnerCreditApplied",    "ms_PartnerCreditRate",    "tmp_InvoiceIssuerName", "tmp_InvoiceIssuerId", "tmp_ListCost",              "tmp_ListCostInUsd", "tmp_ListPrice", "ms_PlanName", "ms_PreviousInvoiceId", "tmp_PricingCurrency", "tmp_PricingModel", "ms_ProductId", "ms_ProductName", "ms_ProductOrderId", "ms_ProductOrderName", "ms_Provider", "ms_PublisherId", "PublisherName", "tmp_PublisherType", "ms_Quantity",   "ms_ResellerMpnId", "ms_ResellerName", "tmp_ReservationId", "tmp_ReservationName", "ms_ResourceGroupName", "ResourceId", "tmp_ResourceLocation", "tmp_ResourceName", "tmp_ResourceType", "ms_ServiceFamily", "tmp_ServicePeriodEndDate", "ms_ServicePeriodStartDate", "tmp_SubscriptionId", "tmp_SubscriptionName", "tmp_Tags", "ms_Term", "ms_UnitOfMeasure", "tmp_OnDemandUnitPrice"},
    // _focus10       = {"ms_AccountName", "ms_AccountOwnerId", "tmp_AdditionalInfo", "AvailabilityZone", "tmp_CommitmentDiscountId", "tmp_CommitmentDiscountName", "ms_BillingAccountId", "ms_BillingAccountName", "BillingCurrency",     "tmp_BillingPeriodEnd", "BillingPeriodStart",     "ms_BillingProfileId", "ms_BillingProfileName", "tmp_ChargeType", "tmp_ConsumedService", "ms_CostAllocationRuleName", "ms_CostCenter", "tmp_CostInBillingCurrency", "tmp_PricingCost",       "tmp_CostInUsd", "ms_CustomerName", "ms_CustomerTenantId", "ChargePeriodStart", "EffectivePrice", "tmp_ExchangeRate",             "tmp_ExchangeRateDate", "tmp_ChargeFrequency","ms_InvoiceId", "ms_InvoiceSectionId", "ms_InvoiceSectionName", "ms_IsAzureCreditEligible", "ms_MeterCategory", "ms_MeterId", "ms_MeterName", "ms_MeterRegion", "ms_MeterSubCategory", "ms_OfferId", "ms_PartNumber", "ms_PartnerCreditApplied",    "ms_PartnerCreditRate",    "tmp_InvoiceIssuerName", "tmp_InvoiceIssuerId", "tmp_ListCost",              "tmp_ListCostInUsd", "tmp_ListPrice", "ms_PlanName", "ms_PreviousInvoiceId", "tmp_PricingCurrency", "tmp_PricingModel", "ms_ProductId", "ms_ProductName", "ms_ProductOrderId", "ms_ProductOrderName", "ms_Provider", "ms_PublisherId", "PublisherName", "tmp_PublisherType", "ms_Quantity",   "ms_ResellerMpnId", "ms_ResellerName", "tmp_ReservationId", "tmp_ReservationName", "ms_ResourceGroupName", "ResourceId", "tmp_ResourceLocation", "tmp_ResourceName", "tmp_ResourceType", "ms_ServiceFamily", "tmp_ServicePeriodEndDate", "ms_ServicePeriodStartDate", "tmp_SubscriptionId", "tmp_SubscriptionName", "tmp_Tags", "ms_Term", "PricingUnit",      "tmp_OnDemandUnitPrice"},

    // Mapping of old names to new names
    // TODO: Needed? -- _pickSchema = (ea, interim, focus05, focus10) => if _targetSchema = 0 then interim else if _targetSchema = 0.5 then focus05 else if _targetSchema = 1.0 then focus10 else ea,
    _originalColumns = Table.ColumnNames(input),
    _nameChanges = [
        // Passthrough
        AccountName                  = "AccountName",
        AccountOwnerId               = "AccountOwnerId",
        AdditionalInfo               = "AdditionalInfo",
        AmortizedCost                = "AmortizedCost",
        AmortizedCostInUsd           = "AmortizedCostInUsd",
        AmortizedPricingCost         = "AmortizedPricingCost",
        BilledCost                   = "BilledCost",
        BilledCostInUsd              = "BilledCostInUsd",
        BilledPricingCost            = "BilledPricingCost",
        BillingAccountId             = "BillingAccountId",
        BillingAccountName           = "BillingAccountName",
        BillingCurrency              = "BillingCurrency",
        BillingPeriodEndDate         = "BillingPeriodEndDate",
        BillingPeriodStartDate       = "BillingPeriodStartDate",
        BillingProfileId             = "BillingProfileId",
        BillingProfileName           = "BillingProfileName",
        ChargeType                   = "ChargeType",
        ConsumedService              = "ConsumedService",
        CostAllocationRuleName       = "CostAllocationRuleName",
        CostCenter                   = "CostCenter",
        CustomerName                 = "CustomerName",
        DataSet                      = "DataSet",
        Date                         = "Date",
        EffectivePrice               = "EffectivePrice",
        Frequency                    = "Frequency",
        InvoiceId                    = "InvoiceId",
        InvoiceSectionId             = "InvoiceSectionId",
        InvoiceSectionName           = "InvoiceSectionName",
        IsAzureCreditEligible        = "IsAzureCreditEligible",
        MeterCategory                = "MeterCategory",
        MeterId                      = "MeterId",
        MeterName                    = "MeterName",
        MeterRegion                  = "MeterRegion",
        MeterSubCategory             = "MeterSubCategory",
        OfferId                      = "OfferId",
        PartNumber                   = "PartNumber",
        PartnerName                  = "PartnerName",
        PlanName                     = "PlanName",
        PreviousInvoiceId            = "PreviousInvoiceId",
        ProductId                    = "ProductId",
        ProductName                  = "ProductName",
        ProductOrderId               = "ProductOrderId",
        ProductOrderName             = "ProductOrderName",
        Provider                     = "Provider",
        PublisherId                  = "PublisherId",
        PublisherType                = "PublisherType",
        Quantity                     = "Quantity",
        ResourceId                   = "ResourceId",
        ResourceType                 = "ResourceType",
        ResellerName                 = "ResellerName",
        ServiceFamily                = "ServiceFamily",
        ServicePeriodEndDate         = "ServicePeriodEndDate",
        ServicePeriodStartDate       = "ServicePeriodStartDate",
        SubscriptionId               = "SubscriptionId",
        SubscriptionName             = "SubscriptionName",
        Tags                         = "Tags",
        Term                         = "Term",
        UnitOfMeasure                = "UnitOfMeasure",
        // Changes
        BenefitId                    = "tmp_BenefitId",
        BenefitName                  = "tmp_BenefitName",
        BillingCurrencyCode          = "BillingCurrency",
        Currency                     = "BillingCurrency",
        CustomerTenantId             = "CustomerId",
        DepartmentName               = "InvoiceSectionName",
        EffectiveUnitPrice           = "EffectivePrice",
        ExchangeRate                 = "tmp_ExchangeRate",
        ExchangeRateDate             = "tmp_ExchangeRateDate",
        ExchangeRatePricingToBilling = "tmp_ExchangeRate",
        InvoiceSection               = "InvoiceSectionName",
        MeterSubcategory             = "MeterSubCategory",
        PartnerEarnedCreditApplied   = "PartnerCreditApplied",
        PartnerEarnedCreditRate      = "PartnerCreditRate",
        PartnerTenantId              = "PartnerId",
        PaygCostInBillingCurrency    = "tmp_ListCost",
        PaygCostInUsd                = "tmp_ListCostInUsd",
        PayGPrice                    = "tmp_ListPrice",
        PricingCurrency              = "tmp_PricingCurrency",
        PricingModel                 = "tmp_PricingModel",
        Product                      = "ProductName",
        ProductCategory              = "ServiceFamily",
        PublisherName                = "tmp_PublisherName",
        ResellerMpnId                = "ResellerId",
        ReservationId                = "tmp_ReservationId",
        ReservationName              = "tmp_ReservationName",
        ResourceGroup                = "ResourceGroupName",
        ResourceLocation             = "tmp_ResourceLocation",
        ResourceName                 = "tmp_ResourceName",
        ResourceRate                 = "tmp_OnDemandPrice",
        SubscriptionGuid             = "SubscriptionId",
        UnitPrice                    = "tmp_OnDemandPrice",
        UsageDateTime                = "Date",
        UsageQuantity                = "Quantity",
        // Colums to remove
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
        {"BillingPeriodEndDate",   type date},
        {"BillingPeriodStartDate", type date},
        {"Date",                   type date},
        {"ServicePeriodEndDate",   type date},
        {"ServicePeriodStartDate", type date},
        {"tmp_ExchangeRateDate",   type date},
        // Price columns
        {"EffectivePrice",         type number},
        {"tmp_ListPrice",          type number},
        {"tmp_OnDemandPrice",      type number},
        // Cost columns
        {"AmortizedCostInUsd",     type number},
        {"AmortizedPricingCost",   type number},
        {"BilledCostInUsd",        type number},
        {"BilledPricingCost",      type number},
        {"tmp_ListCost",           type number},
        {"tmp_ListCostInUsd",      type number},
        // Other columns
        {"PartnerCreditRate",      type number},
        {"Quantity",               type number},
        {"Term",                   type number},
        {"tmp_ExchangeRate",       type number}
        // TODO: {"IsAzureCreditEligible", type logical}
        // TODO: {"PartnerCreditApplied",   type logical}
    }),

    // Transform metadata
// TODO: Add more thorough schema/account validation + use real API versions
    Schema =  Table.AddColumn(FixTypes, "SchemaVersion",
        each if Table.HasColumns(input, "DepartmentName")   then "MG_2023-09"
        else if Table.HasColumns(input, "SubscriptionGuid") then "MOSA_2023-09"
        else if Table.HasColumns(input, "BillingAccountId") then "EA_2023-09"
        else if Table.HasColumns(input, "partnerTenantId") and [partnerName] <> "" then "MPA_2023-09"
        else if Table.HasColumns(input, "billingAccountId") then "MCA_2023-09"
        else "Unknown_2023-09"
    ),
    AccountType = Table.AddColumn(Schema, "AccountType", each Text.Split([SchemaVersion], "_"){0}),

    // Helper functions
    _isBlank       = (val) => val = null or val = "",
    _isNotBlank    = (val) => _isBlank(val) = false,
    _isPositive    = (val) => val <> null and val > 0,
    _isNotPositive = (val) => val = null or val <= 0,
    _swapCol       = (tbl, oldCol, newCol, newVal, optional newType) => let add = Table.AddColumn(tbl, newCol, newVal, newType), del = if Table.HasColumns(add, oldCol) then Table.RemoveColumns(add, {oldCol}) else add in del,
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

    tmp_DefenderFor         = Table.AddColumn(AccountType,     "tmp_DefenderFor", each if Text.StartsWith([ProductName], "Microsoft Defender for") then Text.Range([ProductName], 23, Text.PositionOf([ProductName], "-") - 24) else null),
    tmp_RPName              = Table.AddColumn(tmp_DefenderFor, "tmp_RPName",      each Text.Replace(Text.Replace(Text.Lower([ConsumedService]), "microsoft.classic", ""), "microsoft.", "")),

    // Parse tags
    TagsDictionary          = Table.AddColumn(tmp_RPName,      "TagsDictionary",  each if _isNotBlank([Tags]) then Json.Document(if Text.StartsWith([Tags], "{") then [Tags] else "{" & [Tags] & "}") else null),
    TagsDictionary_errors   = Table.ReplaceErrorValues(TagsDictionary, {{"TagsDictionary", null}}),

    // Parse AddlInfo
    AddlInfoDict            = Table.AddColumn(TagsDictionary_errors, "AdditionalInfoDictionary", each if _isNotBlank([AdditionalInfo]) then Json.Document([AdditionalInfo]) else null),
    AddlInfoDict_errors     = Table.ReplaceErrorValues(AddlInfoDict, {{"AdditionalInfoDictionary", null}}),
    AddlInfoDict_expand     = Table.ExpandRecordColumn(AddlInfoDict_errors, "AdditionalInfoDictionary",
        {"UsageType",        "ImageType",        "ServiceType", "VMName",     "VMProperties",        "VCPUs",       "ReservationOrderId",         "ReservationId",         "VMCapacityReservationId", "AHB",        "vCores"},
        {"ProductUsageType", "ProductImageType", "ProductSKU",  "tmp_VMName", "ProductVMProperties", "tmp_VMvCPUs", "tmp_AddlReservationOrderId", "tmp_AddlReservationId", "CapacityCommitmentId",    "tmp_SQLAHB", "tmp_SQLvCores"}
    ),
    AddlInfoDict_types      = Table.TransformColumnTypes(AddlInfoDict_expand, {{"tmp_VMvCPUs", Int64.Type}, {"tmp_SQLvCores", Int64.Type}}),

    // Transform placeholder columns
    ExchangeRate            = _swapCol(AddlInfoDict_types,     "tmp_ExchangeRate",     "ExchangeRate",     each if _isNotPositive([tmp_ExchangeRate]) then 1                        else [tmp_ExchangeRate],       type number),
    ExchangeRateDate        = _swapCol(ExchangeRate,           "tmp_ExchangeRateDate", "ExchangeRateDate", each if _isBlank([tmp_ExchangeRateDate])   then [BillingPeriodStartDate] else [tmp_ExchangeRateDate],   type date),
    PricingCurrency         = _swapCol(ExchangeRateDate,       "tmp_PricingCurrency",  "PricingCurrency",  each if _isBlank([tmp_PricingCurrency])    then [BillingCurrency]        else [tmp_PricingCurrency]),
    PricingModel            = _swapCol(PricingCurrency,        "tmp_PricingModel",     "PricingModel",     each if _isNotBlank([tmp_PricingModel])    then [tmp_PricingModel]       else if _isNotBlank([tmp_ReservationId])    then "Reservation" else if [ConsumedService] = "Microsoft.Capacity" then "SavingsPlan" else "OnDemand"),
    PublisherName           = _swapCol(PricingModel,           "tmp_PublisherName",    "PublisherName",    each if _isNotBlank([tmp_PublisherName])   then [tmp_PublisherName]      else "Microsoft"),
    ResourceLocation        = _swapCol(PublisherName,          "tmp_ResourceLocation", "ResourceLocation", each
// TODO: Region = Unassigned
        if Text.StartsWith([ChargeType], "Unused") and [tmp_ResourceLocation] = "Unassigned" then "Global"
        else if [ChargeType] = "RoundingAdjustment"                                          then "Global"
        else if [tmp_ResourceLocation] = "All Regions"                                       then "Global"
        else if _isNotBlank([tmp_DefenderFor]) and _isBlank([tmp_ResourceLocation])          then "Global"
        else if _isBlank([tmp_ResourceLocation])                                             then null
        else _regionCleanup([tmp_ResourceLocation])
    ),
// TODO: Parse ResourceName
// TODO: VMName???
    ResourceName            = _swapCol(ResourceLocation,       "tmp_ResourceName",     "ResourceName",           each if _isNotBlank([tmp_ResourceName])    then [tmp_ResourceName]       else if _isNotBlank([tmp_DefenderFor])      then "Microsoft Defender for " & [tmp_DefenderFor] else if [ChargeType] = "Purchase" and [tmp_ReservationName] <> "" then [tmp_ReservationName] else null),
// TODO: Parse ResourceType

    // Columns from AddlInfo -- Must be after ResourceName cleanup
    ResourceMachineName = _swapCol(ResourceName, "tmp_VMName", "ResourceMachineName", each if _isNotBlank([tmp_VMName]) then [tmp_VMName] else null),
    ProductCPUs         = Table.AddColumn(ResourceMachineName, "ProductCPUs",         each if [tmp_VMvCPUs] <> null then [tmp_VMvCPUs] else if [tmp_SQLvCores] <> null then [tmp_SQLvCores] else null, Int64.Type),
    CPUHours            = Table.AddColumn(ProductCPUs,         "CPUHours",            each if [ProductCPUs] <> null then [ProductCPUs] * [Quantity] else null, type number),
    HybridBenefitStatus = Table.AddColumn(CPUHours,            "HybridBenefitStatus", each if _isNotBlank([MeterSubCategory]) and Text.Contains([MeterSubCategory], "Windows") or [tmp_SQLAHB] = "False" then "Not enabled" else if (_isNotBlank([ProductImageType]) and Text.Contains([ProductImageType], "Windows Server BYOL")) or [tmp_SQLAHB] = "True" or (_isNotBlank([MeterSubCategory]) and Text.Contains([MeterSubCategory], "Azure Hybrid Benefit")) then "Enabled" else "Not supported"),
    HybridBenefitCPUs   = Table.AddColumn(HybridBenefitStatus, "HybridBenefitCPUs",   each if [ProductCPUs] = null then 0 else if [ProductCPUs] <= 8 then 8 else if [ProductCPUs] <= 16 then 16 else if [ProductCPUs] = 20 then 24 else if [ProductCPUs] > 20 then [ProductCPUs] else 0, type number),
// TODO: Add SQL AHB handling
    AHB = HybridBenefitCPUs,

    // Commitment columns -- Must be after AHB and PricingModel cleanup
    CommitmentDiscounKey           = Table.AddColumn(AHB,                         "CommitmentDiscounKey",           each [ProductSKU] & [MeterId]),
// TODO: Add ReservationOrderId from AddlInfo
    CommitmentDiscountId           = _swapCol(CommitmentDiscounKey, "tmp_BenefitId",   "CommitmentDiscountId",      each if _isNotBlank([tmp_BenefitId])       then [tmp_BenefitId]          else if _isNotBlank([tmp_ReservationId])   then (if [tmp_ReservationId] <> [tmp_AddlReservationId] then [tmp_ReservationId] else "/providers/Microsoft.Capacity/reservationOrders/" & [tmp_AddlReservationOrderId] & "/reservations/" & [tmp_AddlReservationId]) else null),
    CommitmentDiscountName         = _swapCol(CommitmentDiscountId, "tmp_BenefitName", "CommitmentDiscountName",    each if _isNotBlank([tmp_BenefitName])     then [tmp_BenefitName]        else if _isNotBlank([tmp_ReservationName]) then [tmp_ReservationName] else null),
    CommitmentDiscountProgram      = Table.AddColumn(CommitmentDiscountName,      "CommitmentDiscountProgram",      each if [PricingModel] = "Reservation" then "Reservation" else if [PricingModel] = "SavingsPlan" then "Savings plan" else null),
    CommitmentUtilizationAmount    = Table.AddColumn(CommitmentDiscountProgram,   "CommitmentUtilizationAmount",    each if [ChargeType] = "Usage" and [PricingModel] = "Reservation" then [Quantity] else if [ChargeType] = "Usage" and [PricingModel] = "SavingsPlan" then [AmortizedCost] else 0, type number),
    CommitmentUtilizationPotential = Table.AddColumn(CommitmentUtilizationAmount, "CommitmentUtilizationPotential", each if [PricingModel] = "SavingsPlan" then [AmortizedCost] else if [PricingModel] = "Reservation" then [Quantity] else 0, type number),
    Commitments = CommitmentUtilizationPotential,

    // Pricing columns
    OnDemandPrice           = _swapCol(Commitments,   "tmp_OnDemandPrice", "OnDemandPrice", each (if [tmp_OnDemandPrice] <> null and [tmp_OnDemandPrice] > 0.0 then [tmp_OnDemandPrice] else [EffectivePrice]),            type number),
    ListPrice               = _swapCol(OnDemandPrice, "tmp_ListPrice",     "ListPrice",     each (if [tmp_ListPrice]     <> null and [tmp_ListPrice]     > 0.0 then [tmp_ListPrice]     else [OnDemandPrice]),             type number),
    ListCost                = _swapCol(ListPrice,     "tmp_ListCost",      "ListCost",      each (if [tmp_ListCost]      <> null and [tmp_ListCost]      > 0.0 then [tmp_ListCost]      else [ListPrice] * [Quantity]),    type number),
    ListCostInUsd           = _swapCol(ListCost,      "tmp_ListCostInUsd", "ListCostInUsd", each (if [tmp_ListCostInUsd] <> null and [tmp_ListCostInUsd] > 0.0 then [tmp_ListCostInUsd] else [ListCost] * [ExchangeRate]), type number),
    OnDemandCost            = Table.AddColumn(ListCostInUsd,        "OnDemandCost",         each [Quantity] * [OnDemandPrice],       type number),
    OnDemandPriceSavings    = Table.AddColumn(OnDemandCost,         "OnDemandPriceSavings", each [OnDemandPrice] - [EffectivePrice], type number),
    ListPriceSavings        = Table.AddColumn(OnDemandPriceSavings, "ListPriceSavings",     each [ListPrice] - [EffectivePrice],     type number),
    CommitmentSavings       = Table.AddColumn(ListPriceSavings,     "CommitmentSavings",    each if [PricingModel] <> "Reservation" and [PricingModel] <> "SavingsPlan" then 0 else [OnDemandCost]-[AmortizedCost], type number),
    NegotiatedSavings       = Table.AddColumn(CommitmentSavings,    "NegotiatedSavings",    each if [CommitmentSavings] <> 0 then 0 else [ListCost]-[OnDemandCost], type number),
    DiscountSavings         = Table.AddColumn(NegotiatedSavings,    "DiscountSavings",      each [ListCost]-[AmortizedCost], type number),

    // Unique names -- Must be after ResourceName cleanup and Commitment columns
// TODO: Only add differentiators when the name is not unique
    CommitmentDiscountNameUnique = Table.AddColumn(DiscountSavings,              "CommitmentDiscountNameUnique", each if _isBlank([CommitmentDiscountName]) then null else [CommitmentDiscountName] & " (" & [CommitmentDiscountProgram] & ")"),
// TODO: Change ResourceName differentiator to be the type
    ResourceNameUnique           = Table.AddColumn(CommitmentDiscountNameUnique, "ResourceNameUnique",           each if _isBlank([ResourceName])           then null else [ResourceName] & " (" & [ResourceId] & ")"),
    ResourceGroupNameUnique      = Table.AddColumn(ResourceNameUnique,           "ResourceGroupNameUnique",      each if _isBlank([ResourceGroupName])      then null else [ResourceGroupName] & " (" & [SubscriptionName] & ")"),
    SubscriptionNameUnique       = Table.AddColumn(ResourceGroupNameUnique,      "SubscriptionNameUnique",       each if _isBlank([SubscriptionName])       then null else [SubscriptionName] & " (" & [SubscriptionId] & ")"),

    // Month column
    Month = Table.AddColumn(SubscriptionNameUnique, "Month", each Date.StartOfMonth([Date])),

    // Unique key for the record
    _addIdSegment = (val) => (if _isNotBlank(val) then "-" & val else ""),
    ChargeId = Table.AddColumn(Month, "ChargeId", each Text.Combine(List.RemoveItems({
        Date.ToText([Date]),
        [BillingAccountId],
        if [BillingProfileId] = [BillingAccountId] then null else [BillingProfileId], // Only add BP if not the same as the BA (all EA)
        [InvoiceSectionId],
        if _isNotBlank([ResourceId]) and Text.Contains([ResourceId], [SubscriptionId]) then null else [SubscriptionId], // Only add sub if not in the resource ID
        [ResourceId],
        [ResourceLocation],
        [OfferId],
        [ProductId],
        [MeterId],
        [PartNumber],
        if _isBlank([CommitmentDiscountId])        then null else List.Last(Text.Split([CommitmentDiscountId], "/")),
        [CostAllocationRuleName],
        [CostCenter],
        if _isBlank([Tags])                        then null else Text.Remove([Tags], {"{","""","}"}),
        if _isBlank([AdditionalInfo])              then null else Text.Remove([AdditionalInfo], {"{","""","}"})
    }, {null, ""}), "-")),

    // Cleanup
    // FOCUS ServiceName
    ServiceName = Table.AddColumn(ChargeId, "focus_ServiceName", each
        if [tmp_DefenderFor] <> null then (
            if [tmp_DefenderFor] = "DNS"                   then "Azure DNS"
            else if [tmp_DefenderFor] = "MySQL"            then "Azure Database for MySQL"
            else if [tmp_DefenderFor] = "Resource Manager" then "Azure Resource Manager"
            else if [tmp_DefenderFor] = "Servers"          then "Virtual Machines"
            else if [tmp_DefenderFor] = "SQL"              then "Azure SQL Database"
            else [tmp_DefenderFor]
        )
// TODO: Need a better check for AKS RG names
        else if _isNotBlank([ResourceGroupName]) and ((Text.StartsWith(Text.Lower([ResourceGroupName]), "mc_") and Text.EndsWith(Text.Lower([ResourceGroupName]), "_"&Text.Lower(Text.Replace([ResourceLocation], " ", "")))) or (_isNotBlank([ProductVMProperties]) and Text.Contains([ProductVMProperties], "Microsoft.AKS"))) then "Azure Kubernetes Service"
        else if [tmp_RPName] = "capacity"                then if Text.StartsWith(Text.Lower([ResourceId]), "/providers/microsoft.billingbenefits/savingsplan") then "Azure Savings Plans for Compute" else if [MeterCategory] <> "" then [MeterCategory] else "Azure Reservations"
        else if [tmp_RPName] = "compute"                 then "Virtual Machines"
        else if [tmp_RPName] = "dbformariadb"            then "Azure Database for MariaDB"
        else if [tmp_RPName] = "dbformysql"              then "Azure Database for MySQL"
        else if [tmp_RPName] = "dbforpostgresql"         then "Azure Database for PostgreSQL"
        else if [tmp_RPName] = "insights"                then "Azure Monitor"
        else if [tmp_RPName] = "keyvault"                then "Key Vault"
        else if [tmp_RPName] = "machinelearningservices" then "Azure Machine Learning"
        else if [tmp_RPName] = "operationalinsights"     then "Azure Monitor"
        else if [tmp_RPName] = "sql"                     then [MeterCategory]
        else if [tmp_RPName] = "storage"                 then "Storage Accounts"
        else if [tmp_RPName] = "synapse"                 then "Azure Synapse Analytics"
        else if [tmp_RPName] = "web"                     then "App Service"
        else if [PublisherType] = "Marketplace" and ([MeterCategory] = "SaaS" or [MeterCategory] = "Azure Applications") then [MeterSubCategory]
        else if Table.HasColumns(input, "ServiceName") then [ServiceName]
        else [MeterCategory]
    ),

    // FOCUS ServiceCategory
    ServiceCategory = Table.AddColumn(ServiceName, "focus_ServiceCategory", each
        if [focus_ServiceName] = "Functions"                            then "Compute"
        else if [focus_ServiceName] = "App Service"                     then "Web"
        else if [focus_ServiceName] = "Azure DNS"                       then "Networking"
        else if [focus_ServiceName] = "Azure Kubernetes Service"        then "Compute"
        else if [focus_ServiceName] = "Azure Resource Manager"          then "Management and Governance"
        else if [focus_ServiceName] = "Azure Savings Plans for Compute" then "Compute"
        else if [focus_ServiceName] = "Backup"                          then "Storage"
        else if [focus_ServiceName] = "Virtual Machines"                then "Compute"
        else if [tmp_RPName] = "api management"                   then "Integration"
        else if [tmp_RPName] = "appconfiguration"                 then "Web"
        else if [tmp_RPName] = "compute"                          then "Compute"
        else if [tmp_RPName] = "containerinstance"                then "Compute"
        else if [tmp_RPName] = "containerservice"                 then "Compute"
        else if [tmp_RPName] = "datafactory"                      then "Integration"
        else if [tmp_RPName] = "dbformysql"                       then "Databases"
        else if [tmp_RPName] = "dbforpostgressql"                 then "Databases"
        else if [tmp_RPName] = "digitaltwins"                     then "Internet of Things"
        else if [tmp_RPName] = "eventgrid"                        then "Integration"
        else if [tmp_RPName] = "insights"                         then "Management and Governance"
        else if [tmp_RPName] = "keyvault"                         then "Security"
        else if [tmp_RPName] = "loadtestservice"                  then "Developer Tools"
        else if [tmp_RPName] = "logic"                            then "Integration"
        else if [tmp_RPName] = "machinelearningservices"          then "AI and Machine Learning"
        else if [tmp_RPName] = "network"                          then "Networking"
        else if [tmp_RPName] = "operationalinsights"              then "Management and Governance"
        else if [tmp_RPName] = "recoveryservices"                 then "Management and Governance"
        else if [tmp_RPName] = "search"                           then "Web"
        else if [tmp_RPName] = "security"                         then "Security"
        else if [tmp_RPName] = "servicebus"                       then "Integration"
        else if [tmp_RPName] = "storagesync"                      then "Storage"
        else if [tmp_RPName] = "sql"                              then "Databases"
        else if [tmp_RPName] = "storage"                          then "Storage"
        else if [tmp_RPName] = "synapse"                          then "Analytics"
        else if [tmp_RPName] = "virtual network"                  then "Networking"
        else if [tmp_RPName] = "web"                              then "Web"
        else if Text.Contains(Text.Lower([focus_ServiceName]), "quantum")  then "Compute"
        else if Text.Contains(Text.Lower([focus_ServiceName]), "redis")    then "Storage"
        else if Text.Contains(Text.Lower([focus_ServiceName]), "sendgrid") then "Web"
        else if [MeterCategory] = "RoundingAdjustment"            then "Other"
        else "Other"
    ),

    // Clean up temp columns and re-sort
    RemoveColumns = Table.RemoveColumns(ServiceCategory, {"tmp_AddlReservationOrderId", "tmp_AddlReservationId", "tmp_DefenderFor", "tmp_ReservationId", "tmp_ReservationName", "tmp_RPName", "tmp_SQLAHB", "tmp_SQLvCores", "tmp_VMvCPUs"}),
    Output = Table.ReorderColumns(RemoveColumns, List.Sort(Table.ColumnNames(RemoveColumns)))
in
    Output