// TODO: Make sure you delete this comment and comment out the "VS Code:" line below before using in Power BI. You will get an "Account URL is not valid" error if you don't.
(optional datasets, optional DoNotNormalize) =>
let
    // datasets -- Allowed values: 0 = actual, 1 = amortized, 2 = both
    // DoNotNormalize -- For testing only; true/false

    // VS Code: Uncomment for intellisense in VS Code, but do not include in Power BI reports --
    ftk_CMConnector = () => "", ftk_NormalizeSchema = () => "", #"Data Source" = "FinOps hubs", #"Storage URL" = "", #"File Type" = "", #"RangeStart" = null, #"RangeEnd" = null,

// TODO: Remove SourceType
    SourceType = #"Data Source",
    Connector = ftk_CMConnector(),

    // Helper functions
    _isBlank = (val) => val = null or val = "",
    _capitalizeAndSortColumns = (tbl) =>
        let
            _capitalize = (text) => Text.Upper(Text.Start(text, 1)) & Text.Range(text, 1),
            _original = Table.ColumnNames(tbl),
            _updated = List.Transform(_original, each _capitalize(_)),
            Capitalized = Table.RenameColumns(tbl, List.Zip({_original, _updated})),
            Sorted = Table.SelectColumns(Capitalized, List.Sort(Table.ColumnNames(Capitalized)))
        in
            Sorted
    ,
    _renameCost = (tbl, primaryCol, secondaryCol, secondaryValFunc) => if tbl = null then null else
        let
            _colName     = (col, var) => Text.Replace(col, "Cost", var),
            _hasPricing  = Table.HasColumns(tbl, "CostInPricingCurrency"),
            _hasUsd      = Table.HasColumns(tbl, "CostInUsd"),
            _pricingCol1 = _colName(primaryCol,   "PricingCost"),
            _pricingCol2 = _colName(secondaryCol, "PricingCost"),
            _usdCol1     = _colName(primaryCol,   "CostInUsd"),
            _usdCol2     = _colName(secondaryCol, "CostInUsd"),

            RenamePrimary = Table.RenameColumns(tbl, {
                { (if Table.HasColumns(tbl, "CostInBillingCurrency") then "CostInBillingCurrency" else if Table.HasColumns(tbl, "Cost") then "Cost" else "PreTaxCost"), primaryCol },
                { "CostInPricingCurrency", _pricingCol1 },
                { "CostInUsd",             _usdCol1 }
            }, MissingField.UseNull),
            PrimaryTypes  = Table.TransformColumnTypes(RenamePrimary, {{ primaryCol, type number }, { _pricingCol1, type number }, { _usdCol1, type number }}),

            // Add secondary cost columns
            SecondaryBillingCurrency = Table.AddColumn(PrimaryTypes,             secondaryCol, secondaryValFunc(primaryCol),                                                 type number),
            SecondaryPricingCurrency = Table.AddColumn(SecondaryBillingCurrency, _pricingCol2, if _hasPricing then secondaryValFunc("CostInPricingCurrency") else each null, type number),
            SecondaryUsdCurrency     = Table.AddColumn(SecondaryPricingCurrency, _usdCol2,     if _hasUsd     then secondaryValFunc("CostInUsd")             else each null, type number)
        in
            SecondaryUsdCurrency
    ,

    AmortizedData = if datasets = 0 then null else
        let
            Data = if SourceType <> "FinOps hubs" then Connector{[Key="usagedetailsamortized"]}[Data] else
                // Load from hub
                let
                    // Default values
                    url   = #"Storage URL",
                    ext   = if Text.Length(#"File Type") > 0 then #"File Type" else ".parquet",
                    start = RangeStart,
                    end   = RangeEnd,

                    Hub = AzureStorage.DataLake(url),
                    FilterHiddenFiles = Table.SelectRows(Hub, each [Attributes]?[Hidden]? <> true),

                    // Parse folder path
                    Metric            = Table.AddColumn(FilterHiddenFiles, "Metric", each List.Last(List.RemoveLastN(Text.Split([Folder Path],"/"), 1))),
                    DateRange         = Table.AddColumn(Metric,            "Range",  each List.Last(List.RemoveLastN(List.RemoveLastN(Text.Split([Folder Path],"/"), 1), 1) )),
                    SplitDates        = Table.SplitColumn(DateRange,       "Range",  Splitter.SplitTextByDelimiter("-", QuoteStyle.Csv), {"StartDate", "EndDate"}),
// TODO: Will this work in 0.2 with the shorter paths (yyyyMM)?
                    SplitDates_type   = Table.TransformColumnTypes(SplitDates, {{"StartDate", type date}, {"EndDate", type date}}),

                    // Only amortized costs
                    FilterFilesByMetricAndFileType = Table.SelectRows(SplitDates_type, each [Metric] = "amortizedcost" and [Extension] = ext),

                    // Only process files for months within the date range
                    FilterFilesByDate =
                        if start = null and end = null then FilterFilesByMetricAndFileType
                        else Table.SelectRows(FilterFilesByMetricAndFileType, each (start = null or [StartDate] >= Date.StartOfMonth(Date.From(start))) and (end = null or [EndDate] <= Date.EndOfMonth(Date.From(end)))),

                    // Extract
                    unpack = (zipData) => Table.PromoteHeaders(Csv.Document(Binary.Decompress(zipData, Compression.GZip), [Delimiter=",", Columns=60, Encoding=1252, QuoteStyle=QuoteStyle.Csv, CsvStyle=CsvStyle.QuoteAlways]), [PromoteAllScalars=true]),
                    SelectContent = Table.SelectColumns(FilterFilesByDate, {"Content"}),
                    UnpackContent = Table.AddColumn(SelectContent, "Custom", each if ext = ".gz" then unpack([Content]) else Parquet.Document([Content])),
                    ExpandedColumns = Table.ExpandTableColumn(UnpackContent, "Custom", List.Sort(Table.ColumnNames(List.First(UnpackContent[Custom], null)))),
                    RemovedContent = Table.RemoveColumns(ExpandedColumns, {"Content"}),

                    // Only pull from the predefined date range (if specified)
                    tbl = RemovedContent,
                    FilterRowsByDate =
                        if start = null and end = null then tbl
                        else Table.SelectRows(tbl, each
                            (start = null or (if Table.HasColumns(tbl, "Date") then Date.From([Date]) else Date.From([date])) >= Date.From(start))
                            and (end = null or (if Table.HasColumns(tbl, "Date") then Date.From([Date]) else Date.From([date])) < Date.From(end))
                        )
                in
                    FilterRowsByDate
            ,
            DataSet       = if Data = null then null else Table.AddColumn(_capitalizeAndSortColumns(Data), "DataSet", each "AmortizedCost"),
            AmortizedCost = _renameCost(DataSet, "AmortizedCost", "BilledCost", (col) => each
                if (_isBlank([ReservationId])
                    and [PricingModel] <> "Reservation"
                    and [PricingModel] <> "SavingsPlan"
                    and Text.Lower([ConsumedService]) <> "microsoft.capacity"
                    and (Table.HasColumns(DataSet, "BenefitId") = false or _isBlank([BenefitId]))
                ) then Record.Field(_, col) else 0.0)
        in
            AmortizedCost
    ,

    BilledData = if Connector = null or datasets = 1 then null else
        let
            // Pull actual cost from connector, filter down to commitment purcahses
            Data                    = Connector{[Key="usagedetails"]}[Data],
            DataSet                 = Table.AddColumn(Data, "DataSet", each "ActualCost"),
            CommitmentPurchasesOnly =
                if datasets = 0 then
                    // Don't filter if only using the actual dataset
                    DataSet
                else if Table.HasColumns(DataSet, "ChargeType") then
                    Table.SelectRows(DataSet, each ([ChargeType] = "Purchase" or [ChargeType] = "Refund") and ([PricingModel] = "Reservation" or [PricingModel] = "SavingsPlan" or Text.Lower([ConsumedService]) = "microsoft.capacity"))
                else
                    // If no ChargeType, then there aren't any commitment purchases
                    null
            ,
            BilledCost = _renameCost(CommitmentPurchasesOnly, "BilledCost", "AmortizedCost", (col) => each 0.0)
        in
            BilledCost
    ,

    // Join actual and amortized datasets
    _normalize = (tbl) => if (DoNotNormalize <> null and DoNotNormalize = true) or tbl = null then tbl else ftk_NormalizeSchema(tbl),
    Output = Table.Combine(List.RemoveNulls({_normalize(AmortizedData), _normalize(BilledData)}))
in
    Output
