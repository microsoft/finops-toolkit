(fileContents) =>
let
  m = Parquet.Metadata(fileContents) as any,
  Navigation = m[RowGroups],
  #"Expanded Columns" = Table.ExpandTableColumn(Navigation, "Columns", {"MetaData"}, {"MetaData"}),
  #"Expanded MetaData" = Table.ExpandRecordColumn(#"Expanded Columns", "MetaData", {"PathInSchema", "Statistics"}, {"PathInSchema", "Statistics"}),
  #"Expanded PathInSchema" = Table.ExpandListColumn(#"Expanded MetaData", "PathInSchema"),
  #"Filtered rows" = Table.SelectRows(#"Expanded PathInSchema", each ([PathInSchema] = "ChargePeriodStart")),
  #"Expanded Statistics" = Table.ExpandRecordColumn(#"Filtered rows", "Statistics", {"MaxValue", "MinValue"}, {"MaxValue", "MinValue"}),
  #"Added min" = Table.AddColumn(#"Expanded Statistics", "Min", each if [MinValue] = null then null else ftk_ImpalaToJulianDate([MinValue])),
  #"Added max" = Table.AddColumn(#"Added min", "Max", each if [MaxValue] = null then null else ftk_ImpalaToJulianDate([MaxValue])),
  #"Removed other columns" = Table.SelectColumns(#"Added max", {"Min", "Max"}),
  #"Removed duplicates" = Table.Distinct(#"Removed other columns")
in
  #"Removed duplicates"