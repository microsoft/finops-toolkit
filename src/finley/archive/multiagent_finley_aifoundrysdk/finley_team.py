import os
from typing import Set
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.projects.models import (
    FunctionTool,
    ToolSet,
    SubmitToolOutputsAction
)
from agent_team import AgentTeam, AgentTask
from agent_trace_configurator import AgentTraceConfigurator
from user_functions.adx_queryaif import query_adx_database

# Init Azure AI Project
project_client = AIProjectClient.from_connection_string(
    credential=DefaultAzureCredential(),
    conn_str=os.environ["PROJECT_CONNECTION_STRING"],
)

model_deployment_name = os.getenv("AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME")


def create_task(team_name: str, recipient: str, request: str, requestor: str) -> str:
    print(f"📌 create_task() called: team={team_name}, recipient={recipient}")
    task = AgentTask(recipient=recipient, task_description=request, requestor=requestor)
    agent_team = AgentTeam.get_team(team_name)
    if agent_team:
        agent_team.add_task(task)
        print(f"✅ Task added to {team_name} for {recipient}")
        return "True"
    print("❌ Agent team not found!")
    return "False"


# Wrap functions into a FunctionTool
default_function_tool = FunctionTool(functions={create_task, query_adx_database})
# Create ToolSet for ADXQueryAgent with both functions
adx_toolset = ToolSet()
adx_toolset.add(default_function_tool)


# Register available functions
agent_team_default_functions: Set = {create_task, query_adx_database}

# Entry point
if model_deployment_name is not None:
    AgentTraceConfigurator(project_client).setup_tracing()

    with project_client:
        agent_team = AgentTeam("finley_team", project_client=project_client)

        toolset = ToolSet()
        toolset.add(default_function_tool)

        # Set up team leader
        agent_team.set_team_leader(
            model=model_deployment_name,
            name="TeamLeader",
            instructions="""
            You are an agent named 'TeamLeader'. You are a leader of a team of agents. The name of your team is 'finley_team'.
            You are responsible for receiving requests from the user and utilizing a team of agents to complete the task.
            You will use the provided create_task function to delegate tasks to the most appropriate agent.
            Respond with a summary of the task assignment. Do not create parallel tasks.
            Here are the agents in your team:
            - ADXQueryAgent: Azure Data Explorer analytics expert.
            """,
            toolset=toolset,
        )

        # Add ADXQueryAgent
        agent_team.add_agent(
            model=model_deployment_name,
            name="ADXQueryAgent",
            instructions="""
            You are an agent named 'ADXQueryAgent'. You are an expert in Azure Data Explorer (ADX).
            Use the `query_adx_database` tool to run KQL queries.
            Always request:
            - Full Kusto cluster URL
            - Target database name
            - KQL query string
            You are working with the `Costs_v1_0` table which contains Azure cost data.

            Required inputs:
            - The full Kusto cluster URL (e.g., https://<cluster>.<region>.kusto.windows.net)
            - The database name
            - The KQL query string
            This is the table:Costs_v1_0 
            These are all the columnames:(AvailabilityZone: string, BilledCost: decimal, BillingAccountId: string, BillingAccountName: string, BillingAccountType: string, BillingCurrency: string, BillingPeriodEnd: datetime, BillingPeriodStart: datetime, ChargeCategory: string, ChargeClass: string, ChargeDescription: string, ChargeFrequency: string, ChargePeriodEnd: datetime, ChargePeriodStart: datetime, CommitmentDiscountCategory: string, CommitmentDiscountId: string, CommitmentDiscountName: string, CommitmentDiscountStatus: string, CommitmentDiscountType: string, ConsumedQuantity: decimal, ConsumedUnit: string, ContractedCost: decimal, ContractedUnitPrice: decimal, EffectiveCost: decimal, InvoiceIssuerName: string, ListCost: decimal, ListUnitPrice: decimal, PricingCategory: string, PricingQuantity: decimal, PricingUnit: string, ProviderName: string, PublisherName: string, RegionId: string, RegionName: string, ResourceId: string, ResourceName: string, ResourceType: string, ServiceCategory: string, ServiceName: string, SkuId: string, SkuPriceId: string, SubAccountId: string, SubAccountName: string, SubAccountType: string, Tags: dynamic, x_AccountId: string, x_AccountName: string, x_AccountOwnerId: string, x_BilledCostInUsd: decimal, x_BilledUnitPrice: decimal, x_BillingAccountAgreement: string, x_BillingAccountId: string, x_BillingAccountName: string, x_BillingExchangeRate: decimal, x_BillingExchangeRateDate: datetime, x_BillingProfileId: string, x_BillingProfileName: string, x_ChargeId: string, x_ContractedCostInUsd: decimal, x_CostAllocationRuleName: string, x_CostCategories: dynamic, x_CostCenter: string, x_Credits: dynamic, x_CostType: string, x_CurrencyConversionRate: decimal, x_CustomerId: string, x_CustomerName: string, x_Discount: dynamic, x_EffectiveCostInUsd: decimal, x_EffectiveUnitPrice: decimal, x_ExportTime: datetime, x_IngestionTime: datetime, x_InvoiceId: string, x_InvoiceIssuerId: string, x_InvoiceSectionId: string, x_InvoiceSectionName: string, x_ListCostInUsd: decimal, x_Location: string, x_Operation: string, x_PartnerCreditApplied: string, x_PartnerCreditRate: string, x_PricingBlockSize: decimal, x_PricingCurrency: string, x_PricingSubcategory: string, x_PricingUnitDescription: string, x_Project: string, x_PublisherCategory: string, x_PublisherId: string, x_ResellerId: string, x_ResellerName: string, x_ResourceGroupName: string, x_ResourceType: string, x_ServiceCode: string, x_ServiceId: string, x_ServicePeriodEnd: datetime, x_ServicePeriodStart: datetime, x_SkuDescription: string, x_SkuDetails: dynamic, x_SkuIsCreditEligible: bool, x_SkuMeterCategory: string, x_SkuMeterId: string, x_SkuMeterName: string, x_SkuMeterSubcategory: string, x_SkuOfferId: string, x_SkuOrderId: string, x_SkuOrderName: string, x_SkuPartNumber: string, x_SkuRegion: string, x_SkuServiceFamily: string, x_SkuTerm: int, x_SkuTier: string, x_SourceChanges: string, x_SourceName: string, x_SourceProvider: string, x_SourceType: string, x_SourceVersion: string, x_UsageType: string)  
            Example Query:
            // baseQuery CostsByMonth
            let CostsByMonth = () {
                Costs_v1_0
                | where ChargePeriodStart >= monthsago(numberOfMonths) and ChargePeriodStart < startofday(ago(1d))
                | extend ChargePeriodStart = startofmonth(ChargePeriodStart)
                | extend BillingPeriodStart = startofmonth(BillingPeriodStart)
            };
            CostsByMonth
            | summarize EffectiveCost = sum(EffectiveCost) by BillingPeriodStart
            | order by BillingPeriodStart asc
            | extend PreviousEffectiveCost = prev(EffectiveCost)
            | project BillingPeriodStart, EffectiveCost, Change = iif(isempty(PreviousEffectiveCost), todouble(0), todouble((EffectiveCost - PreviousEffectiveCost) / PreviousEffectiveCost)) * 100

            Return a summary and format the preview as a markdown table.
            """,
            toolset=adx_toolset,
        )

        # Add Reviewer
        # agent_team.add_agent(
        #     model=model_deployment_name,
        #     name="Reviewer",
        #     instructions="You are a software engineer who reviews code. Your name is Reviewer.",
        # )

        agent_team.assemble_team()
        print("✅ Finley and team are available for requests.")

        # Ensure outputs directory exists
        output_dir = os.path.join(os.path.dirname(__file__), "outputs")
        os.makedirs(output_dir, exist_ok=True)

        while True:
            user_input = input("Input (type 'quit' or 'exit' to exit): ")
            if user_input.lower() in {"quit", "exit"}:
                print("👋 Cleaning up and exiting...")
                break

            # Step 1: Submit request to the team (creates thread + message)
            agent_team.process_request(user_input)

            # Step 2: Handle TeamLeader run and tool calls (e.g., create_task)
            run = project_client.agents.create_run(
                thread_id=agent_team._agent_thread.id,
                agent_id=agent_team._team_leader.agent_instance.id,
            )
            print(f"🚀 Created TeamLeader run: {run.id}")

            while run.status in ["queued", "in_progress", "requires_action"]:
                run = project_client.agents.get_run(
                    thread_id=agent_team._agent_thread.id,
                    run_id=run.id,
                )

                if run.status == "requires_action" and isinstance(
                    run.required_action, SubmitToolOutputsAction
                ):
                    print("🛠 TeamLeader run requires action - handling tools...")
                    tool_outputs = []
                    if tool_outputs:
                        project_client.agents.submit_tool_outputs_to_run(
                            thread_id=agent_team._agent_thread.id,
                            run_id=run.id,
                            tool_outputs=tool_outputs
                        )

            # ✅ Log TeamLeader run outcome
            print(f"✅ TeamLeader run completed: {run.status}")
            if run.status.lower() == "failed":
                print(f"❌ TeamLeader run failed. Run ID: {run.id}")
            else:
                print(
                    f"✅ TeamLeader run completed successfully. Final status: {run.status}"
                )

            try:
                messages = project_client.agents.list_messages(
                    thread_id=agent_team._agent_thread.id
                )
            except Exception as e:
                print(f"❌ Error while saving markdown table: {e}")

            # FOR DEBUGGING:
            import pprint
            print("🔎 Debugging TeamLeader run failure. Dumping run object:")
            pprint.pprint(vars(run))
            print(
                f"📋 Tasks in queue: {[task.recipient for task in agent_team._tasks]}"
            )

            # Step 3: Process all delegated tasks
            while agent_team._tasks:
                task = agent_team._tasks.pop(0)
                print(
                    f"\n🧵 Starting task for agent '{task.recipient}'. Requestor: '{task.requestor}'."
                )
                print(f"📌 Task description: '{task.task_description}'\n")

                agent = agent_team._get_member_by_name(task.recipient)
                if agent and agent.agent_instance:
                    message = project_client.agents.create_message(
                        thread_id=agent_team._agent_thread.id,
                        role="user",
                        content=task.task_description,
                    )
                    print(
                        f"💬 Created message ID: {message.id} in thread {agent_team._agent_thread.id}"
                    )

                    run = project_client.agents.create_run(
                        thread_id=agent_team._agent_thread.id,
                        agent_id=agent.agent_instance.id,
                    )
                    print(f"⚙️ Run started for agent '{agent.name}', run ID: {run.id}")

                    while run.status in ["queued", "in_progress", "requires_action"]:
                        run = project_client.agents.get_run(
                            thread_id=agent_team._agent_thread.id,
                            run_id=run.id,
                        )
                        if run.status == "requires_action" and isinstance(
                            run.required_action, SubmitToolOutputsAction
                        ):
                            print("🔧 Agent run requires tool execution...")
                            tool_outputs = []

                        agent_team.dismantle_team()
                        print("👥 Team dismantled successfully.")

else:
    print("Error: Please define the environment variable MODEL_DEPLOYMENT_NAME.")
