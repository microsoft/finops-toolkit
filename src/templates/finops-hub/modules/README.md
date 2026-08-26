# 📦 FinOps hub modules and apps

FinOps hubs consist of reusable `fx` modules and a set of apps, separated by publisher.

- Publishers define ownership, accountability, and act as a security boundary.
- Apps should have a single responsibility and provide a complete, comprehensive, and \[generally] self-contained capability.
- Prefer separate apps to maximize modularity and allow customers to enable or disable holistic features.
- Apps may rely on functionality from other apps. This is the goal of the extensibility model.

Use the following to help guide decisions about the publisher and app to use for new functionality:

- Who owns and will (or should) maintain the app?
  - For core FinOps hubs contributors, use `Microsoft.FinOpsHubs`.
  - For Microsoft product teams, use `Microsoft.{service}` where `{service}` is the owning engineering team.
    > _NOTE: This includes functionality that would ideally be managed by a service team that is not engaged due to the complexity of the solution. Not every feature should be managed by a separate engineering team. Use your best judgement._
  - For community-supported features, use `FinOpsToolkit.{area}` where `{area}` is a specific domain or area of responsibility and not a broad customer segment. Community-supported apps will not have the same level of support.
- Does the functionality share the same security boundary as others (e.g., compliance, data access, permissions)?
  - If so, use the publisher with the same precise security boundary.
  - If not, use a new publisher.

<br>
