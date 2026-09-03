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
const workbook = JSON.parse(readFileSync(resolve(workbookDir, "workbook.json"), "utf8"));
const groups = workbook.items.filter((item) => item.type === 12);
const sourceGroups = groups.slice(0, 13);
const descendants = (items) => items.flatMap((item) => [
    item,
    ...descendants(item.content?.items ?? []),
]);
const allItems = descendants(workbook.items);
const sourceItems = descendants(sourceGroups).filter((item) => item.type === 1 || item.type === 3);
const queryItems = allItems.filter((item) => item.type === 3);
const parameterItem = workbook.items.find((item) => item.type === 9);
const parameters = parameterItem.content.parameters;
const parameterByName = new Map(parameters.map((parameter) => [parameter.name, parameter]));

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
    assert.ok(groups.every((group) => group.content.loadType === "always"));
    assert.equal(parameterByName.get("SelectedSupplyTab").value, "home");
});

test("uses native Azure Data Explorer query envelopes", () => {
    const adxItems = queryItems.filter((item) => item.content.queryType === 9);
    assert.equal(adxItems.length, 108);
    for (const item of adxItems) {
        const query = JSON.parse(item.content.query);
        assert.equal(query.version, "AzureDataExplorerQuery/1.0");
        assert.equal(query.clusterName, "{HubClusterName}");
        assert.equal(query.databaseName, "{HubDatabase}");
        assert.ok(query.queryText.length > 0);
    }
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
    assert.match(foundryAgentsQuery, /arg\(''\)\.Resources/);
    assert.match(foundryAgentsQuery, /adx\('\{HubQueryUri\}\/\{HubDatabase\}'\)\.Costs\(\)/);
    assert.match(foundryAgentsQuery, /adx\('\{HubQueryUri\}\/\{HubDatabase\}'\)\.Prices\(\)/);
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
        assert.match(view.query, /\|\s*summarize/i);
        assert.doesNotMatch(view.query, /\|\s*(take|limit)\s+\d+/i);
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

test("defines valid native metrics", () => {
    for (const metric of [...tokenMetrics, ...requestMetrics, ...latencyMetrics]) {
        assert.equal(metric.namespace, "microsoft.cognitiveservices/accounts");
        assert.match(metric.metric, /^microsoft\.cognitiveservices\/accounts-/);
        assert.ok(Number.isInteger(metric.aggregation));
    }
    assert.deepEqual(
        tokenMetrics.map((metric) => metric.metric),
        [
            "microsoft.cognitiveservices/accounts-ProcessedPromptTokens",
            "microsoft.cognitiveservices/accounts-GeneratedTokens",
            "microsoft.cognitiveservices/accounts-TokenTransaction",
        ]
    );
    assert.ok(requestMetrics.every((metric) => metric.metric.endsWith("-AzureOpenAIRequests")));
    assert.ok(requestMetrics.some((metric) => metric.splitBy?.includes("StatusCode")));
});
