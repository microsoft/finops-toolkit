// TODO: Make sure you delete this comment and comment out the "VS Code:" line below before using in Power BI. You will get an "Account URL is not valid" error if you don't.
(datasetType) =>
let
    // VS Code: Uncomment for intellisense in VS Code, but do not include in Power BI reports --
    #"Storage URL" = "", #"File Type" = "", #"RangeStart" = null, #"RangeEnd" = null,

    // Config
    url     = #"Storage URL",
    ext     = if Text.Length(#"File Type") > 0 then #"File Type" else ".parquet",
    start   = RangeStart,
    end     = RangeEnd,
// TODO: Allow pulling other datasets -- if datasetType = null or datasetType = "" then "focuscost" else datasetType
    dataset = "focuscost",

    ADLS = AzureStorage.DataLake(url),
    FilterHiddenFiles = Table.SelectRows(ADLS, each [Attributes]?[Hidden]? <> true),

    // Parse folder path
    Dataset   = Table.AddColumn(FilterHiddenFiles, "Dataset",   each List.Last(List.RemoveLastN(Text.Split([Folder Path],"/"), 1))),
    Month     = Table.AddColumn(Dataset,           "Month",     each List.Last(List.RemoveLastN(List.RemoveLastN(Text.Split([Folder Path],"/"), 1), 1) )),
// TODO: Update date handling for raw exports
    StartDate = Table.AddColumn(Month,             "StartDate", each [Month] & "01"),
    StartDate_type = Table.TransformColumnTypes(StartDate, {{"StartDate", type date}}),
    EndDate   = Table.AddColumn(StartDate_type,    "EndDate",   each Date.EndOfMonth([StartDate])),

    // Only FOCUS costs
// TODO: Get metric from the manifest
    FilterFilesByMetricAndFileType = Table.SelectRows(EndDate, each [Dataset] = dataset and [Extension] = ext),

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
            (start = null or [ChargePeriodEnd] >= DateTime.From(start))
            and (end = null or [ChargePeriodStart] < DateTime.From(end))
        ),

    // TODO: Extract from the manifest
    _armResourceName = (id) => List.Last(Text.Split(id, "/")),
    DataSet = Table.AddColumn(FilterRowsByDate, "x_DatasetType", each "FocusCost"),
    Schema =  Table.AddColumn(DataSet, "x_DatasetVersion", each "1.0-preview(v1)"),
    AccountType = Table.AddColumn(Schema, "x_AccountType", 
        each if [BillingAccountId] = [SubAccountId] then "MOSA"
        else if _armResourceName([BillingAccountId]) = [x_BillingAccountId] then "EA"
        else if _armResourceName([BillingAccountId]) = [x_BillingProfileId] then (if [InvoiceIssuerName] = "Microsoft" then "MCA" else "MPA")
        else "Unknown"
    ),

    Output = AccountType
in
    Output