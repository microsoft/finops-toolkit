// TODO: Make sure you delete this comment and comment out the "VS Code:" line below before using in Power BI. You will get an "Account URL is not valid" error if you don't.
(optional dataset) =>
let
    // VS Code: Uncomment for intellisense in VS Code, but do not include in Power BI reports --
    AzureCostManagement.Tables = () => "", #"Billing Account ID" = "123", #"Billing Profile ID" = "", #"Number of Months" = 3,

    ba = #"Billing Account ID",
    bp = #"Billing Profile ID",
    mo = #"Number of Months",
    IsMCA = ba <> null and Text.Contains(ba, "-"),
    Scope =
        if ba = null then null
        else if IsMCA then "/providers/Microsoft.Billing/billingAccounts/" & ba & (if Text.Length(bp) = 0 then "" else ("/billingProfiles/" & bp))
        else if Text.Length(ba) > 0 then ba
        else null,
    Connector = if Scope = null then null else AzureCostManagement.Tables((if IsMCA then "Manually Input Scope" else "Enrollment Number"), Scope, mo, []),
    Data = if dataset = "" or dataset = null then Connector else Connector{[Key=dataset]}[Data]
in
    Data
