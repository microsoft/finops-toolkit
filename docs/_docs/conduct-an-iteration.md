---
layout: default
title: "Conduct an iteration"
nav_order: 11
description: This tutorial helps you learn how to take an iterative approach to FinOps adoption.
permalink: /conduct-an-iteration
author: bandersmsft
ms.author: banders
ms.date: 06/21/2023
ms.topic: tutorial
ms.service: finops
ms.reviewer: micflan
---

<span class="fs-9 d-block mb-4">How to conduct a FinOps iteration</span>
Learn how to take an iterative approach to FinOps adoption within your organization.
{: .fs-6 .fw-300 }

[Learn more](#about){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-4 }
[Get started](#-define-your-scope){: .btn .fs-5 .mb-4 .mb-md-0 .mr-4 }

<details open markdown="1">
   <summary class="fs-2 text-uppercase">On this page</summary>

- [✋ Before you begin](#-before-you-begin)
- [🤔 Define your scope](#-define-your-scope)
- [🎯 Identify your goals](#-identify-your-goals)
- [🏃‍♀️ Put your plan into action](#️-put-your-plan-into-action)
- [🔍 Review progress](#-review-progress)
- [⏩ Next steps](#-next-steps)

</details>

---

<a name="about"></a>
FinOps is an iterative, hierarchical process that requires cross-functional collaboration across business, technology, and finance teams. When you consider the 18 different capabilities, each with their own unique nuances, adopting FinOps can seem like a daunting task. However, in this tutorial, you learn how to take an iterative approach to FinOps adoption where you:

<!--[!div class="checklist"]-->
- Define the right scope for your next FinOps investments.
- Identify measurable goals to achieve over the coming weeks or months.
- Select the right actions to get to the next maturity level.
- Review progress at the end of the iteration and identify goals for the next.

Use this tutorial as a guide when you start each iteration of the FinOps lifecycle.

<br>

## ✋ Before you begin

Consider the stakeholders involved in your iteration. Since FinOps requires collaboration across business, technology, and finance teams, we recommend approaching this tutorial holistically and evaluating each step with everyone in mind. However, there are also times when you may only have a subset of stakeholders. For example, a single engineering team, or just one FinOps practitioner dedicated to setting up the right culture and driving positive change within the organization. Whichever case applies to you in this iteration, keep all stakeholders' experience in mind as you complete this tutorial. Every balanced team has people with a diverse mix of experience levels. Make your best judgment about the team's current state.

<br>

## 🤔 Define your scope

Before you start your next iteration, it's important to define the bounds for which you want to focus to ensure your iteration goals are achievable. If it is your first iteration, we recommend selecting three to five FinOps capabilities as a starting point. If you're defining the scope of a later iteration, you may want to keep the same capabilities or add one to two new ones.

Use the information following as a guide to select the right FinOps capabilities based on your role, experience, and current priorities. It isn't an all-inclusive list of considerations. We encourage you to select all from one group or pick and choose across groups based on your current needs. It's merely an aid to help you get started.

1. If your team is new to FinOps with little to moderate experience with cost management and optimization, we recommend starting with the basics:
   1. Reporting and analytics
   2. Forecasting
   3. Budgeting
   4. Workload optimization
   5. Anomaly management
2. If you're building a new FinOps team or interested in driving awareness and adoption of FinOps, start with:
   1. FinOps practice operations
   2. Onboarding workloads
   3. FinOps assessment
   4. FinOps education and enablement
   5. Forecasting
3. If your team has a solid understanding of the basics provided by FinOps tools in Microsoft Cloud and is responsible for managing costs across a broad organization with distributed and sometimes shared ownership, consider:
   1. Allocation
   2. Invoicing and chargeback
   3. Rate optimization
4. If your team needs to build more advanced reporting, like managing costs across clouds or merging with business data, consider:
   1. Tools and services
   2. Data ingestion
   3. Allocation
   4. Reporting and analytics
5. If your team has a solid understanding of the basics and wants to focus on deeper optimization through advanced automation, consider:
   1. Architecting for the cloud
   2. Workload optimization
   3. Rate optimization
   4. Licensing and SaaS
   5. Cloud sustainability
   6. Cloud policy and governance
6. If your team has a solid understanding of the basics and needs to map cloud investments back to business value, consider:
   1. Unit economics
   2. Allocation
   3. Budgeting
   4. Planning and estimating

Note the capabilities you select for future use.

<br>

## 🎯 Identify your goals

Next, you identify specific, measurable goals based on your current experience with the capabilities you selected. Consider the following when you identify goals for this iteration:

- **Knowledge** – How much do you know about the capability?
  - If you're new to the capability, focus on learning the purpose, intent, and how to implement the basics. Knowledge is often the first step of any capability.
- **Process** – Is a repeatable process defined, documented, and verified?
  - If you know the basics, but don't have a predefined process, consider spending time documenting a repeatable process. Include how to implement the capability, roles and responsibilities for all stakeholders, and the metrics you use to measure success.
- **Metrics** – Have success metrics been identified, baselined, and automated?
  - If you're new to the capability, think about success metrics as you learn the basics. For example, cost vs. budget, and commitment utilization. They help with future iterations.
  - If you know the basics, but haven't identified success metrics, they're a must-have for your next step. Focus on identifying metrics that are relevant for your business and help you make trade-off decisions for this capability. Build these metrics and decisions into your process to maximize efficiency.
  - If you've identified metrics, focus on getting a baseline for where you're at today. Seek to automate wherever possible, which will save you time in the future. Use tools like Power BI to generate reports you can share with stakeholders and celebrate your collective successes.
- **Adoption** – How many teams have adopted the defined process and metrics?
  - If you have a process that has only been tested on a small scale, share it with others. Experiment with the process and incorporate a feedback loop for continuous improvement.
  - As your process matures, you notice less input from the feedback loop. Less input is a sign that your process is ready to be scaled out more and potentially be established as an official governance policy for new teams. If you're in a large organization that doesn't have a dedicated FinOps team, you may want to consider establishing one to drive this effort.  

    <!--[!IMPORTANT]-->
    <blockquote class="important" markdown="1">
      _Before establishing a dedicated FinOps team, consider how much time each individual team is spending on FinOps efforts, what the potential business value is with more savings and efficiency (or lost opportunity), and how much a dedicated team can accelerate those goals. A dedicated team is not for everyone. Ensure you have the right return on investment._
    </blockquote>

- **Automation** – Has the capability been automated to minimize manual effort?
  - If you're developing a process, we recommend identifying automation opportunities as you go. You may identify low-hanging fruit that could lead to large efficiency gains at scale or even find partner teams willing to contribute time in those areas and share resources.
  - As you experiment with your process, keep your list of automation opportunities updated and share them with others as part of the feedback loop. Prioritize automating success metrics and look for opportunities to implement the most repeated tasks for maximum efficiency.

In general, we recommend short iterations with targeted goals. Select one to three highly related goals listed previously. Avoid long iterations that cover a broad spectrum of work because they're harder to track, measure, and ultimately deliver.

<br>

## 🏃‍♀️ Put your plan into action

At this point, you have a rough plan of action. You may be new and plan on digging into the capability to learn and implement the basics. Or maybe you're planning to develop or experiment with a process being scaled out to other teams and stakeholders. Or maybe your process is already defined and you're driving full adoption or full automation. Whichever stage you're at, use the [FinOps Framework guidance](https://www.finops.org/framework/capabilities) to guide your efforts.

Check back later for more targeted guidance aligned with the FinOps Framework.

<br>

## 🔍 Review progress

When you started the iteration, you identified three to five capabilities, decided on the areas you wanted to focus on for those capabilities, and explored the capability guides. Were you able to achieve what you set out to do? What went well? What didn't go well? How could you improve the next iteration? Make note of your answers internally and review them at the end of each iteration to ensure you're addressing issues and maturing your process.

After you close out on the iteration, remember that this tutorial can help guide you through each successive iteration through the FinOps lifecycle. Start the tutorial over to prepare for your next iteration. Feel free to leave feedback on this page after every iteration to let us know if you find this information helpful and how we can improve it.

<br>

## ⏩ Next steps

In this tutorial, you learned how to:

<!--[!div class="checklist"]-->
- Define the right scope for your next FinOps investments.
- Identify measurable goals to achieve over the coming weeks or months.
- Select the right actions to get to the next maturity level.
- Review progress at the end of the iteration and identify goals for the next.

Review and refine the FinOps capabilities that are most critical to you:

- [FinOps capabilities](framework/capabilities/README.md)

For additional resources:

<!--[!div class="nextstepaction"]-->
- [Overview of the Well-Architected Framework cost optimization pillar](https://learn.microsoft.com/azure/well-architected/cost/overview)
