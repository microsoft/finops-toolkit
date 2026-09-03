import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
    foundryAgentsQuery,
    foundryCostQuery,
    foundryInventoryQuery,
    latencyMetrics,
    requestMetrics,
    supplyQuery,
    supplyViews,
    tokenMetrics,
} from "./queries.mjs";

const workbookDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(workbookDir, "../../..");
const sourcePath = resolve(repoRoot, "src/templates/finops-hub/dashboard.json");
const outputPath = resolve(workbookDir, "workbook.json");
const dashboard = JSON.parse(readFileSync(sourcePath, "utf8"));
const packageVersion = JSON.parse(readFileSync(resolve(repoRoot, "package.json"), "utf8")).version;

const guid = (seed) => {
    const value = createHash("sha1").update(seed).digest("hex").slice(0, 32);
    return `${value.slice(0, 8)}-${value.slice(8, 12)}-${value.slice(12, 16)}-${value.slice(16, 20)}-${value.slice(20)}`;
};

const normalizeTitle = (value) => value.replace(/^-\s*/, "").replace(/\s+/g, " ").trim();
const pageKey = (page) => normalizeTitle(page.name)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
const pageCondition = (key) => ({
    parameterName: "SelectedTab",
    comparison: "isEqualTo",
    value: key,
});

const baseQueryByVariable = new Map(dashboard.baseQueries.map((query) => [query.variableName, query]));
const queryById = new Map(dashboard.queries.map((query) => [query.id, query]));
const parameterNames = new Set(dashboard.parameters.map((parameter) => parameter.variableName));

function parameterPrelude() {
    return `let numberOfMonths = toint('{numberOfMonths}');
let numberOfDays = toint('{numberOfDays}');
let maxGroupCount = toint('{maxGroupCount}');
let selectedBillingCurrency = '{selectedBillingCurrency}';`;
}

function compileQuery(query) {
    const declarations = [];
    const seen = new Set();

    function addDependencies(item) {
        for (const variableId of item.usedVariables ?? []) {
            const baseQuery = baseQueryByVariable.get(variableId);
            if (baseQuery && !seen.has(baseQuery.id)) {
                const definition = queryById.get(baseQuery.queryId);
                if (!definition) {
                    throw new Error(`Base query '${baseQuery.id}' does not reference a known query.`);
                }
                addDependencies(definition);
                declarations.push(`let ${baseQuery.variableName} = (\n${definition.text.trim()}\n);`);
                seen.add(baseQuery.id);
            } else if (!baseQuery && !parameterNames.has(variableId)) {
                throw new Error(`Query '${item.id}' references unknown variable '${variableId}'.`);
            }
        }
    }

    addDependencies(query);
    return [parameterPrelude(), ...declarations, query.text.trim()].join("\n\n");
}

function workbookMarkdown(markdown) {
    return markdown
        .replaceAll("$$ftkver$$", packageVersion)
        .replaceAll(" ($$build-month$$)", "");
}

function adxQuery(queryText) {
    return JSON.stringify({
        version: "AzureDataExplorerQuery/1.0",
        queryText,
        clusterName: "{HubClusterName}",
        databaseName: "{HubDatabase}",
    });
}

function workbookVisualization(visualType) {
    const type = visualType.toLowerCase().replace(/\s+/g, "");
    if (type === "table") return "table";
    if (type === "pie") return "piechart";
    if (type === "multistat" || type === "card") return "tiles";
    if (type.includes("bar") || type.includes("column")) return "barchart";
    if (type.includes("line") || type.includes("time") || type.includes("area")) return "timechart";
    return "table";
}

function textItem(name, markdown, style, width = "100") {
    const content = {
        json: markdown,
    };
    if (style) content.style = style;
    return {
        type: 1,
        content,
        customWidth: width,
        name: guid(name),
    };
}

function sourceTextStyle(markdown) {
    const value = markdown.trim();
    if (/^###\s/.test(value)) return "upsell";
    return undefined;
}

function sourceVisualizationSize(tile) {
    const type = tile.visualType.toLowerCase();
    if (type === "multistat" || type === "card") return 0;
    if (type === "table") return 3;
    return 2;
}

function sourceTileToWorkbookItem(tile, width) {
    const common = {
        customWidth: `${width}`,
        name: guid(`source-tile:${tile.id}`),
    };

    if (tile.markdownText) {
        const style = sourceTextStyle(tile.markdownText);
        return {
            type: 1,
            content: {
                json: workbookMarkdown(tile.markdownText),
                ...(style ? { style } : {}),
            },
            ...common,
        };
    }

    const query = queryById.get(tile.queryRef?.queryId);
    if (!query) {
        throw new Error(`Tile '${tile.id}' does not reference a known query.`);
    }

    return {
        type: 3,
        content: {
            version: "KqlItem/1.0",
            query: adxQuery(compileQuery(query)),
            size: sourceVisualizationSize(tile),
            title: tile.title,
            timeContext: {
                durationMs: 0,
            },
            queryType: 9,
            visualization: workbookVisualization(tile.visualType),
            showExportToExcel: tile.visualType.toLowerCase() === "table",
        },
        doNotRunWhenHidden: true,
        ...common,
    };
}

function sourceRowWidths(tiles) {
    if (tiles.length === 1) return [100];
    if (tiles.length === 2) {
        const total = tiles[0].layout.width + tiles[1].layout.width;
        const left = Math.round((tiles[0].layout.width / total) * 100);
        const pairs = [[25, 75], [33, 66], [50, 50], [66, 33], [75, 25]];
        return pairs.reduce((best, pair) => (
            Math.abs(pair[0] - left) < Math.abs(best[0] - left) ? pair : best
        ));
    }
    if (tiles.length === 3) return [33, 33, 33];
    if (tiles.length === 4) return [25, 25, 25, 25];
    if (tiles.length === 5) return [20, 20, 20, 20, 20];
    throw new Error(`Unsupported source row with ${tiles.length} tiles.`);
}

function kustoItem(name, title, query, visualization = "table", width = "100") {
    return {
        type: 3,
        content: {
            version: "KqlItem/1.0",
            query: adxQuery(query),
            size: 1,
            title,
            timeContext: {
                durationMs: 0,
            },
            queryType: 9,
            visualization,
            showExportToExcel: visualization === "table",
        },
        doNotRunWhenHidden: true,
        customWidth: width,
        name: guid(name),
    };
}

function argItem(name, title, query, width = "100") {
    return {
        type: 3,
        content: {
            version: "KqlItem/1.0",
            query,
            size: 1,
            title,
            queryType: 1,
            resourceType: "microsoft.resourcegraph/resources",
            crossComponentResources: [
                "value::selected"
            ],
            visualization: "table",
            showExportToExcel: true,
        },
        doNotRunWhenHidden: true,
        customWidth: width,
        name: guid(name),
    };
}

function logsItem(name, title, query, width = "100") {
    return {
        type: 3,
        content: {
            version: "KqlItem/1.0",
            query,
            size: 1,
            title,
            timeContext: {
                durationMs: 0,
            },
            queryType: 0,
            resourceType: "microsoft.operationalinsights/workspaces",
            crossComponentResources: [
                "{TelemetryResources}"
            ],
            visualization: "table",
            showExportToExcel: true,
        },
        doNotRunWhenHidden: true,
        customWidth: width,
        name: guid(name),
    };
}

function metricsItem(name, title, metrics, width = "100") {
    return {
        type: 10,
        content: {
            version: "MetricsItem/2.0",
            size: 0,
            chartType: 0,
            resourceType: "microsoft.cognitiveservices/accounts",
            resourceIds: [
                "{FoundryAccounts}"
            ],
            timeContext: {
                durationMs: 0,
            },
            title,
            metrics,
        },
        doNotRunWhenHidden: true,
        customWidth: width,
        name: guid(name),
    };
}

function groupItem(name, key, items) {
    return {
        type: 12,
        content: {
            version: "NotebookGroup/1.0",
            groupType: "editable",
            loadType: "always",
            items,
        },
        conditionalVisibility: pageCondition(key),
        name: guid(name),
    };
}

function rowGroupItem(name, items) {
    return {
        type: 12,
        content: {
            version: "NotebookGroup/1.0",
            groupType: "editable",
            loadType: "always",
            items,
        },
        customWidth: "100",
        name: guid(name),
    };
}

function nestedGroupItem(name, parameterName, value, items) {
    return {
        type: 12,
        content: {
            version: "NotebookGroup/1.0",
            groupType: "editable",
            loadType: "always",
            items,
        },
        conditionalVisibility: {
            parameterName,
            comparison: "isEqualTo",
            value,
        },
        name: guid(name),
    };
}

const sourcePages = dashboard.pages.map((page) => ({
    ...page,
    title: normalizeTitle(page.name),
    key: pageKey(page),
}));
const addedPages = [
    { title: "Foundry infrastructure", key: "foundry-infrastructure" },
    { title: "Foundry agents", key: "foundry-agents" },
    { title: "Supply", key: "supply" },
];
const allPages = [...sourcePages, ...addedPages];

const navigation = {
    type: 11,
    content: {
        version: "LinkItem/1.0",
        style: "tabs",
        links: allPages.map((page) => ({
            id: guid(`navigation:${page.key}`),
            cellValue: "SelectedTab",
            linkTarget: "parameter",
            linkLabel: page.title,
            subTarget: page.key,
            style: "link",
        })),
    },
    name: guid("navigation"),
};

const hubQueryUriQuery = `resources
| where id =~ '{HubCluster}'
| where type =~ 'microsoft.kusto/clusters'
| project value=tostring(properties.uri), label=tostring(properties.uri), selected=true`;
const hubClusterNameQuery = `resources
| where id =~ '{HubCluster}'
| where type =~ 'microsoft.kusto/clusters'
| project value=strcat(name, '.', location), label=strcat(name, '.', location), selected=true`;
const foundryAccountsQuery = `resources
| where type =~ 'microsoft.cognitiveservices/accounts'
| project
    value=id,
    label=strcat(name, ' (', resourceGroup, ', ', location, ')'),
    selected=true
| order by label asc`;
const telemetryResourcesQuery = `resources
| where type =~ 'microsoft.operationalinsights/workspaces'
| project
    value=id,
    label=strcat(name, ' (', resourceGroup, ', ', location, ')'),
    selected=true
| order by label asc`;

const numberOfMonthsQuery = queryById.get("c9039243-968d-4e75-9899-8d4ab51a9896")?.text;
const currencyQuery = queryById.get("f2a8c4d6-3b5e-4a7f-9c2d-8e5b1f4a7d9c");
if (!numberOfMonthsQuery || !currencyQuery) {
    throw new Error("The source dashboard parameter queries are missing.");
}
const currencyParameterQuery = `${currencyQuery.text.trim()}
| serialize
| extend selected = row_number() == 1
| project value=BillingCurrency, label=Label, selected`;

const parameterItem = {
    type: 9,
    content: {
        version: "KqlParameterItem/1.0",
        parameters: [
            {
                id: guid("parameter:selected-tab"),
                version: "KqlParameterItem/1.0",
                name: "SelectedTab",
                type: 1,
                value: sourcePages[0].key,
                isHiddenWhenLocked: true,
            },
            {
                id: guid("parameter:selected-supply-tab"),
                version: "KqlParameterItem/1.0",
                name: "SelectedSupplyTab",
                type: 1,
                value: supplyViews[0].id,
                isHiddenWhenLocked: true,
            },
            {
                id: guid("parameter:hub-cluster"),
                version: "KqlParameterItem/1.0",
                name: "HubCluster",
                label: "FinOps hub cluster",
                type: 5,
                isRequired: true,
                value: "value::1",
                isHiddenWhenLocked: true,
                typeSettings: {
                    resourceTypeFilter: {
                        "microsoft.kusto/clusters": true
                    },
                    additionalResourceOptions: [
                        "value::1"
                    ],
                    showDefault: false,
                },
            },
            {
                id: guid("parameter:hub-query-uri"),
                version: "KqlParameterItem/1.0",
                name: "HubQueryUri",
                label: "FinOps hub query endpoint",
                type: 2,
                isRequired: true,
                query: hubQueryUriQuery,
                crossComponentResources: [
                    "{HubCluster:subscription}"
                ],
                queryType: 1,
                resourceType: "microsoft.resourcegraph/resources",
                typeSettings: {
                    additionalResourceOptions: [],
                    showDefault: false,
                },
                isHiddenWhenLocked: true,
            },
            {
                id: guid("parameter:hub-cluster-name"),
                version: "KqlParameterItem/1.0",
                name: "HubClusterName",
                label: "FinOps hub cluster",
                type: 2,
                isRequired: true,
                query: hubClusterNameQuery,
                crossComponentResources: [
                    "{HubCluster:subscription}"
                ],
                queryType: 1,
                resourceType: "microsoft.resourcegraph/resources",
                typeSettings: {
                    additionalResourceOptions: [],
                    showDefault: false,
                },
            },
            {
                id: guid("parameter:hub-database"),
                version: "KqlParameterItem/1.0",
                name: "HubDatabase",
                label: "FinOps hub database",
                type: 1,
                isRequired: true,
                value: "Hub",
            },
            {
                id: guid("parameter:telemetry"),
                version: "KqlParameterItem/1.0",
                name: "TelemetryResources",
                label: "Agent telemetry workspaces",
                type: 5,
                isRequired: true,
                multiSelect: true,
                quote: "'",
                delimiter: ",",
                query: telemetryResourcesQuery,
                crossComponentResources: [
                    "value::selected"
                ],
                typeSettings: {
                    resourceTypeFilter: {
                        "microsoft.operationalinsights/workspaces": true
                    },
                    additionalResourceOptions: [],
                    selectAllValue: "*",
                    showDefault: false,
                },
                queryType: 1,
                resourceType: "microsoft.resourcegraph/resources",
            },
            {
                id: guid("parameter:foundry-accounts"),
                version: "KqlParameterItem/1.0",
                name: "FoundryAccounts",
                label: "Foundry accounts",
                type: 5,
                isRequired: true,
                multiSelect: true,
                quote: "'",
                delimiter: ",",
                query: foundryAccountsQuery,
                crossComponentResources: [
                    "value::selected"
                ],
                typeSettings: {
                    resourceTypeFilter: {
                        "microsoft.cognitiveservices/accounts": true
                    },
                    additionalResourceOptions: [],
                    selectAllValue: "*",
                    showDefault: false,
                },
                queryType: 1,
                resourceType: "microsoft.resourcegraph/resources",
            },
            {
                id: guid("parameter:time-range"),
                version: "KqlParameterItem/1.0",
                name: "TimeRange",
                label: "Time range",
                type: 4,
                isRequired: true,
                value: {
                    durationMs: 604800000
                },
                typeSettings: {
                    selectableValues: [
                        { durationMs: 86400000 },
                        { durationMs: 604800000 },
                        { durationMs: 1209600000 },
                        { durationMs: 2592000000 }
                    ],
                    allowCustom: true,
                },
            },
            {
                id: guid("parameter:number-of-months"),
                version: "KqlParameterItem/1.0",
                name: "numberOfMonths",
                label: "Months",
                type: 2,
                isRequired: true,
                value: "12",
                query: adxQuery(numberOfMonthsQuery),
                queryType: 9,
                typeSettings: {
                    additionalResourceOptions: [],
                    showDefault: false,
                },
            },
            {
                id: guid("parameter:currency"),
                version: "KqlParameterItem/1.0",
                name: "selectedBillingCurrency",
                label: "Currency",
                type: 2,
                value: "",
                query: adxQuery(currencyParameterQuery),
                queryType: 9,
                typeSettings: {
                    additionalResourceOptions: [],
                    showDefault: false,
                },
            },
            {
                id: guid("parameter:number-of-days"),
                version: "KqlParameterItem/1.0",
                name: "numberOfDays",
                label: "Comparison days",
                type: 1,
                value: "28",
            },
            {
                id: guid("parameter:max-group-count"),
                version: "KqlParameterItem/1.0",
                name: "maxGroupCount",
                label: "Maximum groups",
                type: 1,
                value: "9",
            }
        ],
        style: "pills",
        queryType: 1,
        resourceType: "microsoft.resourcegraph/resources",
    },
    name: guid("parameters"),
};

const sourceGroups = sourcePages.map((page) => {
    const rows = new Map();
    for (const tile of dashboard.tiles
        .filter((tile) => tile.pageId === page.id)
        .sort((left, right) => left.layout.y - right.layout.y || left.layout.x - right.layout.x)) {
        const row = rows.get(tile.layout.y) ?? [];
        row.push(tile);
        rows.set(tile.layout.y, row);
    }
    const items = [...rows.entries()].map(([y, rowTiles]) => {
        const widths = sourceRowWidths(rowTiles);
        return rowGroupItem(
            `source-page:${page.id}:row:${y}`,
            rowTiles.map((tile, index) => sourceTileToWorkbookItem(tile, widths[index]))
        );
    });
    return groupItem(`source-page:${page.id}`, page.key, items);
});

const foundryInfrastructureItems = [
    textItem(
        "foundry-infrastructure:introduction",
        "## Foundry infrastructure\n\nUse Azure Resource Graph for inventory, Azure Monitor Metrics for platform behavior, and FinOps hub cost for financial context."
    ),
    argItem("foundry-infrastructure:inventory", "Foundry estate", foundryInventoryQuery),
    metricsItem("foundry-infrastructure:tokens", "Token usage", tokenMetrics),
    metricsItem("foundry-infrastructure:requests", "Model requests", requestMetrics, "50"),
    metricsItem("foundry-infrastructure:latency", "Latency and throughput", latencyMetrics, "50"),
    kustoItem("foundry-infrastructure:cost", "Foundry cost and usage", foundryCostQuery),
];

const foundryAgentItems = [
    textItem(
        "foundry-agents:introduction",
        "## Foundry agents\n\nThis view runs one cached, Monitor-primary query across the selected workspaces. The query correlates Azure Resource Graph inventory with FinOps hub cost and price data. Workspace resource IDs stay outside KQL."
    ),
    logsItem("foundry-agents:dataset", "Foundry agent operations and cost dataset", foundryAgentsQuery),
];

const supplyNavigation = {
    type: 11,
    content: {
        version: "LinkItem/1.0",
        style: "tabs",
        links: supplyViews.map((view) => ({
            id: guid(`supply-navigation:${view.id}`),
            cellValue: "SelectedSupplyTab",
            linkTarget: "parameter",
            linkLabel: view.label,
            subTarget: view.id,
            style: "link",
        })),
    },
    name: guid("supply-navigation"),
};

const supplyItems = [
    textItem(
        "supply:introduction",
        "## Supply\n\nReview quota and inventory as separate evidence. Missing observations are unknown, not healthy."
    ),
    supplyNavigation,
    ...supplyViews.map((view) => nestedGroupItem(
        `supply:${view.id}`,
        "SelectedSupplyTab",
        view.id,
        [
            textItem(`supply:${view.id}:heading`, `### ${view.title}\n\n${view.description}`),
            kustoItem(`supply:${view.id}:dataset`, view.title, view.query),
        ]
    )),
];

const workbook = {
    version: "Notebook/1.0",
    items: [
        parameterItem,
        navigation,
        ...sourceGroups,
        groupItem("foundry-infrastructure", "foundry-infrastructure", foundryInfrastructureItems),
        groupItem("foundry-agents", "foundry-agents", foundryAgentItems),
        groupItem("supply", "supply", supplyItems),
    ],
    fallbackResourceIds: [
        "Azure Monitor"
    ],
    "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json",
};

const descendants = (items) => items.flatMap((item) => [
    item,
    ...descendants(item.content?.items ?? []),
]);
const sourceItems = descendants(sourceGroups).filter((item) => item.type === 1 || item.type === 3);
const sourceTileCount = sourceItems.length;
const sourceQueryCount = sourceItems.filter((item) => item.type === 3).length;
const workspaceLiterals = JSON.stringify(workbook)
    .match(/\/providers\/microsoft\.operationalinsights\/workspaces\//gi) ?? [];
const unboundedTake = [foundryCostQuery, supplyQuery, ...supplyViews.map((view) => view.query)]
    .some((query) => /\|\s*(take|limit)\s+\d+/i.test(query));

if (sourcePages.length !== 13 || sourceTileCount !== 158 || sourceQueryCount !== 99) {
    throw new Error(`Conversion mismatch: ${sourcePages.length} pages, ${sourceTileCount} tiles, ${sourceQueryCount} queries.`);
}
if (workspaceLiterals.length > 0) {
    throw new Error("A Log Analytics workspace resource ID was written into the Workbook.");
}
if (unboundedTake) {
    throw new Error("An unapproved global row limit was added to an aggregate query.");
}

writeFileSync(outputPath, `${JSON.stringify(workbook, null, 2)}\n`);
console.log(`Generated ${outputPath} with ${sourcePages.length} source pages, ${sourceTileCount} source tiles, and ${addedPages.length} new pages.`);
