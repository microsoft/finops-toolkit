<!-- markdownlint-disable MD041 -->

This document outlines the high-level support escalation process. The goal of this document is to raise awareness of contributors' roles and responsibilities within the support process. This document is not intended to offer a detailed, end-to-end process for how toolkit consumers submit and resolve support requests.

On this page:

- [🙋‍♀️ Support requests](#️-support-requests)
- [🔎 Escalation process](#-escalation-process)

---

## 🙋‍♀️ Support requests

Tools and resources within the FinOps toolkit are provided as-is without any express or implied warranties. Microsoft Support does not handle support requests for the FinOps toolkit, however the underlying products leveraged by tools in the toolkit are officially supported.

> [!NOTE]
> The term "tool" is being used to indicate a software offering. "Products" are tools that are operationally managed by Microsoft. "Solutions" are preconfigured tools that may use a mix of managed products and custom code and are deployed and managed by you (or another organization on your behalf).

If you run into an issue, we recommend taking the following actions:

1. **Report security issues securely.**<br>If you believe you've found a security vulnerability, refer to [Reporting security issues](../tree/dev/SECURITY.md).<br>&nbsp;
2. **Confirm all setup instructions were completed in order.**<br>9 out of 10 issues are due to missing steps. Please follow instructions carefully.<br>&nbsp;
3. **Review the [troubleshooting guide](https://aka.ms/ftk/trouble).**<br>The most common issues and their solutions are documented and should be able to be resolved indepdentently.<br>&nbsp;
4. **Identify the source of the issue.**<br>For error messages, what product is showing the error? Does the error refer to another product? For missing or incorrect data, is the data generated in Power BI report or does it come directly from a product, like Cost Management?<br>&nbsp;
5. **Create support requests for product issues.**<br>If the source of the issue is a managed product (including data from Cost Management), create a Microsoft support request for that specific product. If you're not sure, ask in the [Q&A discussion forum](../discussions/categories/q-a).<br>&nbsp;
6. **Create an issue in GitHub.**<br>Whether you submit a support request or not, we recommend [creating an issue](https://aka.ms/ftk/idea) to let us know about the problems you're facing. Even if the issue is a product bug, we would like to document it to help others.

We try to respond to issues and discussions within 2 business days but there can sometimes be unanticipated delays. If you've completed all steps above and the issue has not been resolved within a week, join our [biweekly office hours](https://aka.ms/ftk/office-hours) to get live help from the team. If you need more hands-on support, you can request a paid, community-driven advisory session or consulting delivery during the office hours call.

> [!NOTE]
> Internal Microsoft employees are encouraged to utlize this same process for any issues. However, you are welcome to ping Microsoft employees in Microsoft Teams.

<br>

## 🔎 Escalation process

**Issues and discussions** are reviewed periodically through the week. [[Advisory council]] members and key contributors will be looped into issues and discussions as needed. Council members are expected to respond within 2 business days and be available for a Teams call should the issue not be resolved asynchronously within a week.

Microsoft Support will attempt to resolve **support requests** using internal troubleshooting guides. Some products, like Power BI, have connectors owned by different teams and may route issues one or more times before finding the right contact. For this reason, offering detailed troubleshooting guides is critical. When the issue is not resolved, Microsoft Support will typically contact the primary contributors in the repo, which are typically [[Governing board]] and [[Advisory council]] members. Board and council members are expected to respond within 1 business day for support escalations, loop in relevant contributors, and ideally facilitate a Teams call getting scheduled within the next 2 business days.

**Security issues** are managed by the Microsoft Security Response Center (MSRC), which will contact members of the [[Governing board]] should any issues arise. Board members are expected to loop in the key contributors for the tool in question including the [[Advisory council]] representative within 1 business day. Microsoft employees are expected to prioritize security issues above other work.

<br>
