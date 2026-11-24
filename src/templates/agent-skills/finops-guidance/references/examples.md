# Worked examples

Load this reference when a question resembles one of these examples. They show the expected behavior. They aren't scripts to repeat. The rules in `SKILL.md` still apply.

Someone asks: "Should we buy reservations or a savings plan?"
The fit depends on how stable and predictable the workload is. Ask: "Is this a steady, known VM footprint, or a mix that changes across services or regions?" Then stop and wait. With that context, give the documented comparison, the applicable exchange and refund rules, and the practical trade-off. Recommend; don't purchase.

Someone asks: "Does this toolkit feature work in our sovereign cloud?"
Check the current documentation for that feature and cloud. If it explicitly covers the cloud, answer with that source. If it doesn't, say: "I couldn't verify support for that cloud in the documentation I could access. That's unconfirmed, not evidence that it's unsupported," and point to the documented way to confirm.

Someone asks: "Our Azure costs jumped 40%. Why?"
If the user has no breakdown yet, don't open with a question: name the tool that produces one, what to bring back for two comparable periods (complete months, or the same elapsed days of each month), and the candidate drivers you'll check. If they have figures and the wording points to a partial period, such as "this month," ask: "Are you comparing complete months, or this month so far with all of last month?" Then stop and wait. With comparable data, work through Explaining a cost change in `references/cost-figures.md`. Don't call it an expired reservation until its end date or status is confirmed. Show how the drivers and any unexplained remainder add up to the change, label each one-time, recurring or trending, and say which report would confirm the main driver next period.

Someone asks: "Our FinOps hub savings report shows zero savings. Is the toolkit broken?"
Sort it before recommending a fix. The toolkit's savings documentation shows zero savings both when list or contracted prices are missing and when no discount applies, so zero doesn't by itself mean the toolkit is broken. Confirm that on the current "Understanding savings calculations in FinOps toolkit" page, ask the one question that best separates the explanations, such as whether price sheet exports feed that hub, then stop and wait. Don't call it a defect, or suggest escalating it as one, unless the evidence or a documented known issue for their hub or report version supports it.

Someone asks: "The setup matches the documentation, but it still fails. What could explain it?"
Use the known tool, version and symptom to read the documented troubleshooting guidance and known issues. Ask about one blocking variable before a version-specific conclusion. If converging verified facts meet the inference bar in `references/evidence-backed-inference.md`, give a "High-confidence inference (not confirmed)" with a short evidence summary, an alternative that could change it, and a low-risk read-only check. Otherwise, label a tentative hypothesis or ask for the evidence that would decide it. Never call an untested workaround a verified fix.
