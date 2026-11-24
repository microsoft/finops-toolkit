# Clarifying questions and context

Load this reference for the realistic options to offer in a clarifying question, and for wording a context line when a variable was inferred. The accuracy gate and the rules for reusing context are in `SKILL.md`, and they still apply.

## Branch variables

Answers in Azure and AI FinOps often depend on something the person hasn't said. These are the branch variables:

- Product and plan: Azure service, Foundry model and deployment, GitHub Copilot developer product and plan, Microsoft 365 Copilot entitlement, or Copilot Studio agent and harness. Identify the billing model and unit instead of treating everything called Copilot as one product.
- Agreement type: Enterprise Agreement (EA), Microsoft Customer Agreement (MCA), Microsoft Partner Agreement or Cloud Solution Provider (CSP), pay-as-you-go (a Microsoft Online Services Program account, MOSP, also written MOSA on Learn, or in some regions an MCA billing account, so check the account type), sponsorship or credits.
- Cloud: Azure commercial, Azure Government or another sovereign cloud, such as Azure operated by 21Vianet.
- Scope: billing account or enrollment, billing profile, invoice section, department or enrollment account, management group, subscription or resource group.
- Data path: Cost Management in the portal, exports to storage, the Cost Details or Exports APIs, FinOps hubs, Power BI, Microsoft Fabric or Azure Data Explorer.
- Dataset and consumer: actual cost, amortized cost, FOCUS, price sheet, reservation details, recommendations or transactions, and the report, template or schema that consumes it.
- Tool: FinOps hubs, Power BI reports, workbooks, Azure Optimization Engine, the PowerShell module, Bicep Registry modules, FinOps alerts, FinOps Explorer, Azure Advisor, Cost Management budgets or native portal features.
- Run context: local PowerShell (Windows PowerShell or PowerShell 7), Azure Cloud Shell or a pipeline; the identity and roles available; whether the person can create resources or only read. Distinguish the person configuring a service from the identity it uses at run time.
- Version and lifecycle: the installed tool or report version, API or dataset version, model version, and preview or general availability status.
- Commitment type: reservation or savings plan, term, scope, exchange and refund rules, and purchase date.

## Making context visible

Make the established context visible. When an answer depends on branch variables, name the ones it relies on in a few words, preferably inside the opening sentence ("For an MCA billing profile in Azure commercial, ...") or, when several apply, in one short "Assuming:" line before it. Show it in the first answer that relies on it, and again only when it changes or a later answer relies on a different variable. Infer only what the user's words establish, and say when a variable was inferred rather than stated ("Assuming EA, based on 'enrollment'"). If an inference could be wrong in a way that changes the answer, ask under the accuracy gate instead. For example, "billing profile" rules out an Enterprise Agreement but doesn't distinguish a Microsoft Customer Agreement from a Microsoft Partner Agreement. Don't ask the user to reconfirm established context each turn. Skip this for conceptual or general answers, greetings and clarification-only turns.
