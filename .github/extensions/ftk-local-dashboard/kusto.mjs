// KQL query layer for the FinOps hub local (ftklocal) Kusto emulator.
//
// Talks to the Kusto emulator HTTP API (/v1/rest/query) and parses the v1
// response shape (Tables[0]) into plain row objects. The dashboard queries are
// grounded in the FinOps Framework domains and the FinOps toolkit query
// catalog (src/queries/INDEX.md, KPI.md, finops-hub-database-guide.md).

const DEFAULT_TIMEOUT_MS = 20000;

/**
 * Run a single KQL query against the emulator and return rows as objects.
 * Throws on transport error or Kusto error payload.
 */
export async function runQuery(clusterUri, database, csl, timeoutMs = DEFAULT_TIMEOUT_MS) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    let res;
    try {
        res = await fetch(`${clusterUri.replace(/\/+$/, "")}/v1/rest/query`, {
            method: "POST",
            headers: { "Content-Type": "application/json", Accept: "application/json" },
            body: JSON.stringify({ db: database, csl }),
            signal: controller.signal,
        });
    } catch (err) {
        if (err?.name === "AbortError") {
            throw new Error(`Timed out after ${timeoutMs}ms reaching ${clusterUri}`);
        }
        throw new Error(`Could not reach Kusto emulator at ${clusterUri}: ${err?.message ?? err}`);
    } finally {
        clearTimeout(timer);
    }

    if (!res.ok) {
        const text = await res.text().catch(() => "");
        throw new Error(`Kusto returned HTTP ${res.status}. ${text.slice(0, 300)}`);
    }

    const json = await res.json();
    // v1 query API returns { Tables: [ { TableName, Columns:[{ColumnName}], Rows:[[...]] }, ... ] }
    // An error surfaces as an OneApiErrors / Exceptions payload instead.
    if (json?.error || json?.Exceptions || json?.OneApiErrors) {
        const msg = json?.error?.["@message"] || JSON.stringify(json).slice(0, 300);
        throw new Error(`Kusto query error: ${msg}`);
    }
    const table = Array.isArray(json?.Tables) ? json.Tables[0] : null;
    if (!table) return [];
    const cols = table.Columns.map((c) => c.ColumnName);
    return table.Rows.map((r) => Object.fromEntries(cols.map((c, i) => [c, r[i]])));
}

// --- date helpers (work in UTC to match Kusto datetimes) ----------------------

function startOfMonthUTC(d) {
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));
}
function addMonthsUTC(d, n) {
    return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + n, 1));
}
function isoDay(d) {
    return d.toISOString().slice(0, 10);
}

/**
 * Resolve a preset window (all | 12m | 6m | 3m) against the actual data range.
 * Returns inclusive start and exclusive end ISO-day strings plus the data range.
 */
export async function resolveWindow(clusterUri, database, preset) {
    const range = await runQuery(
        clusterUri,
        database,
        "Costs() | summarize MinDate=min(ChargePeriodStart), MaxDate=max(ChargePeriodStart), Rows=count()"
    );
    const row = range[0] ?? {};
    if (!row.MaxDate) {
        return { start: null, end: null, dataMin: null, dataMax: null, rows: 0, empty: true };
    }
    const dataMin = new Date(row.MinDate);
    const dataMax = new Date(row.MaxDate);
    const endExclusive = addMonthsUTC(startOfMonthUTC(dataMax), 1); // include the whole last month
    const lastMonth = startOfMonthUTC(dataMax);

    let start;
    switch (preset) {
        case "3m": start = addMonthsUTC(lastMonth, -2); break;
        case "6m": start = addMonthsUTC(lastMonth, -5); break;
        case "12m": start = addMonthsUTC(lastMonth, -11); break;
        case "all":
        default: start = startOfMonthUTC(dataMin); break;
    }
    if (start < startOfMonthUTC(dataMin)) start = startOfMonthUTC(dataMin);

    return {
        start: isoDay(start),
        end: isoDay(endExclusive),
        dataMin: isoDay(dataMin),
        dataMax: isoDay(dataMax),
        rows: row.Rows ?? 0,
        empty: false,
    };
}

// --- dashboard data -----------------------------------------------------------

/**
 * Run all dashboard queries in parallel for the resolved window and shape the
 * result into a single payload the renderer consumes.
 */
export async function getDashboard(clusterUri, database, preset = "all") {
    const win = await resolveWindow(clusterUri, database, preset);
    if (win.empty) {
        return { window: win, empty: true, generatedAt: new Date().toISOString() };
    }

    const period = `| where ChargePeriodStart >= datetime(${win.start}) and ChargePeriodStart < datetime(${win.end})`;

    const queries = {
        // KPI totals — Understand Usage & Cost + Quantify Business Value
        summary: `Costs() ${period} | summarize Billed=sum(BilledCost), Effective=sum(EffectiveCost), List=sum(ListCost), Contracted=sum(ContractedCost), Resources=dcount(ResourceId), Services=dcount(ServiceName), Subscriptions=dcount(SubAccountId), Regions=dcount(RegionId), Rows=count()`,
        // Allocation KPI — percentage-untagged-costs
        tagged: `Costs() ${period} | extend _t=iff(isnull(Tags) or array_length(bag_keys(Tags))==0,'Untagged','Tagged') | summarize Cost=sum(EffectiveCost) by _t`,
        // Rate Optimization — commitment coverage (Committed vs Standard pricing)
        pricing: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by PricingCategory`,
        // Reporting & Analytics — monthly-cost-trend (Billed vs Effective)
        trend: `Costs() ${period} | summarize Billed=sum(BilledCost), Effective=sum(EffectiveCost) by Month=format_datetime(startofmonth(ChargePeriodStart),'yyyy-MM') | order by Month asc`,
        // Understand Usage & Cost — cost by service category
        serviceCategory: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by ServiceCategory | where Cost > 0 | order by Cost desc`,
        // top-services-by-cost
        topServices: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by ServiceName | top 10 by Cost desc`,
        // top-resource-groups-by-cost
        topResourceGroups: `Costs() ${period} | where isnotempty(x_ResourceGroupName) | summarize Cost=sum(EffectiveCost) by x_ResourceGroupName | top 10 by Cost desc`,
        // cost-by-region-trend (top regions by cost)
        topRegions: `Costs() ${period} | where isnotempty(RegionId) | summarize Cost=sum(EffectiveCost) by RegionId | top 12 by Cost desc`,
        // Charge category mix (Usage / Purchase / Adjustment)
        chargeCategory: `Costs() ${period} | summarize Cost=sum(EffectiveCost) by ChargeCategory | where Cost != 0 | order by Cost desc`,
        // macc-consumption-vs-commitment — MACC burn rate (graceful: returns CommitmentAmount=0 if no MACC data)
        macc: `let con = toscalar(Costs() ${period} | where not(ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory)) | summarize sum(EffectiveCost));
let com = toscalar(Transactions() | where isnotnull(x_MonetaryCommitment) | summarize sum(x_MonetaryCommitment));
let com0 = coalesce(todouble(com), 0.0);
print ConsumptionAmount=con, CommitmentAmount=com0, CommitmentBurnPercent=iff(com0 > 0, con / com0 * 100.0, 0.0)`,
    };

    const entries = Object.entries(queries);
    const results = await Promise.all(
        entries.map(([, csl]) => runQuery(clusterUri, database, csl))
    );
    const data = Object.fromEntries(entries.map(([key], i) => [key, results[i]]));

    return {
        window: win,
        empty: false,
        data,
        generatedAt: new Date().toISOString(),
    };
}

// --- tokenomics (AI / Azure OpenAI token economics) ---------------------------
//
// Grounded in the FinOps toolkit AI query catalog (ai-token-usage-breakdown,
// ai-model-cost-comparison, ai-daily-trend) and the FinOps Foundation
// "Token Consumption Metrics" KPI (Cost per Token = Total Cost / Tokens Used).
//
// Token meters are scoped to Azure OpenAI subcategories whose SKU description
// is denominated in tokens, which excludes non-token AI meters (image/media,
// Cognitive Search). ConsumedQuantity is the token count per the catalog.
const AI_SCOPE = `| where x_SkuMeterSubcategory has 'OpenAI' and x_SkuDescription contains 'Token'`;

// Direction: descriptions use abbreviations (Inp / Outp / cached Inp), so the
// canonical contains "Input"/"Output" test is replaced with term/substring
// matching that also splits cached input out as its own (cheaper) bucket.
const DIRECTION = `extend Direction = case(
    x_SkuDescription has 'Outp' or x_SkuDescription contains 'Output', 'Output',
    x_SkuDescription contains 'cached', 'Cached input',
    x_SkuDescription has 'Inp' or x_SkuDescription contains 'Input', 'Input',
    'Other')`;

// Collapse verbose SKU descriptions to a clean model family, e.g.
// "Azure OpenAI - gpt 4.1 cached Inp glbl Tokens - US East 2" -> "GPT 4.1".
const MODEL_FAMILY = `extend Model = x_SkuDescription
| extend Model = replace_regex(Model, @'^Azure OpenAI(?: GPT5)?\\s*-\\s*', '')
| extend Model = replace_regex(Model, @'(?i)[\\s-]+(cached[\\s-]+)?(inp|inpt|outp|out|chat|media)([\\s-].*)?$', '')
| extend Model = replace_regex(trim(@'[\\s-]+', Model), @'(?i)^gpt', 'GPT')`;

export async function getTokenomics(clusterUri, database, preset = "all") {
    const win = await resolveWindow(clusterUri, database, preset);
    if (win.empty) {
        return { window: win, empty: true, generatedAt: new Date().toISOString() };
    }
    const period = `| where ChargePeriodStart >= datetime(${win.start}) and ChargePeriodStart < datetime(${win.end})`;

    const queries = {
        // Token KPI totals — Token Consumption Metrics
        summary: `Costs() ${period} ${AI_SCOPE} | summarize Tokens=sum(ConsumedQuantity), Effective=sum(EffectiveCost), List=sum(ListCost), Models=dcount(x_SkuDescription), Resources=dcount(ResourceId), Rows=count()`,
        // Total cloud effective cost in the window — for AI share-of-spend
        totalCloud: `Costs() ${period} | summarize Effective=sum(EffectiveCost)`,
        // ai-token-usage-breakdown — direction mix (input/cached/output)
        direction: `Costs() ${period} ${AI_SCOPE} | ${DIRECTION} | summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Direction`,
        // ai-model-cost-comparison — by model family with cost per 1K tokens
        models: `Costs() ${period} ${AI_SCOPE} | ${MODEL_FAMILY} | summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost), List=sum(ListCost) by Model | extend CostPer1K=iff(Tokens==0, 0.0, Cost/Tokens*1000) | top 12 by Cost desc`,
        // ai-daily-trend (monthly variant) — token volume + AI cost over time
        trend: `Costs() ${period} ${AI_SCOPE} | summarize Tokens=sum(ConsumedQuantity), Cost=sum(EffectiveCost) by Month=format_datetime(startofmonth(ChargePeriodStart),'yyyy-MM') | order by Month asc`,
        // ai-cost-by-application — AI cost showback by app/team/env/cost-center
        byApplication: `Costs() ${period} ${AI_SCOPE}
| extend Application = tostring(Tags['application']), Team = tostring(Tags['team'])
| extend CostCenter = coalesce(tostring(Tags['cost-center']), tostring(Tags['CostCenter']), '')
| extend Environment = tostring(Tags['environment'])
| summarize TokenCount=sum(ConsumedQuantity), EffectiveCost=sum(EffectiveCost)
    by Application, Team, CostCenter, Environment
| extend CostPer1KTokens = iff(TokenCount == 0, 0.0, EffectiveCost / TokenCount * 1000)
| top 12 by EffectiveCost desc`,
    };

    const entries = Object.entries(queries);
    const results = await Promise.all(entries.map(([, csl]) => runQuery(clusterUri, database, csl)));
    const data = Object.fromEntries(entries.map(([key], i) => [key, results[i]]));

    const tokenRows = data.summary?.[0]?.Rows ?? 0;
    return {
        window: win,
        empty: tokenRows === 0,
        data,
        generatedAt: new Date().toISOString(),
    };
}

// --- shared page runner -------------------------------------------------------
// Resolves the window, builds a named map of KQL queries from the period clause,
// runs them in parallel, and returns { window, empty, data, generatedAt }.
async function runPage(clusterUri, database, preset, buildQueries) {
    const win = await resolveWindow(clusterUri, database, preset);
    if (win.empty) return { window: win, empty: true, generatedAt: new Date().toISOString() };
    const period = `| where ChargePeriodStart >= datetime(${win.start}) and ChargePeriodStart < datetime(${win.end})`;
    const queries = buildQueries(period, win);
    const entries = Object.entries(queries);
    const results = await Promise.all(entries.map(([, csl]) => runQuery(clusterUri, database, csl)));
    const data = Object.fromEntries(entries.map(([key], i) => [key, results[i]]));
    return { window: win, empty: false, data, generatedAt: new Date().toISOString() };
}

// --- Allocation page ----------------------------------------------------------
// FinOps "Allocation" capability. Grounded in catalog queries:
// percentage-untagged-costs, percentage-unallocated-costs, tagging-policy-compliance,
// allocation-accuracy-index, cost-by-financial-hierarchy. Tag policy keys are tuned
// to this estate's taxonomy (CostCenter/env/org); allocation evidence also honours
// the enriched x_CostCenter / x_CostAllocationRuleName columns.
const NON_PURCHASE = `| where not(ChargeCategory == 'Purchase' and isnotempty(CommitmentDiscountCategory))`;

export async function getAllocation(clusterUri, database, preset = "all") {
    return runPage(clusterUri, database, preset, (period) => ({
        // Single-pass core: total, untagged, attributed (AAI), compliant
        core: `let req=dynamic(['CostCenter','env','org']);
let ev=dynamic(['cost-center','team','owner','application','product','CostCenter','org','env','Project']);
Costs() ${period} ${NON_PURCHASE}
| extend tk=coalesce(bag_keys(Tags), dynamic([]))
| extend isUntagged = array_length(tk)==0
| extend hasEvidence = isnotempty(x_CostAllocationRuleName) or isnotempty(x_CostCenter) or array_length(set_intersect(tk,ev))>0
| extend isCompliant = array_length(set_intersect(tk,req))==array_length(req)
| summarize Total=sum(EffectiveCost), Untagged=sumif(EffectiveCost,isUntagged), Attributed=sumif(EffectiveCost,hasEvidence), Compliant=sumif(EffectiveCost,isCompliant), Subs=dcount(SubAccountId)`,
        // cost-by-financial-hierarchy (tuned to org/Project/env taxonomy)
        hierarchy: `Costs() ${period}
| extend Org=tostring(Tags['org']), Project=tostring(Tags['Project']), Env=tostring(Tags['env'])
| summarize Cost=sum(EffectiveCost) by Org, Project, Env
| where Cost > 0 | top 12 by Cost desc`,
        // Tag-key coverage — cost touched by each tag key
        tagKeys: `Costs() ${period}
| mv-expand k=bag_keys(Tags) to typeof(string)
| where isnotempty(k) and k !in ('ftk-tool','ftk-version','cm-resource-parent','costanalysis-parent')
| summarize Cost=sum(EffectiveCost) by k
| top 12 by Cost desc`,
        // Cost by subscription (SubAccountName)
        bySubscription: `Costs() ${period} | where isnotempty(SubAccountName) | summarize Cost=sum(EffectiveCost) by SubAccountName | top 10 by Cost desc`,
    }));
}

// --- Rate optimization page ---------------------------------------------------
// FinOps "Rate Optimization" capability. Grounded in catalog queries:
// savings-summary-report, commitment-discount-waste, compute-spend-commitment-coverage,
// commitment-discount-utilization. (cost-optimization-index/COIN is omitted because it
// depends on Recommendations(), which is empty in this estate, so it would always read 100.)
// Commitment utilization is derived as the effective-cost complement of waste, the cleanest
// single-basis definition for a grand-total KPI.
export async function getRate(clusterUri, database, preset = "all") {
    return runPage(clusterUri, database, preset, (period) => ({
        // savings-summary-report — ESR + negotiated/commitment/total savings
        savings: `Costs() ${period} ${NON_PURCHASE}
| extend neg=iff(ListCost<ContractedCost,real(0),ListCost-ContractedCost)
| extend com=iff(ContractedCost<EffectiveCost,real(0),ContractedCost-EffectiveCost)
| extend tot=iff(ListCost<EffectiveCost,real(0),ListCost-EffectiveCost)
| summarize List=sum(ListCost), Effective=sum(EffectiveCost), Negotiated=sum(neg), Commitment=sum(com), Total=sum(tot)`,
        // commitment-discount-waste (grand total, effective-cost basis)
        commitment: `Costs() ${period} | where isnotempty(CommitmentDiscountId) ${NON_PURCHASE}
| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost)`,
        // compute-spend-commitment-coverage
        computeCoverage: `Costs() ${period} ${NON_PURCHASE} | where ServiceCategory=='Compute'
| summarize Committed=sumif(EffectiveCost,isnotempty(CommitmentDiscountCategory)), Contracted=sum(ContractedCost)`,
        // commitment-discount-utilization — consumed core-hours by commitment type
        coreHours: `Costs() ${period}
| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores, 0))
| extend ch=iff(cores>0, cores*ConsumedQuantity, toreal(''))
| extend t=iff(isempty(CommitmentDiscountType),'On Demand',CommitmentDiscountType)
| summarize CoreHours=sum(ch) by t | where CoreHours > 0 | order by CoreHours desc`,
        // Per-commitment waste — which reservations/plans are underutilized
        byCommitment: `Costs() ${period} | where isnotempty(CommitmentDiscountName) ${NON_PURCHASE}
| summarize Unused=sumif(EffectiveCost,CommitmentDiscountStatus=='Unused'), Total=sum(EffectiveCost) by CommitmentDiscountName
| where Unused > 0 | top 10 by Unused desc`,
        // commitment-utilization-score (formal KPI) — per-commitment and grand-total utilization score
        commitmentUtilScore: `let rows = materialize(Costs() ${period} | where isnotempty(CommitmentDiscountId)
| extend Potential = case(ChargeCategory == 'Purchase', toreal(0), isnotempty(CommitmentDiscountCategory), toreal(EffectiveCost), toreal(0))
| extend Amount = iff(CommitmentDiscountStatus == 'Used', Potential, toreal(0)));
let byCommit = rows | summarize Amount=sum(Amount), Potential=sum(Potential) by CommitmentDiscountName, CommitmentDiscountCategory, CommitmentDiscountType
| extend Score = iff(Potential > 0, Amount / Potential * 100.0, 0.0);
union byCommit, (byCommit | summarize Amount=sum(Amount), Potential=sum(Potential)
| extend CommitmentDiscountName='(Grand Total)', CommitmentDiscountCategory='', CommitmentDiscountType='', Score=iff(Potential>0, Amount/Potential*100.0, 0.0))
| project CommitmentDiscountName, CommitmentDiscountCategory, CommitmentDiscountType, Amount, Potential, Score | order by Potential desc`,
        // top-commitment-transactions — largest RI/SP purchases
        topCommitmentTxns: `Costs() ${period} | where ChargeCategory != 'Usage' and isnotempty(CommitmentDiscountType) and BilledCost > 0
| summarize BilledCost=sum(BilledCost), EffectiveCost=sum(EffectiveCost)
    by CommitmentDiscountName, CommitmentDiscountType, CommitmentDiscountCategory
| top 10 by BilledCost desc`,
    }));
}

// --- Usage & unit economics page ----------------------------------------------
// FinOps "Usage Optimization" + "Unit Economics". Grounded in catalog queries:
// compute-cost-per-core, cost-per-gb-stored, storage-tier-distribution, top-resource-types-by-cost.
export async function getUsage(clusterUri, database, preset = "all") {
    return runPage(clusterUri, database, preset, (period) => ({
        // compute-cost-per-core
        compute: `Costs() ${period} ${NON_PURCHASE}
| extend vm = x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses') and ChargeCategory=='Usage'
| extend isComputeCommit = x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses')
| extend cores = iff(vm, toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores)), toint(''))
| extend ch = iff(vm and isnotempty(cores), toreal(cores*ConsumedQuantity), toreal(''))
| summarize ComputeEff=sumif(EffectiveCost,vm), UnusedCommit=sumif(EffectiveCost, CommitmentDiscountStatus=='Unused' and isnotempty(CommitmentDiscountCategory) and isComputeCommit), CoreHours=sum(ch)`,
        // cost-per-gb-stored
        storage: `Costs() ${period} | where ServiceCategory=='Storage' and ChargeCategory=='Usage'
| extend gb = case(ConsumedUnit endswith 'PB', toreal(ConsumedQuantity)*1048576.0, ConsumedUnit endswith 'TB', toreal(ConsumedQuantity)*1024.0, ConsumedUnit endswith 'MB', toreal(ConsumedQuantity)/1024.0, toreal(ConsumedQuantity))
| summarize Cost=sum(EffectiveCost), GBMonths=sum(gb)`,
        // storage-tier-distribution
        storageTiers: `Costs() ${period} | where ServiceCategory=='Storage' and ChargeCategory=='Usage'
| extend Tier = case(
    x_SkuTier in ('Hot','Standard','Premium'), 'Frequent',
    x_SkuTier in ('Cool','Cold','Archive'), 'Infrequent',
    x_SkuMeterSubcategory has_any ('Hot','Standard','Premium','Frequent'), 'Frequent',
    x_SkuMeterSubcategory has_any ('Cool','Cold','Archive'), 'Infrequent',
    'Unclassified')
| summarize Cost=sum(EffectiveCost) by Tier | where Cost > 0 | order by Cost desc`,
        // top-resource-types-by-cost
        topResourceTypes: `Costs() ${period} | where isnotempty(ResourceType) | summarize Count=count(), Cost=sum(EffectiveCost) by ResourceType | top 10 by Cost desc`,
        // compute-cost-per-core grouped by VM series — where the expensive cores are
        perCoreSeries: `Costs() ${period} | where x_SkuMeterCategory in ('Virtual Machines','Virtual Machine Licenses') and ChargeCategory=='Usage'
| extend cores=toint(coalesce(x_SkuDetails.VCPUs, x_SkuDetails.vCores))
| extend ch=iff(isnotempty(cores), toreal(cores*ConsumedQuantity), toreal(''))
| summarize Eff=sum(EffectiveCost), CH=sum(ch) by x_SkuMeterSubcategory
| where CH > 100 | extend PerCore=Eff/CH | top 10 by Eff desc`,
        // grand total for share-of-cost on the resource-type table
        total: `Costs() ${period} | summarize Total=sum(EffectiveCost)`,
    }));
}

// --- Anomalies & forecast page ------------------------------------------------
// FinOps "Anomaly Management" + "Forecasting" + data-freshness (Data Ingestion).
// Grounded in catalog queries: cost-anomaly-detection, anomaly-detection-rate,
// anomaly-variance-total, monthly-cost-change-percentage, cost-forecasting-model,
// data-update-frequency, cost-visibility-delay. Time-series array outputs are
// flattened with mv-expand so the renderer can chart them.
export async function getAnomaly(clusterUri, database, preset = "all") {
    return runPage(clusterUri, database, preset, (period, win) => {
        // forecast uses full history for accuracy; horizon = 4 months past the last data month
        const dmax = new Date(win.dataMax);
        const monthStart = new Date(Date.UTC(dmax.getUTCFullYear(), dmax.getUTCMonth(), 1));
        const horizon = new Date(Date.UTC(dmax.getUTCFullYear(), dmax.getUTCMonth() + 4, 1));
        const isoH = horizon.toISOString().slice(0, 10);
        const fcDays = Math.round((horizon - monthStart) / 86400000);
        return {
            // cost-anomaly-detection + anomaly-variance-total (flattened daily series)
            daily: `let s=datetime(${win.start}); let e=datetime(${win.end});
Costs() | where ChargePeriodStart>=s and ChargePeriodStart<e ${NON_PURCHASE}
| summarize DC=sum(EffectiveCost) by bin(ChargePeriodStart,1d)
| make-series Cost=sum(DC) default=0.0 on ChargePeriodStart from s to e step 1d
| extend (flag,score,baseline)=series_decompose_anomalies(Cost,1.5)
| mv-expand Day=ChargePeriodStart to typeof(datetime), Cost to typeof(real), flag to typeof(real), baseline to typeof(real)
| project Day, Cost=toreal(Cost), Flag=toint(flag), Baseline=toreal(baseline)`,
            // monthly-cost-change-percentage
            monthlyChange: `Costs() ${period} | summarize Eff=sum(EffectiveCost) by M=startofmonth(ChargePeriodStart)
| order by M asc | extend PrevEff=prev(Eff)
| project Month=format_datetime(M,'yyyy-MM'), EffChangePct=iff(isempty(PrevEff),0.0,(Eff-PrevEff)*100.0/PrevEff), Eff`,
            // cost-forecasting-model (monthly, forecasts past the last data month)
            forecast: `let s=datetime(${win.dataMin}); Costs() | where ChargePeriodStart>=s
| summarize Eff=sum(EffectiveCost) by bin(ChargePeriodStart,1d)
| make-series Actual=sum(Eff) default=0.0 on ChargePeriodStart from s to datetime(${isoH}) step 1d
| extend Fc=series_decompose_forecast(Actual,${fcDays})
| mv-expand Day=ChargePeriodStart to typeof(datetime), Actual to typeof(real), Fc to typeof(real)
| extend M=startofmonth(Day)
| summarize Actual=sum(toreal(Actual)), Forecast=sum(toreal(Fc)) by M
| order by M asc | project Month=format_datetime(M,'yyyy-MM'), Actual, Forecast`,
            // data-update-frequency + cost-visibility-delay
            freshness: `Costs() ${period} | where isnotnull(x_IngestionTime)
| summarize LastUpdate=max(x_IngestionTime), Rows=count(), P50=percentile(todouble((x_IngestionTime-ChargePeriodEnd)/1h),50), P90=percentile(todouble((x_IngestionTime-ChargePeriodEnd)/1h),90)`,
        };
    });
}
