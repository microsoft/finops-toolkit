import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import {
    foundryAgentsQuery,
    latencyMetrics,
    requestMetrics,
    supplyQuery,
    supplyViews,
    tokenMetrics,
} from "./queries.mjs";

const workbookDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(workbookDir, "../../..");
const workbook = JSON.parse(readFileSync(resolve(workbookDir, "workbook.json"), "utf8"));
const dashboard = JSON.parse(readFileSync(resolve(repoRoot, "src/templates/finops-hub/dashboard.json"), "utf8"));
const packageVersion = JSON.parse(readFileSync(resolve(repoRoot, "package.json"), "utf8")).version;
const groups = workbook.items.filter((item) => item.type === 12);
const sourceGroups = groups.slice(0, 13);
const descendants = (items) => items.flatMap((item) => [
    item,
    ...descendants(item.content?.items ?? []),
]);
const allItems = descendants(workbook.items);
const sourceItems = descendants(sourceGroups).filter((item) => item.type === 1 || item.type === 3);
const queryItems = allItems.filter((item) => item.type === 3);
const tableItems = queryItems.filter((item) => item.content.visualization === "table");
const parameterItem = workbook.items.find((item) => item.type === 9);
const parameters = parameterItem.content.parameters;
const parameterByName = new Map(parameters.map((parameter) => [parameter.name, parameter]));
const sourceVisualization = (visualType) => {
    const type = visualType.toLowerCase().replace(/\s+/g, "");
    if (type === "table") return "table";
    if (type === "pie") return "piechart";
    if (type === "multistat" || type === "card") return "tiles";
    if (type.includes("bar") || type.includes("column")) return "barchart";
    if (type.includes("line") || type.includes("time") || type.includes("area")) return "timechart";
    return "table";
};
const sourceSize = (visualType) => {
    const type = visualType.toLowerCase();
    if (type === "multistat" || type === "card") return 0;
    if (type === "table") return 3;
    return 2;
};

function expectedSourceQuery(queryId) {
    const queryById = new Map(dashboard.queries.map((query) => [query.id, query]));
    const baseQueryByVariable = new Map(dashboard.baseQueries.map((query) => [query.variableName, query]));
    const parameterNames = new Set(dashboard.parameters.map((parameter) => parameter.variableName));
    const query = queryById.get(queryId);
    const declarations = [];
    const seen = new Set();

    function addDependencies(item) {
        for (const variableId of item.usedVariables ?? []) {
            const baseQuery = baseQueryByVariable.get(variableId);
            if (baseQuery && !seen.has(baseQuery.id)) {
                const definition = queryById.get(baseQuery.queryId);
                addDependencies(definition);
                declarations.push(`let ${baseQuery.variableName} = (\n${definition.text.trim()}\n);`);
                seen.add(baseQuery.id);
            } else if (!baseQuery) {
                assert.ok(parameterNames.has(variableId), `Unknown source variable '${variableId}'.`);
            }
        }
    }

    addDependencies(query);
    return [
        `let numberOfMonths = toint('{numberOfMonths}');
let numberOfDays = toint('{numberOfDays}');
let maxGroupCount = toint('{maxGroupCount}');
let selectedBillingCurrency = '{selectedBillingCurrency}';`,
        ...declarations,
        query.text.trim(),
    ].join("\n\n");
}

test("preserves the source dashboard structure", () => {
    assert.equal(sourceGroups.length, 13);
    assert.equal(sourceItems.length, 158);
    assert.equal(sourceItems.filter((item) => item.type === 1).length, 59);
    assert.equal(sourceItems.filter((item) => item.type === 3).length, 99);
    assert.equal(groups.length, 16);
    assert.ok(sourceItems.every((item) => !item.customWidth || /^\d+$/.test(item.customWidth)));
    assert.deepEqual(
        [...new Set(sourceItems.filter((item) => item.type === 3).map((item) => item.content.size))].sort(),
        [0, 2, 3]
    );
    for (const page of sourceGroups) {
        assert.ok(page.content.items.every((item) => item.type === 12 && item.customWidth === "100"));
        for (const row of page.content.items) {
            const width = row.content.items.reduce((total, item) => total + Number(item.customWidth), 0);
            assert.ok(width === 99 || width === 100);
        }
    }
});

test("preserves every source tile query and visualization mapping", () => {
    for (const [pageIndex, sourcePage] of dashboard.pages.entries()) {
        const expectedTiles = dashboard.tiles
            .filter((tile) => tile.pageId === sourcePage.id)
            .sort((left, right) => left.layout.y - right.layout.y || left.layout.x - right.layout.x);
        const actualTiles = sourceGroups[pageIndex].content.items
            .flatMap((row) => row.content.items);
        assert.equal(actualTiles.length, expectedTiles.length, sourcePage.name);

        for (const [tileIndex, expected] of expectedTiles.entries()) {
            const actual = actualTiles[tileIndex];
            if (expected.markdownText) {
                assert.equal(actual.type, 1, expected.id);
                assert.equal(
                    actual.content.json,
                    expected.markdownText
                        .replaceAll("$$ftkver$$", packageVersion)
                        .replaceAll(" ($$build-month$$)", ""),
                    expected.id
                );
                continue;
            }

            assert.equal(actual.type, 3, expected.id);
            assert.equal(actual.content.title, expected.title, expected.id);
            assert.equal(actual.content.visualization, sourceVisualization(expected.visualType), expected.id);
            assert.equal(actual.content.size, sourceSize(expected.visualType), expected.id);
            const actualQuery = JSON.parse(actual.content.query);
            assert.equal(actualQuery.queryText, expectedSourceQuery(expected.queryRef.queryId), expected.id);
        }
    }
});

test("declares the tab parameter before documented link navigation", () => {
    const parameterIndex = workbook.items.indexOf(parameterItem);
    const navigationIndex = workbook.items.findIndex((item) => item.type === 11);
    const navigation = workbook.items[navigationIndex];
    assert.ok(parameterIndex < navigationIndex);
    assert.equal(parameterByName.get("SelectedTab").value, "about");
    assert.ok(navigation.content.links.every((link) => (
        link.cellValue === "SelectedTab"
        && link.linkTarget === "parameter"
        && link.style === "link"
    )));
    const conditionalGroups = allItems.filter((item) => (
        item.type === 12 && item.conditionalVisibility
    ));
    assert.ok(conditionalGroups.length > sourceGroups.length);
    assert.ok(conditionalGroups.every((group) => group.content.loadType === "lazy"));
    assert.ok(allItems
        .filter((item) => item.type === 12 && !item.conditionalVisibility)
        .every((group) => group.content.loadType === "always"));
    assert.equal(parameterByName.get("SelectedSupplyTab").value, "home");
    assert.equal(parameterByName.get("SelectedTab").isGlobal, true);
    assert.equal(parameterByName.get("SelectedSupplyTab").isGlobal, true);
});

test("uses native Azure Data Explorer query envelopes", () => {
    const adxItems = queryItems.filter((item) => item.content.queryType === 9);
    const supplyPanelCount = supplyViews.reduce((count, view) => count + view.panels.length, 0);
    assert.equal(adxItems.length, 100 + supplyPanelCount);
    for (const item of adxItems) {
        const query = JSON.parse(item.content.query);
        assert.equal(query.version, "AzureDataExplorerQuery/1.0");
        assert.equal(query.clusterName, "{HubClusterName}");
        assert.equal(query.databaseName, "{HubDatabase}");
        assert.ok(query.queryText.length > 0);
    }
});

test("uses full source grids and 50-row Supply detail pages", () => {
    assert.ok(tableItems.length > 0);
    const pagedItems = tableItems.filter((item) => (
        item.content.query.startsWith("{")
        && JSON.parse(item.content.query).queryText.includes("PageRow=row_number()")
    ));
    assert.equal(pagedItems.length, 8);
    assert.ok(pagedItems.every((item) => item.content.gridSettings?.rowLimit === 50));
    assert.ok(tableItems
        .filter((item) => !pagedItems.includes(item))
        .every((item) => item.content.gridSettings?.rowLimit === 10000));
});

test("binds the hub selector to the workbook resource context", () => {
    const hubCluster = parameterByName.get("HubCluster");
    assert.equal(hubCluster.type, 5);
    assert.equal(hubCluster.value, "value::1");
    assert.equal(hubCluster.query, undefined);
    assert.equal(hubCluster.isHiddenWhenLocked, true);
    assert.deepEqual(hubCluster.typeSettings.resourceTypeFilter, {
        "microsoft.kusto/clusters": true,
    });
    assert.deepEqual(hubCluster.typeSettings.additionalResourceOptions, ["value::1"]);

    for (const parameterName of ["HubQueryUri", "HubClusterName"]) {
        const parameter = parameterByName.get(parameterName);
        assert.equal(parameter.queryType, 1);
        assert.equal(parameter.resourceType, "microsoft.resourcegraph/resources");
        assert.deepEqual(parameter.crossComponentResources, ["{HubCluster:subscription}"]);
    }
    assert.equal(parameterByName.get("HubClusterName").isHiddenWhenLocked, undefined);
});

test("uses documented Resource Graph subscription scopes", () => {
    const serialized = JSON.stringify(parameterItem);
    assert.doesNotMatch(serialized, /value::tenant/);
    for (const parameterName of ["TelemetryResources", "FoundryAccounts"]) {
        const parameter = parameterByName.get(parameterName);
        assert.equal(parameter.queryType, 1);
        assert.equal(parameter.resourceType, "microsoft.resourcegraph/resources");
        assert.deepEqual(parameter.crossComponentResources, ["value::selected"]);
    }
    assert.match(parameterByName.get("FoundryAccounts").query, /kind in~ \('OpenAI', 'AIServices'\)/);
    const resourceGraphItems = queryItems.filter((item) => item.content.queryType === 1);
    assert.ok(resourceGraphItems.length > 0);
    assert.ok(resourceGraphItems.every((item) => (
        JSON.stringify(item.content.crossComponentResources) === JSON.stringify(["value::selected"])
    )));
});

test("uses native Azure Data Explorer envelopes for query-backed parameters", () => {
    for (const parameterName of ["numberOfMonths", "selectedBillingCurrency"]) {
        const parameter = parameterByName.get(parameterName);
        assert.equal(parameter.queryType, 9);
        const query = JSON.parse(parameter.query);
        assert.equal(query.version, "AzureDataExplorerQuery/1.0");
        assert.equal(query.clusterName, "{HubClusterName}");
        assert.equal(query.databaseName, "{HubDatabase}");
        assert.ok(query.queryText.length > 0);
    }

    const currencyQuery = JSON.parse(parameterByName.get("selectedBillingCurrency").query);
    assert.doesNotMatch(currencyQuery.queryText, /\{selectedBillingCurrency\}/);
    assert.match(currencyQuery.queryText, /\|\s*project\s+value=BillingCurrency,\s*label=Label,\s*selected$/);
});

test("keeps workspace selection outside KQL", () => {
    const serialized = JSON.stringify(workbook);
    assert.doesNotMatch(serialized, /\/providers\/microsoft\.operationalinsights\/workspaces\//i);
    assert.doesNotMatch(foundryAgentsQuery, /macro-expand|entity_group/i);
    assert.match(foundryAgentsQuery, /todatetime\(\{TimeRange:start\}\)/);
    assert.match(foundryAgentsQuery, /todatetime\(\{TimeRange:end\}\)/);
    assert.match(foundryAgentsQuery, /arg\(''\)\.Resources/);
    assert.match(foundryAgentsQuery, /adx\('__KUSTO_QUERY_URI__\/Hub'\)\.Costs\b/);
    assert.match(foundryAgentsQuery, /adx\('__KUSTO_QUERY_URI__\/Hub'\)\.Prices\b/);
    assert.doesNotMatch(foundryAgentsQuery, /adx\('[^']+'\)\.(Costs|Prices|Region)\(\)/);
    assert.doesNotMatch(foundryAgentsQuery, /adx\('[^']*\{[^']*'\)/);
});

test("returns the complete aggregated agent dataset", () => {
    for (const rowType of [
        "AgentSummary",
        "TimeBucket",
        "TokenBucket",
        "ModelUsage",
        "FinishReason",
        "Tool",
        "Run",
        "Error",
        "BilledCost",
        "ScopedTokenRate",
        "EstimatedCost",
    ]) {
        assert.match(foundryAgentsQuery, new RegExp(`RowType='${rowType}'`));
    }
    assert.deepEqual(
        [...foundryAgentsQuery.matchAll(/\|\s*top\s+(\d+)/gi)].map((match) => Number(match[1])),
        [100, 20]
    );
    assert.doesNotMatch(foundryAgentsQuery, /\|\s*(take|limit)\s+\d+/i);
});

test("keeps supply views aggregated without a global cap", () => {
    assert.deepEqual(
        supplyViews.map((view) => view.label),
        ["Home", "App Service", "Azure AI", "Compute", "Azure SQL", "Storage", "Capacity reservations", "Premium SSD v2"]
    );
    assert.match(supplyQuery, /by SourceType=x_SourceType/);
    for (const view of supplyViews) {
        assert.ok(view.panels.length > 0);
        for (const panel of view.panels) {
            assert.match(panel.query, /\|\s*(summarize|project)|^print\s/im, `${view.id}/${panel.id}`);
            assert.doesNotMatch(panel.query, /\|\s*(take|limit)\s+\d+/i, `${view.id}/${panel.id}`);
        }
        for (const control of view.controls ?? []) {
            if (control.query) {
                assert.doesNotMatch(control.query, /\|\s*(take|limit)\s+\d+/i, `${view.id}/${control.name}`);
            }
        }
    }

    const supplyGroup = groups.find((group) => group.content.items.some((item) => (
        item.type === 11
        && item.content.links.some((link) => link.cellValue === "SelectedSupplyTab")
    )));
    assert.ok(supplyGroup);
    const supplyLinks = supplyGroup.content.items.find((item) => item.type === 11).content.links;
    assert.deepEqual(supplyLinks.map((link) => link.linkLabel), supplyViews.map((view) => view.label));
    assert.ok(supplyLinks.every((link) => link.cellValue === "SelectedSupplyTab"));
    assert.equal(supplyGroup.content.items.filter((item) => item.type === 12).length, supplyViews.length);
});

test("keeps matrix Supply views interactive and evidence-aware", () => {
    const matrixViews = supplyViews.filter((view) => view.kind === "matrix");
    const rowLabels = {
        "app-service": "Plan SKU",
        "azure-ai": "Model and tier",
        compute: "VM family",
        "azure-sql": "Azure SQL quota",
    };
    assert.deepEqual(matrixViews.map((view) => view.id), ["app-service", "azure-ai", "compute", "azure-sql"]);
    for (const view of matrixViews) {
        assert.deepEqual(view.panels.slice(0, 5).map((panel) => panel.role), [
            "summary",
            "coverage",
            "matrix",
            "detail",
            "subscription-detail",
        ]);
        assert.deepEqual(view.controls.filter((control) => !control.hidden).slice(0, 4).map((control) => control.label), [
            "Search",
            "Show",
            "Region",
            "High-water mark",
        ]);
        assert.equal(view.panels.some((panel) => panel.role === "demand"), false, view.id);
        assert.deepEqual(view.detailTabs.map((tab) => tab.id), ["pairs", "subscriptions"]);
        assert.deepEqual(
            view.detailControls.flatMap((detail) => detail.controls.map((control) => control.label)),
            ["Page", "Search subscriptions", "Page"]
        );
        const matrix = view.panels.find((panel) => panel.role === "matrix");
        assert.match(matrix.query, /evaluate pivot\(Location/i);
        assert.match(matrix.query, /coalesce\(UtilizationPercent, -1\.0\)/);
        assert.match(matrix.query, new RegExp(`\\['${rowLabels[view.id]}'\\]`));
        assert.doesNotMatch(matrix.query, new RegExp(rowLabels[view.id].replaceAll(" ", "")));
        const detail = view.panels.find((panel) => panel.role === "detail");
        assert.equal(detail.rowLimit, 50);
        assert.match(detail.query, /:base64/);
        assert.match(detail.query, /RowLabel contains Search/);
        assert.match(detail.query, /QuotaStatus|EvidenceState/i);
        assert.match(detail.query, /PageRow=row_number\(\)/);
        assert.match(detail.query, new RegExp(`\\{${view.detailControls[0].controls[0].name}\\}`));
        assert.match(view.detailControls[0].controls[0].query, /TotalRows=count\(\)/);
        assert.match(view.detailControls[0].controls[0].query, /range\(1, TotalPages, 1\)/);
        const subscriptionDetail = view.panels.find((panel) => panel.role === "subscription-detail").query;
        assert.equal(view.panels.find((panel) => panel.role === "subscription-detail").rowLimit, 50);
        assert.match(subscriptionDetail, /by SubscriptionId/i);
        assert.match(subscriptionDetail, new RegExp(`\\{${view.controls[0].name}:base64\\}`));
        assert.match(subscriptionDetail, /SubscriptionSearch:base64/);
        assert.match(subscriptionDetail, /RowLabel contains ResourceSearch/);
        assert.match(subscriptionDetail, /SubscriptionId startswith SubscriptionSearch/);
        assert.match(subscriptionDetail, /PageRow=row_number\(\)/);
        assert.match(subscriptionDetail, new RegExp(`\\{${view.detailControls[1].controls[1].name}\\}`));
        assert.match(view.detailControls[1].controls[1].query, /TotalRows=count\(\)/);
        assert.match(view.detailControls[1].controls[1].query, /range\(1, TotalPages, 1\)/);
    }

    const compute = matrixViews.find((view) => view.id === "compute");
    assert.match(compute.panels.find((panel) => panel.role === "coverage").query, /ComputeResourceSku/);
    assert.match(compute.panels.find((panel) => panel.role === "matrix").query, /NoQuotaSubscriptions >= Subscriptions/);
    const computeDetail = compute.panels.find((panel) => panel.role === "detail").query;
    assert.match(computeDetail, /OfferSubscriptions/);
    assert.match(computeDetail, /RegionRestrictedSubscriptions/);
    assert.match(computeDetail, /ZoneRestrictedSubscriptions/);
    assert.match(computeDetail, /RepresentativeSkus/);

    const azureAi = matrixViews.find((view) => view.id === "azure-ai");
    assert.match(azureAi.panels.find((panel) => panel.role === "matrix").query, /by RowKey=ResourceName, Unit=unit, Location/);

    const azureSql = matrixViews.find((view) => view.id === "azure-sql");
    assert.equal(
        [...azureSql.panels.find((panel) => panel.role === "matrix").query.matchAll(/'([^']+)'/g)]
            .filter((match) => match[1].includes("Quota"))
            .length >= 5,
        true
    );
    assert.match(azureSql.description, /five supported regional quota metrics/i);
});

test("keeps inventory, quota, and billed demand as separate evidence", () => {
    const evidenceViews = supplyViews.filter((view) => view.kind === "evidence");
    assert.deepEqual(evidenceViews.map((view) => view.id), [
        "storage",
        "capacity-reservations",
        "premium-ssd-v2",
    ]);
    for (const view of evidenceViews) {
        assert.notEqual(view.description, view.sourceNote);
        assert.deepEqual(view.panels.slice(0, 6).map((panel) => panel.role), [
            "summary",
            "coverage",
            "current",
            "history",
            "heatmap",
            "demand",
        ]);
        assert.equal(view.controls.length, 2);
        assert.match(view.panels.find((panel) => panel.role === "history").query, /HistoryMode/);
        assert.match(view.panels.find((panel) => panel.role === "demand").query, /Costs\(\)/);
    }

    const storage = evidenceViews.find((view) => view.id === "storage");
    assert.match(storage.panels.find((panel) => panel.role === "current").query, /Unknown or unclassified/);
    assert.match(storage.panels.find((panel) => panel.role === "heatmap").query, /evaluate pivot\(Region/);
    assert.match(storage.panels.find((panel) => panel.role === "heatmap").query, /Unclassified/);

    const reservations = evidenceViews.find((view) => view.id === "capacity-reservations");
    assert.equal(reservations.panels.at(-1).role, "reconciliation");
    assert.match(reservations.panels.at(-1).query, /join kind=fullouter/);
    assert.match(reservations.panels.at(-1).query, /Inventory only/);
    assert.match(reservations.panels.at(-1).query, /Cost only/);

    const disks = evidenceViews.find((view) => view.id === "premium-ssd-v2");
    assert.match(disks.sourceNote, /GiB inventory; no quota limit/);
    assert.match(disks.panels.find((panel) => panel.role === "demand").title, /matched cost/i);
});

test("renders full Supply information architecture with native Workbook controls", () => {
    const supplyGroup = groups.find((group) => group.conditionalVisibility?.value === "supply");
    const viewGroups = supplyGroup.content.items.filter((item) => (
        item.type === 12
        && item.conditionalVisibility?.parameterName === "SelectedSupplyTab"
    ));
    assert.equal(viewGroups.length, supplyViews.length);

    for (const view of supplyViews) {
        const viewGroup = viewGroups.find((group) => group.conditionalVisibility.value === view.id);
        assert.ok(viewGroup, view.id);
        const viewDescendants = descendants(viewGroup.content.items);
        const renderedPanels = viewDescendants.filter((item) => item.type === 3);
        assert.equal(renderedPanels.length, view.panels.length, view.id);
        if (view.kind === "home") continue;

        const renderedText = viewDescendants
            .filter((item) => item.type === 1)
            .map((item) => item.content.json)
            .join("\n");
        assert.doesNotMatch(renderedText, /\bundefined\b/i, view.id);
        assert.match(renderedText, /\*\*Evidence:\*\*/i, view.id);
        assert.ok(renderedText.includes(view.sourceNote), view.id);
        assert.ok(renderedText.includes(view.nextAction), view.id);

        const controls = viewDescendants.filter((item) => item.type === 9);
        assert.equal(controls.length, view.kind === "matrix" ? 3 : 1, view.id);
        assert.equal(controls[0].content.parameters.length, view.controls.length, view.id);
        if (view.kind === "matrix") {
            assert.equal(controls[1].content.parameters[0].label, "Page", view.id);
            assert.deepEqual(
                controls[2].content.parameters.map((parameter) => parameter.label),
                ["Search subscriptions", "Page"],
                view.id
            );
        }
        const summary = renderedPanels.find((item) => item.content.visualization === "tiles");
        assert.ok(summary?.content.tileSettings, view.id);

        if (view.kind === "matrix") {
            const matrix = renderedPanels.find((item) => item.content.title.startsWith("Estate quota by"));
            assert.ok(matrix.content.gridSettings.formatters.some((formatter) => (
                formatter.formatter === 18
                && formatter.formatOptions?.thresholdsGrid.some((threshold) => (
                    threshold.thresholdValue === "-1"
                    && threshold.representation === "gray"
                    && threshold.text === "Not observed"
                ))
                && formatter.formatOptions?.customColumnWidthSetting === "18ch"
            )), view.id);
            const detailNavigation = viewDescendants.find((item) => (
                item.type === 11
                && item.content.links.every((link) => link.cellValue === view.detailParameter)
            ));
            assert.ok(detailNavigation, view.id);
            assert.equal(detailNavigation.content.links.length, 2, view.id);
            assert.equal(
                viewDescendants.filter((item) => (
                    item.type === 12
                    && item.conditionalVisibility?.parameterName === view.detailParameter
                )).length,
                2,
                view.id
            );
            const pagedPanels = renderedPanels.filter((item) => (
                item.content.title === "Subscriptions"
                || item.content.title.startsWith("Filtered ")
            ));
            assert.equal(pagedPanels.length, 2, view.id);
            assert.ok(pagedPanels.every((item) => item.content.gridSettings.rowLimit === 50), view.id);
        }
    }
});

test("keeps the cross-service proxy query at the Bicep patch location", () => {
    const foundryAgentGroup = workbook.items[16];
    assert.equal(foundryAgentGroup.conditionalVisibility.value, "foundry-agents");
    assert.equal(foundryAgentGroup.content.items[1].type, 3);
    assert.match(foundryAgentGroup.content.items[1].content.query, /__KUSTO_QUERY_URI__/);
});

test("lets the Supply coverage index open a selected class", () => {
    const home = supplyViews.find((view) => view.id === "home").panels[0];
    assert.equal(home.exportFieldName, "ClassId");
    assert.equal(home.exportParameterName, "SelectedSupplyTab");
    const coverage = queryItems.find((item) => item.content.title === "Quota coverage");
    assert.equal(coverage.content.exportFieldName, "ClassId");
    assert.equal(coverage.content.exportParameterName, "SelectedSupplyTab");
});

test("defines valid native metrics", () => {
    for (const metric of [...tokenMetrics, ...requestMetrics, ...latencyMetrics]) {
        assert.equal(metric.namespace, "microsoft.cognitiveservices/accounts");
        assert.match(metric.metric, /^microsoft\.cognitiveservices\/accounts-/);
        assert.ok(Number.isInteger(metric.aggregation));
    }
    assert.deepEqual(
        tokenMetrics.map((metric) => metric.metric),
        [
            "microsoft.cognitiveservices/accounts-Azure OpenAI  Usage-ProcessedPromptTokens",
            "microsoft.cognitiveservices/accounts-Azure OpenAI  Usage-GeneratedTokens",
            "microsoft.cognitiveservices/accounts-Azure OpenAI  Usage-TokenTransaction",
        ]
    );
    assert.ok(requestMetrics.every((metric) =>
        metric.metric === "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-AzureOpenAIRequests"
    ));
    assert.ok(requestMetrics.some((metric) => metric.splitBy?.includes("StatusCode")));
    assert.deepEqual(
        latencyMetrics.map((metric) => metric.metric),
        [
            "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-AzureOpenAITimeToResponse",
            "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-TimeToLastByte",
            "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-TokensPerSecond",
            "microsoft.cognitiveservices/accounts-Azure OpenAI  HTTP Requests-AzureOpenAIContextTokensCacheMatchRate",
        ]
    );
});
