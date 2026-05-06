# AI Workload Cost Analysis

## Identity
- **YAML:** sre-config/scheduled-tasks/ai-workload-cost-analysis.yaml
- **Cron:** 0 10 1 * * — monthly on day 1 at 10:00 UTC
- **Owning subagent:** chief-financial-officer
- **FinOps Framework capability:** Unit Economics (FinOps for AI)
- **Maturity:** Walk
- **Tools used:** PostTeamsMessage, resource-graph-query, vm-quota-usage, ai-model-cost-comparison, ai-cost-by-application

## Latest run summary
Monthly AI Workload Cost Analysis completed successfully. All 8 phases finished: **Data collection:** 5 AI Kusto queries + 1 Resource Graph call executed without errors **Key findings:** April 2026 spend of $11.82 across 27.96M tokens, down 65% MoM from $33.92. Model portfolio consolidated from 19 to 5 variants. Extreme I/O ratio (162:1) flagged for prompt optimization. **Deliverables:** Full report with 3 embedded charts posted to Teams. Operational learnings (model naming

## Final Teams card / Outlook output (verbatim)
~~~~text
## Teams Message (posted verbatim)

Subject: **🤖 AI Workload Cost Analysis — May 2026 (April Billing Period)**

---

<h2>🤖 Executive Summary</h2>
<p>Total Azure OpenAI spend for <b>April 2026</b> was <b>$11.82</b> across <b>27.96M tokens</b>, a <b>-65.1% cost
decline</b> and <b>-62.9% token volume decline</b> from March ($33.92 / 75.3M tokens). All usage is concentrated on
a single dev resource (<code>aiharishx2gd</code>) in US East 2. No commitment discounts are applied — all spend is
pay-as-you-go at list price.</p>

<p>The model portfolio consolidated from <b>19 variants</b> (March) to <b>5 variants</b> (April), with preview
models (GPT 5, 5.1, 5.3) fully retired. GPT 5.2 GA now accounts for 99.9% of spend. Input-to-output token ratios
are extremely high (162:1 for GPT 5.2), indicating significant prompt optimization opportunity.</p>

<hr/>

<h2>📊 Daily AI Cost &amp; Token Trend</h2>
<img src="/api/files/tmp/ThreadFiles/6a8c3d75-731b-45c5-801b-2003c101c4c0/ai-daily-trend.png" alt="Daily AI Trend"
style="max-width:100%;"/>
<p>Usage was concentrated in early April (Apr 3-10) with a burst of activity, followed by a 19-day gap and brief
activity on Apr 29. Peak day was Apr 4 at $3.88 / 9.0M tokens. No clear weekday/weekend pattern — consistent with
dev/testing workloads rather than production traffic.</p>

<hr/>

<h2>🤖 Token Economics — April 2026</h2>
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; width:100%;">
<tr style="background:#4472C4; color:white;">
<th>Model</th><th>Direction</th><th>Tokens</th><th>Effective Cost</th><th>Cost/1K Tokens</th><th>% of Total
Cost</th>
</tr>
<tr><td>GPT 5.2</td><td>Standard Input</td><td align="right">2,900,953</td><td align="right">$5.08</td><td
align="right">$0.00175</td><td align="right">42.9%</td></tr>
<tr><td>GPT 5.2</td><td>Cached Input</td><td align="right">24,815,360</td><td align="right">$4.34</td><td
align="right">$0.000175</td><td align="right">36.7%</td></tr>
<tr><td>GPT 5.2</td><td>Output</td><td align="right">170,994</td><td align="right">$2.39</td><td
align="right">$0.014</td><td align="right">20.3%</td></tr>
<tr><td>GPT 4.1 nano</td><td>Input</td><td align="right">59,977</td><td align="right">$0.007</td><td
align="right">$0.00011</td><td align="right">0.06%</td></tr>
<tr><td>GPT 4.1 nano</td><td>Output</td><td align="right">8,661</td><td align="right">$0.004</td><td
align="right">$0.00044</td><td align="right">0.03%</td></tr>
<tr style="background:#f0f0f0; font-weight:bold;">
<td colspan="2">TOTAL</td><td align="right">27,955,945</td><td align="right">$11.82</td><td
align="right">$0.00042</td><td align="right">100%</td>
</tr>
</table>

<p><b>Key insight:</b> GPT 5.2 output tokens cost <b>80x more</b> than cached input tokens ($0.014 vs $0.000175 per
1K), yet output is only 0.6% of token volume. Cached input (88.8% of volume) is the most cost-efficient tier at
$0.000175/1K.</p>

<hr/>

<h2>📊 Model Cost Efficiency Comparison</h2>
<img src="/api/files/tmp/ThreadFiles/6a8c3d75-731b-45c5-801b-2003c101c4c0/ai-model-comparison.png" alt="Model Cost
Comparison" style="max-width:100%;"/>

<hr/>

<h2>📊 Month-over-Month: March vs April 2026</h2>
<img src="/api/files/tmp/ThreadFiles/6a8c3d75-731b-45c5-801b-2003c101c4c0/ai-mom-comparison.png" alt="MoM
Comparison" style="max-width:100%;"/>

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; width:100%;">
<tr style="background:#4472C4; color:white;">
<th>Metric</th><th>March 2026</th><th>April 2026</th><th>Change</th>
</tr>
<tr><td>Total Tokens</td><td align="right">75.33M</td><td align="right">27.96M</td><td align="right"
style="color:#C00000;"><b>-62.9%</b></td></tr>
<tr><td>Total Cost</td><td align="right">$33.92</td><td align="right">$11.82</td><td align="right"
style="color:#C00000;"><b>-65.1%</b></td></tr>
<tr><td>Cost per 1K Tokens</td><td align="right">$0.00045</td><td align="right">$0.00042</td><td align="right"
style="color:#70AD47;"><b>-6.2%</b></td></tr>
<tr><td>Model Variants</td><td align="right">19</td><td align="right">5</td><td align="right"
style="color:#C00000;"><b>-73.7%</b></td></tr>
<tr><td>Active Days</td><td align="right">~30</td><td align="right">9</td><td align="right"
style="color:#C00000;"><b>-70%</b></td></tr>
</table>

<p><b>Analysis:</b> The cost decline is primarily driven by reduced usage volume (-63%) and model consolidation
(preview retirements). Unit cost improved slightly (-6.2%) as GPT 5.2 GA rates are marginally cheaper than the
blended preview model rates used in March.</p>

<hr/>

<h2>🤖 Input/Output Token Ratio Analysis</h2>
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; width:100%;">
<tr style="background:#ED7D31; color:white;">
<th>Model</th><th>Input Tokens</th><th>Output Tokens</th><th>I/O Ratio</th><th>Flag</th>
</tr>
<tr><td>GPT 5.2 (April)</td><td align="right">27,716,313</td><td align="right">170,994</td><td
align="right"><b>162:1</b></td><td style="color:#C00000;"><b>⚠️ EXTREME</b></td></tr>
<tr><td>GPT 4.1 nano (April)</td><td align="right">59,977</td><td align="right">8,661</td><td
align="right"><b>6.9:1</b></td><td style="color:#70AD47;">✅ Normal</td></tr>
<tr><td>GPT 5.2 (March)</td><td align="right">32,366,945</td><td align="right">411,698</td><td
align="right"><b>79:1</b></td><td style="color:#C00000;"><b>⚠️ HIGH</b></td></tr>
<tr><td>GPT 5.1 Preview (March)</td><td align="right">22,997,534</td><td align="right">140,247</td><td
align="right"><b>164:1</b></td><td style="color:#C00000;"><b>⚠️ EXTREME</b></td></tr>
</table>

<p><b>Insight:</b> GPT 5.2 I/O ratio <b>doubled</b> from 79:1 (March) to 162:1 (April). This suggests very large
context windows being passed with short completions — a classic prompt engineering optimization target. Reducing
prompt context by 50% could save ~$2.50/month on standard input costs alone.</p>

<hr/>

<h2>💰 Cost Allocation</h2>
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; width:100%;">
<tr style="background:#4472C4; color:white;">
<th>Resource</th><th>Environment</th><th>Cost Center</th><th>Model
Family</th><th>Tokens</th><th>Cost</th><th>Share</th>
</tr>
<tr><td>aiharishx2gd</td><td>dev</td><td>1234</td><td>GPT5</td><td align="right">27.89M</td><td
align="right">$11.81</td><td align="right">99.91%</td></tr>
<tr><td>aiharishx2gd</td><td>dev</td><td>1234</td><td>GPT 4.1 nano</td><td align="right">0.07M</td><td
align="right">$0.01</td><td align="right">0.09%</td></tr>
<tr style="background:#f0f0f0; font-weight:bold;">
<td colspan="4">TOTAL</td><td align="right">27.96M</td><td align="right">$11.82</td><td align="right">100%</td>
</tr>
</table>

<p><b>Notes:</b> All AI spend is on a single dev deployment (<code>aiharishx2gd</code>) in US East 2. No
application or team tags are set. 100% dev environment — no production AI workloads detected. The resource sits in
the <code>foundry</code> resource group alongside AI Foundry Hub/Project resources.</p>

<hr/>

<h2>🎯 Top 3 Optimization Recommendations</h2>

<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse; width:100%;">
<tr style="background:#70AD47; color:white;">
<th>#</th><th>Recommendation</th><th>Est. Monthly Savings</th><th>Priority</th>
</tr>
<tr>
<td>1</td>
<td><b>Prompt Context Optimization:</b> GPT 5.2 I/O ratio of 162:1 is extreme. Reduce context window size by
compressing, summarizing, or chunking prompts. A 50% reduction in standard input tokens would save
~$2.54/month.</td>
<td align="right"><b>$2.50</b></td>
<td>HIGH</td>
</tr>
<tr>
<td>2</td>
<td><b>Model Substitution for Low-Complexity Tasks:</b> If any GPT 5.2 workloads handle simple tasks
(classification, extraction, summarization), switch to GPT 4.1 nano which costs 16x less per input token ($0.00011
vs $0.00175/1K). Even moving 10% of standard input to nano would save ~$0.46/month.</td>
<td align="right"><b>$0.46</b></td>
<td>MEDIUM</td>
</tr>
<tr>
<td>3</td>
<td><b>Tag Governance &amp; Showback:</b> No <code>application</code> or <code>team</code> tags are set on AI
resources. Implement mandatory tagging to enable per-team chargeback and cost accountability as AI usage
scales.</td>
<td align="right">Governance</td>
<td>MEDIUM</td>
</tr>
</table>

<h3>Additional Observations</h3>
<ul>
<li><b>No commitment discounts:</b> 0% discount across all models — all pay-as-you-go at list price. At
$11.82/month, PTU commitments are not cost-justified. Revisit if monthly spend exceeds $500.</li>
<li><b>Cache utilization is strong:</b> 88.8% of tokens are cached input at 10x lower cost — indicates effective
prompt caching is already in place.</li>
<li><b>Dev-only workload:</b> No production AI traffic detected. Consider using GPT 4.1 nano as default for
dev/test to minimize non-production costs.</li>
<li><b>Model consolidation complete:</b> Preview models (GPT 5, 5.1, 5.3) successfully retired. Portfolio now clean
with 2 model families.</li>
</ul>

<hr/>

<h3>📋 FOCUS Compliance Note</h3>
<p>All metrics use standard FOCUS columns: ConsumedQuantity (tokens), ConsumedUnit (tokens), EffectiveCost,
x_SkuMeterSubcategory (Azure OpenAI), x_SkuDescription (model + direction). Unit economics = EffectiveCost /
ConsumedQuantity.</p>

<h3>🤖 AI Infrastructure Inventory</h3>
<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse;">
<tr style="background:#4472C4; color:white;"><th>Resource</th><th>Type</th><th>Kind</th><th>Region</th><th>Resource
Group</th></tr>
<tr><td>brett-mmqxefcp-eastus</td><td>Cognitive
Services</td><td>AIServices</td><td>eastus</td><td>foundry</td></tr>
<tr><td>foundy1125</td><td>Cognitive Services</td><td>AIServices</td><td>eastus2</td><td>foundry</td></tr>
<tr><td>foundy1125-speech</td><td>Cognitive
Services</td><td>SpeechServices</td><td>eastus2</td><td>foundry</td></tr>
<tr><td>brettwil-6560</td><td>ML Workspace</td><td>Project</td><td>eastus2</td><td>foundry</td></tr>
<tr><td>brettwil-6830_ai</td><td>ML Workspace</td><td>Hub</td><td>eastus2</td><td>foundry</td></tr>
</table>

<p><i>Report generated by Azure SRE Agent — Monthly AI Workload Cost Analysis (scheduled task, May 2, 2026 18:57
UTC). Data source: FinOps Hub (msbwtreyhub.westus.kusto.windows.net). All metrics are ACTUAL DATA from Hub Costs()
function.</i></p>

---

## Insights saved to synthesized knowledge

The following block was written into
[finops-hub-health-check-findings.md](/api/files/memories/synthesizedKnowledge/finops-hub-health-check-findings.md)
under the existing `## AI Workload Cost Analysis Execution Notes` section (replacing the prior run's content for
that section). Only operational patterns — no financial figures:

```
### x_SkuDescription model naming patterns (additions)
- **Additional March 2026 patterns discovered:**
  - `GPT 5 Chat Inpt Glbl 1M Tokens - Preview` = GPT 5.0 standard input (preview, global)
  - `GPT 5 Chat cchd Inpt Glbl 1M Tokens - Preview` = GPT 5.0 cached input (preview, global)
  - `GPT 5 Chat outpt Glbl 1M Tokens - Preview` = GPT 5.0 output (preview, global)
  - `GPT 5.1 chat inp Gl 1M Tokens - Preview` = GPT 5.1 standard input (preview, global)
  - `GPT 5.1 chat cd inp Gl 1M Tokens - Preview` = GPT 5.1 cached input (preview, global)
  - `GPT 5.1 chat opt Gl 1M Tokens - Preview` = GPT 5.1 output (preview, global)
  - `5.3 chat inp Gl 1M Tokens - Preview` = GPT 5.3 standard input (preview, global) — note: no "GPT" prefix
  - `5.3 chat cd inp Gl 1M Tokens - Preview` = GPT 5.3 cached input (preview, global)
  - `5.3 chat opt Gl 1M Tokens - Preview` = GPT 5.3 output (preview, global)
  - `5.1 codex mini inp Gl 1M Tokens` = Codex Mini 5.1 input (global)
  - `5.1 codex mini opt Gl 1M Tokens` = Codex Mini 5.1 output (global)
  - `gpt 4.1 mini Inp Data Zone Tokens` = GPT 4.1 mini input (data zone)
  - `gpt 4.1 mini cached Inp DZone Tokens` = GPT 4.1 mini cached input (data zone)
  - `gpt 4.1 mini Outp Data Zone Tokens` = GPT 4.1 mini output (data zone)

### Resource Graph API for AI resource discovery (update)
- As of May 2026: 5 AI resources in `foundry` resource group — 2 Cognitive Services (AIServices), 1 SpeechServices,
1 ML Hub, 1 ML Project.

### Chart generation for AI reports (update)
- 3 charts (daily trend, model comparison, MoM comparison) generated successfully in a single Python execution.
- Dual-axis chart (bar + line) works well for showing tokens vs cost on daily trend.
- 3-panel horizontal comparison chart (tokens, cost, model diversity) effective for MoM visualization.
- Horizontal bar chart with color-coded cost tiers effective for model efficiency comparison.

### End-to-end AI analysis pipeline (update)
- **Confirmed 2nd consecutive monthly run (May 2, 2026 18:57 UTC):** All tools reliable, same execution pattern
works.

### Model lifecycle observations (new section)
- March 2026: 19 model variants active (GPT 5.0 Preview, 5.1 Preview, 5.2 GA, 5.3 Preview, Codex Mini 5.1, GPT 4.1
nano, GPT 4.1 mini).
- April 2026: Consolidated to 5 variants (GPT 5.2 GA input/cached/output, GPT 4.1 nano input/output).
- Preview models (GPT 5.0, 5.1, 5.3) and GPT 4.1 mini fully retired between billing periods.
- Codex Mini 5.1 also retired — very low usage in March (6,882 tokens total).
- Model consolidation is a natural cost reduction vector worth tracking monthly.
```

No other knowledge base files were created or modified during this run.
~~~~

## Finding tables
| Model | Direction | Tokens | Effective Cost | Cost/1K Tokens | % of Total Cost |
| --- | --- | --- | --- | --- | --- |
| GPT 5.2 | Standard Input | 2,900,953 | $5.08 | $0.00175 | 42.9% |
| GPT 5.2 | Cached Input | 24,815,360 | $4.34 | $0.000175 | 36.7% |
| GPT 5.2 | Output | 170,994 | $2.39 | $0.014 | 20.3% |
| GPT 4.1 nano | Input | 59,977 | $0.007 | $0.00011 | 0.06% |
| GPT 4.1 nano | Output | 8,661 | $0.004 | $0.00044 | 0.03% |
| TOTAL | 27,955,945 | $11.82 | $0.00042 | 100% |  |

| Metric | March 2026 | April 2026 | Change |
| --- | --- | --- | --- |
| Total Tokens | 75.33M | 27.96M | -62.9% |
| Total Cost | $33.92 | $11.82 | -65.1% |
| Cost per 1K Tokens | $0.00045 | $0.00042 | -6.2% |
| Model Variants | 19 | 5 | -73.7% |
| Active Days | ~30 | 9 | -70% |

| Model | Input Tokens | Output Tokens | I/O Ratio | Flag |
| --- | --- | --- | --- | --- |
| GPT 5.2 (April) | 27,716,313 | 170,994 | 162:1 | ⚠️ EXTREME |
| GPT 4.1 nano (April) | 59,977 | 8,661 | 6.9:1 | ✅ Normal |
| GPT 5.2 (March) | 32,366,945 | 411,698 | 79:1 | ⚠️ HIGH |
| GPT 5.1 Preview (March) | 22,997,534 | 140,247 | 164:1 | ⚠️ EXTREME |

| Resource | Environment | Cost Center | Model Family | Tokens | Cost | Share |
| --- | --- | --- | --- | --- | --- | --- |
| aiharishx2gd | dev | 1234 | GPT5 | 27.89M | $11.81 | 99.91% |
| aiharishx2gd | dev | 1234 | GPT 4.1 nano | 0.07M | $0.01 | 0.09% |
| TOTAL | 27.96M | $11.82 | 100% |  |  |  |

| # | Recommendation | Est. Monthly Savings | Priority |
| --- | --- | --- | --- |
| 1 | Prompt Context Optimization: GPT 5.2 I/O ratio of 162:1 is extreme. Reduce context window size by compressing, summarizing, or chunking prompts. A 50% reduction in standard input tokens would save ~$2.54/month. | $2.50 | HIGH |
| 2 | Model Substitution for Low-Complexity Tasks: If any GPT 5.2 workloads handle simple tasks (classification, extraction, summarization), switch to GPT 4.1 nano which costs 16x less per input token ($0.00011 vs $0.00175/1K). Even moving 10% of standard input to nano would save ~$0.46/month. | $0.46 | MEDIUM |
| 3 | Tag Governance & Showback: No application or team tags are set on AI resources. Implement mandatory tagging to enable per-team chargeback and cost accountability as AI usage scales. | Governance | MEDIUM |

| Resource | Type | Kind | Region | Resource Group |
| --- | --- | --- | --- | --- |
| brett-mmqxefcp-eastus | Cognitive Services | AIServices | eastus | foundry |
| foundy1125 | Cognitive Services | AIServices | eastus2 | foundry |
| foundy1125-speech | Cognitive Services | SpeechServices | eastus2 | foundry |
| brettwil-6560 | ML Workspace | Project | eastus2 | foundry |
| brettwil-6830_ai | ML Workspace | Hub | eastus2 | foundry |

## Recommendations
- No explicit recommendations surfaced in the final output.

## Knowledge updates
## Insights saved to synthesized knowledge

The following block was written into
[finops-hub-health-check-findings.md](/api/files/memories/synthesizedKnowledge/finops-hub-health-check-findings.md)
under the existing `## AI Workload Cost Analysis Execution Notes` section (replacing the prior run's content for
that section). Only operational patterns — no financial figures:

```
### x_SkuDescription model naming patterns (additions)
- **Additional March 2026 patterns discovered:**
  - `GPT 5 Chat Inpt Glbl 1M Tokens - Preview` = GPT 5.0 standard input (preview, global)
  - `GPT 5 Chat cchd Inpt Glbl 1M Tokens - Preview` = GPT 5.0 cached input (preview, global)
  - `GPT 5 Chat outpt Glbl 1M Tokens - Preview` = GPT 5.0 output (preview, global)
  - `GPT 5.1 chat inp Gl 1M Tokens - Preview` = GPT 5.1 standard input (preview, global)
  - `GPT 5.1 chat cd inp Gl 1M Tokens - Preview` = GPT 5.1 cached input (preview, global)
  - `GPT 5.1 chat opt Gl 1M Tokens - Preview` = GPT 5.1 output (preview, global)
  - `5.3 chat inp Gl 1M Tokens - Preview` = GPT 5.3 standard input (preview, global) — note: no "GPT" prefix
  - `5.3 chat cd inp Gl 1M Tokens - Preview` = GPT 5.3 cached input (preview, global)
  - `5.3 chat opt Gl 1M Tokens - Preview` = GPT 5.3 output (preview, global)
  - `5.1 codex mini inp Gl 1M Tokens` = Codex Mini 5.1 input (global)
  - `5.1 codex mini opt Gl 1M Tokens` = Codex Mini 5.1 output (global)
  - `gpt 4.1 mini Inp Data Zone Tokens` = GPT 4.1 mini input (data zone)
  - `gpt 4.1 mini cached Inp DZone Tokens` = GPT 4.1 mini cached input (data zone)
  - `gpt 4.1 mini Outp Data Zone Tokens` = GPT 4.1 mini output (data zone)

### Resource Graph API for AI resource discovery (update)
- As of May 2026: 5 AI resources in `foundry` resource group — 2 Cognitive Services (AIServices), 1 SpeechServices,
1 ML Hub, 1 ML Project.

### Chart generation for AI reports (update)
- 3 charts (daily trend, model comparison, MoM comparison) generated successfully in a single Python execution.
- Dual-axis chart (bar + line) works well for showing tokens vs cost on daily trend.
- 3-panel horizontal comparison chart (tokens, cost, model diversity) effective for MoM visualization.
- Horizontal bar chart with color-coded cost tiers effective for model efficiency comparison.

### End-to-end AI analysis pipeline (update)
- **Confirmed 2nd consecutive monthly run (May 2, 2026 18:57 UTC):** All tools reliable, same execution pattern
works.

### Model lifecycle observations (new section)
- March 2026: 19 model variants active (GPT 5.0 Preview, 5.1 Preview, 5.2 GA, 5.3 Preview, Codex Mini 5.1, GPT 4.1
nano, GPT 4.1 mini).
- April 2026: Consolidated to 5 variants (GPT 5.2 GA input/cached/output, GPT 4.1 nano input/output).
- Preview models (GPT 5.0, 5.1, 5.3) and GPT 4.1 mini fully retired between billing periods.
- Codex Mini 5.1 also retired — very low usage in March (6,882 tokens total).
- Model consolidation is a natural cost reduction vector worth tracking monthly.
```

No other knowledge base files were created or modified during this run.

## MCAPS asks this task answers
- **#7:** Reports AI token volume trend: 27.96M April tokens, down 62.9% MoM.
- **#25:** Attributes AI cost by resource and model; output notes this is not yet user/team chargeback.
- **#26:** Translates 27.96M tokens to $11.82 and cost per 1K tokens by model direction.
- **#29:** Shows model portfolio consolidation from 19 to 5 variants and GPT 5.2 dominance.
- **#30:** Flags 162:1 input-to-output ratio as prompt optimization opportunity.
- **#33:** Shows AI spend trend and PayGo exposure for finance forecast/brake-pedal discussions.
- **#69:** Provides a demo-ready AI FinOps agent card with charts and token economics.
