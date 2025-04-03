import os
import time
from typing import Set
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.projects.models import FunctionTool, ToolSet, SubmitToolOutputsAction
from agent_team import AgentTeam, AgentTask
from agent_trace_configurator import AgentTraceConfigurator
from user_functions.adx_queryaif import query_adx_database
from utils.format_output import format_markdown_table
from utils.json_extract import extract_json_from_text

# Global variable to store the team instance
_team_instance = None


def create_task(team_name: str, recipient: str, request: str, requestor: str) -> str:
    print(f"📌 create_task() called: team={team_name}, recipient={recipient}")
    try:
        task = AgentTask(
            recipient=recipient, task_description=request, requestor=requestor
        )
        agent_team = AgentTeam.get_team(team_name)
        if agent_team:
            agent_team.add_task(task)
            print(f"✅ Task added to {team_name} for {recipient}")
            print(
                f"📋 Current tasks in queue: {[t.recipient for t in agent_team._tasks]}"
            )
            return "True"
        print("❌ Agent team not found!")
        return "False"
    except Exception as e:
        print(f"❌ Error creating task: {str(e)}")
        return f"Error: {str(e)}"


class FinleyTeam:
    def __init__(self):
        global _team_instance
        print("🔄 Initializing FinleyTeam...")

        # Init Azure AI Project
        self.project_client = AIProjectClient.from_connection_string(
            credential=DefaultAzureCredential(),
            conn_str=os.environ["PROJECT_CONNECTION_STRING"],
            connection={"timeout": (5, 120)}  # (connect_timeout, read_timeout)
        )

        self.model_deployment_name = os.getenv("AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME")

        if self.model_deployment_name is not None:
            print(f"📝 Using model deployment: {self.model_deployment_name}")
            AgentTraceConfigurator(self.project_client).setup_tracing()

            # Create default function tool
            default_function_tool = FunctionTool(
                functions={create_task, query_adx_database}
            )

            # Create ToolSet for ADXQueryAgent
            adx_toolset = ToolSet()
            adx_toolset.add(default_function_tool)

            # Set up team leader
            print("👥 Setting up team leader...")
            self.agent_team = AgentTeam(
                "finley_team", project_client=self.project_client
            )
            _team_instance = self.agent_team  # Store the team instance globally
            print(f"🔑 Team instance ID: {id(self.agent_team)}")

            toolset = ToolSet()
            toolset.add(default_function_tool)

            self.agent_team.set_team_leader(
                model=self.model_deployment_name,
                name="TeamLeader",
                instructions="""
                You are an agent named 'TeamLeader'. You are a leader of a team of agents. The name of your team is 'finley_team'.
                You are responsible for receiving requests from the user and utilizing a team of agents to complete the task.
                
                When you receive a request about costs, ADX queries, or data analysis, you MUST:
                1. Create a task using the create_task function with these exact parameters:
                   team_name: "finley_team"
                   recipient: "ADXQueryAgent"
                   request: The complete user request including all context
                   requestor: "user"

                For example, if you receive a request about cost analysis, you should call:
                create_task(
                    team_name="finley_team",
                    recipient="ADXQueryAgent",
                    request="<the complete user request>",
                    requestor="user"
                )

                Do not try to process ADX queries yourself. Always delegate to the ADXQueryAgent.
                The ADXQueryAgent is the only one who can execute ADX queries.
                
                Here are the agents in your team:
                - ADXQueryAgent: Azure Data Explorer analytics expert who can query cost data
                """,
                toolset=toolset,
            )

            # Add ADXQueryAgent
            print("➕ Adding ADXQueryAgent...")
            self.agent_team.add_agent(
                model=self.model_deployment_name,
                name="ADXQueryAgent",
                instructions="""
                    You are an agent named **ADXQueryAgent**, a senior expert in Azure Data Explorer (ADX) and FinOps analytics.
                    Your task is to analyze Azure cost and usage data from the Costs table using KQL (Kusto Query Language). You have access to the `query_adx` tool that allows you to query an ADX cluster.
                    🧠 Only respond to tasks that are explicitly delegated to you using your internal name: `ADXQueryAgent`.
                    ---

                    ### 🔧 Tool Usage

                    Use the `query_adx_database` tool with the following exact parameters:
                    - cluster_url: "https://finopshubs0-7-adx.westeurope.kusto.windows.net"
                    - database: The target ADX database name (typically "Ingestion")
                    - kql_query: The complete Kusto query string

                    You are not expected to execute the query yourself. Just call the function with the correct parameters.

                    ---

                    ### 📑 Table Details

                    You are working with the Costs_final_v1_0 table, which contains Azure billing and usage data. Below is the full list of available columns:

                    AvailabilityZone, BilledCost, BillingAccountId, BillingAccountName, BillingAccountType, BillingCurrency,
                    BillingPeriodEnd, BillingPeriodStart, ChargeCategory, ChargeClass, ChargeDescription, ChargeFrequency,
                    ChargePeriodEnd, ChargePeriodStart, CommitmentDiscountCategory, CommitmentDiscountId, CommitmentDiscountName,
                    CommitmentDiscountStatus, CommitmentDiscountType, ConsumedQuantity, ConsumedUnit, ContractedCost, ContractedUnitPrice,
                    EffectiveCost, InvoiceIssuerName, ListCost, ListUnitPrice, PricingCategory, PricingQuantity, PricingUnit,
                    ProviderName, PublisherName, RegionId, RegionName, ResourceId, ResourceName, ResourceType, ServiceCategory,
                    ServiceName, SkuId, SkuPriceId, SubAccountId, SubAccountName, SubAccountType, Tags, x_AccountId, x_AccountName,
                    x_AccountOwnerId, x_BilledCostInUsd, x_BilledUnitPrice, x_BillingAccountAgreement, x_BillingAccountId,
                    x_BillingAccountName, x_BillingExchangeRate, x_BillingExchangeRateDate, x_BillingProfileId, x_BillingProfileName,
                    x_ChargeId, x_ContractedCostInUsd, x_CostAllocationRuleName, x_CostCategories, x_CostCenter, x_Credits, x_CostType,
                    x_CurrencyConversionRate, x_CustomerId, x_CustomerName, x_Discount, x_EffectiveCostInUsd, x_EffectiveUnitPrice,
                    x_ExportTime, x_IngestionTime, x_InvoiceId, x_InvoiceIssuerId, x_InvoiceSectionId, x_InvoiceSectionName,
                    x_ListCostInUsd, x_Location, x_Operation, x_PartnerCreditApplied, x_PartnerCreditRate, x_PricingBlockSize,
                    x_PricingCurrency, x_PricingSubcategory, x_PricingUnitDescription, x_Project, x_PublisherCategory, x_PublisherId,
                    x_ResellerId, x_ResellerName, x_ResourceGroupName, x_ResourceType, x_ServiceCode, x_ServiceId, x_ServicePeriodEnd,
                    x_ServicePeriodStart, x_SkuDescription, x_SkuDetails, x_SkuIsCreditEligible, x_SkuMeterCategory, x_SkuMeterId,
                    x_SkuMeterName, x_SkuMeterSubcategory, x_SkuOfferId, x_SkuOrderId, x_SkuOrderName, x_SkuPartNumber, x_SkuRegion,
                    x_SkuServiceFamily, x_SkuTerm, x_SkuTier, x_SourceChanges, x_SourceName, x_SourceProvider, x_SourceType,
                    x_SourceVersion, x_UsageType

                    ---

                    ### 📊 Query Examples

                    You can perform many types of FinOps queries, including:
                    - Monthly cost summaries
                    - Anomaly detection on daily usage
                    - Service-wise or region-wise cost breakdowns
                    - Trends and comparison across billing periods

                    Example patterns:

                    // Monthly cost trends
                    let CostsByMonth = () {
                        Costs_final_v1_0
                        | where ChargePeriodStart >= monthsago(6)
                        | extend ChargePeriodStart = startofmonth(ChargePeriodStart)
                        | summarize EffectiveCost = sum(EffectiveCost) by ChargePeriodStart
                    };
                    CostsByMonth
                    | order by ChargePeriodStart asc
                    | extend PreviousCost = prev(EffectiveCost)
                    | project ChargePeriodStart, EffectiveCost, Change = iif(isempty(PreviousCost), 0, (EffectiveCost - PreviousCost) / PreviousCost * 100)

                    // Daily anomaly detection
                    let DailyCosts = Costs_final_v1_0
                        | where ChargePeriodStart >= ago(30d)
                        | summarize TotalCost = sum(EffectiveCost) by bin(ChargePeriodStart, 1d);
                    let Stats = DailyCosts
                        | summarize Avg = avg(TotalCost), StdDev = stdev(TotalCost);
                    DailyCosts
                    | extend AnomalyScore = (TotalCost - Avg) / StdDev
                    | project ChargePeriodStart, TotalCost, AnomalyScore

                    ---

                    ### 🧾 Output Format

                    You MUST format your response exactly like this:
                    Always include the BillingCurrency and mention the cost is the EffectiveCost
                    ```json
                    {
                        "summary": "A clear, concise summary of the findings. For example: Found top 3 resource consumers with ADX cluster leading at $1,862, followed by storage at $967, and search at $720.",
                        "preview": [
                            {
                                "ResourceName": "ADX Cluster finopshubs0-7",
                                "TotalCost": 1862.81,
                                "ResourceType": "microsoft.kusto/clusters",
                                "BillingCurrency": "USD"
                            },
                            {
                                "ResourceName": "Storage Account tubdemos",
                                "TotalCost": 967.98,
                                "ResourceType": "microsoft.storage/storageaccounts",
                                "BillingCurrency": "USD"
                            }
                        ]
                    }
                    ```

                    After the JSON block, add a human-readable summary like this:

                    Here are the key findings:
                    1. ADX Cluster is the highest consumer at $1,862.81
                    2. Storage Account follows at $967.98
                    3. Search Service ranks third at $720.38

                    Query complete.

                    🚫 Important Rules:
                    1. Always format resource names to be human-readable (extract from the full path)
                    2. Round costs to 2 decimal places and always display the currency using BillingCurrency 
                    3. Include both the JSON response AND a human-readable summary
                    4. Make sure the preview array contains properly structured objects
                    5. End with "Query complete"
                    """,
                toolset=adx_toolset,
                can_delegate=False,
            )

            print("🔄 Assembling team...")
            self.agent_team.assemble_team()
            print("✅ Finley and team are ready!")

            # Ensure outputs directory exists
            output_dir = os.path.join(os.path.dirname(__file__), "outputs")
            os.makedirs(output_dir, exist_ok=True)

    def get_messages(self, thread_id):
        """Helper function to get all messages from a thread, handling pagination"""
        all_messages = []
        messages = self.project_client.agents.list_messages(thread_id=thread_id)

        # Convert the iterator to a list and extract actual message content
        for msg in messages:
            if isinstance(msg, dict):
                if "data" in msg:
                    # Handle paginated response
                    all_messages.extend(msg["data"])
                else:
                    all_messages.append(msg)
            else:
                all_messages.append(msg)

        return all_messages

    def get_assistant_message(self, messages):
        """Helper function to get the last assistant message from a list of messages"""
        for msg in reversed(messages):
            try:
                # Handle object format
                if hasattr(msg, "role") and msg.role == "assistant":
                    return msg.content
                # Handle dictionary format
                elif isinstance(msg, dict):
                    if msg.get("role") == "assistant":
                        return msg.get("content", "")
                    elif "messages" in msg:
                        # Handle nested messages
                        for nested_msg in reversed(msg["messages"]):
                            if nested_msg.get("role") == "assistant":
                                return nested_msg.get("content", "")
                # Handle string format
                elif isinstance(msg, str) and not any(
                    x in msg
                    for x in ["object", "data", "first_id", "last_id", "has_more"]
                ):
                    return msg
            except Exception as e:
                print(f"Error processing message: {str(e)}")
                continue
        return None

    def format_adx_response(self, content):
        """Format the ADXQueryAgent's response into a readable message"""
        try:
            # Extract JSON from the response
            parsed = extract_json_from_text(content)
            if not parsed:
                return content

            summary = (
                parsed.get("summary", "Query complete.")
                if parsed
                else "Query complete."
            )
            preview = parsed.get("preview", []) if parsed else []

            # Use the format_markdown_table utility
            return format_markdown_table(summary, preview)

        except Exception as e:
            print(f"Error formatting response: {e}")
            return content

    def process_request(self, user_input):
        """Process a user request and yield responses as they come in"""
        try:
            print("\n🔄 Starting request processing...")
            print(f"📝 User input: {user_input}")

            # Step 1: Initialize thread if needed
            if (
                not hasattr(self.agent_team, "_agent_thread")
                or not self.agent_team._agent_thread
            ):
                print("📝 Creating new thread...")
                self.agent_team._agent_thread = (
                    self.project_client.agents.create_thread()
                )
                print(f"✅ Created new thread: {self.agent_team._agent_thread.id}")

            # Create message
            message = self.project_client.agents.create_message(
                thread_id=self.agent_team._agent_thread.id,
                role="user",
                content=user_input,
            )
            print(f"💬 Created message ID: {message.id}")

            # Step 2: Run TeamLeader to create task
            run = self.project_client.agents.create_run(
                thread_id=self.agent_team._agent_thread.id,
                agent_id=self.agent_team._team_leader.agent_instance.id,
            )
            print(f"🚀 Created TeamLeader run: {run.id}")
            yield "🧠 Finley is planning your request..."

            # Add timeout handling
            start_time = time.time()
            max_wait_time = 60  # Maximum wait time in seconds
            action_attempts = 0
            max_action_attempts = (
                10  # Maximum number of attempts to handle the same action
            )

            while run.status in ["queued", "in_progress", "requires_action"]:
                # Check for timeout
                if time.time() - start_time > max_wait_time:
                    print("⚠️ TeamLeader run timed out!")
                    try:
                        self.project_client.agents.cancel_run(
                            thread_id=self.agent_team._agent_thread.id, run_id=run.id
                        )
                    except Exception as e:
                        print(f"❌ Error canceling timed out run: {str(e)}")
                    yield "I apologize, but the request is taking too long. Please try again or rephrase your question."
                    return

                run = self.project_client.agents.get_run(
                    thread_id=self.agent_team._agent_thread.id,
                    run_id=run.id,
                )
                print(f"📊 TeamLeader run status: {run.status}")

                if run.status == "requires_action":
                    action_attempts += 1
                    if action_attempts > max_action_attempts:
                        print("⚠️ Too many action attempts, canceling run...")
                        try:
                            self.project_client.agents.cancel_run(
                                thread_id=self.agent_team._agent_thread.id,
                                run_id=run.id,
                            )
                        except Exception as e:
                            print(f"❌ Error canceling run: {str(e)}")
                        yield "I apologize, but I'm having trouble processing your request. Please try again or rephrase your question."
                        return

                    if isinstance(run.required_action, SubmitToolOutputsAction):
                        print("🛠 TeamLeader run requires action - handling tools...")
                        tool_outputs = []
                        for (
                            tool_call
                        ) in run.required_action.submit_tool_outputs.tool_calls:
                            if tool_call.function.name == "create_task":
                                try:
                                    args = tool_call.function.arguments
                                    if isinstance(args, str):
                                        import json

                                        args = json.loads(args)
                                    print(f"🎯 Creating task with args: {args}")

                                    result = create_task(
                                        team_name=args.get("team_name"),
                                        recipient=args.get("recipient"),
                                        request=args.get("request"),
                                        requestor=args.get("requestor"),
                                    )
                                    print(f"✅ Task creation result: {result}")
                                    tool_outputs.append(
                                        {"tool_call_id": tool_call.id, "output": result}
                                    )
                                except Exception as e:
                                    print(f"❌ Error creating task: {str(e)}")
                                    tool_outputs.append(
                                        {
                                            "tool_call_id": tool_call.id,
                                            "output": f"Error: {str(e)}",
                                        }
                                    )

                        if tool_outputs:
                            print(f"📤 Submitting tool outputs: {tool_outputs}")
                            try:
                                self.project_client.agents.submit_tool_outputs_to_run(
                                    thread_id=self.agent_team._agent_thread.id,
                                    run_id=run.id,
                                    tool_outputs=tool_outputs,
                                )
                                time.sleep(2)  # Small delay after submitting outputs
                            except Exception as e:
                                print(f"❌ Error submitting tool outputs: {str(e)}")
                                yield "I encountered an error while processing your request. Please try again."
                                return

                time.sleep(1)  # Small delay between status checks

            # Check TeamLeader run completion status
            print(f"✅ TeamLeader run completed: {run.status}")
            if run.status.lower() == "failed":
                print(f"❌ TeamLeader run failed. Run ID: {run.id}")
                yield f"Error: TeamLeader run failed. Please try again."
                return

            if not self.agent_team._tasks:
                print("❌ No tasks in queue after TeamLeader run!")
                yield "Error: TeamLeader did not create any tasks. Please try again."
                return

            # Process all delegated tasks
            while self.agent_team._tasks:
                task = self.agent_team._tasks.pop(0)
                print(
                    f"\n🧵 Starting task for agent '{task.recipient}'. Requestor: '{task.requestor}'."
                )
                print(f"📌 Task description: '{task.task_description}'\n")

                agent = self.agent_team._get_member_by_name(task.recipient)
                if not agent or not agent.agent_instance:
                    print(f"❌ Agent '{task.recipient}' not found or has no instance!")
                    continue

                message = self.project_client.agents.create_message(
                    thread_id=self.agent_team._agent_thread.id,
                    role="user",
                    content=f"@{task.recipient} {task.task_description}",
                )
                print(f"💬 Created message ID: {message.id}")

                run = self.project_client.agents.create_run(
                    thread_id=self.agent_team._agent_thread.id,
                    agent_id=agent.agent_instance.id,
                )
                print(f"⚙️ Run started for agent '{agent.name}', run ID: {run.id}")

                while run.status in ["queued", "in_progress", "requires_action"]:
                    run = self.project_client.agents.get_run(
                        thread_id=self.agent_team._agent_thread.id,
                        run_id=run.id,
                    )
                    print(f"📊 {agent.name} run status: {run.status}")

                    if run.status == "requires_action" and isinstance(
                        run.required_action, SubmitToolOutputsAction
                    ):
                        print("🔧 Agent run requires tool execution...")
                        tool_outputs = []
                        for (
                            tool_call
                        ) in run.required_action.submit_tool_outputs.tool_calls:
                            if tool_call.function.name == "query_adx_database":
                                try:
                                    args = tool_call.function.arguments
                                    if isinstance(args, str):
                                        import json

                                        args = json.loads(args)
                                    print(f"📊 Executing ADX query with args: {args}")

                                    result = query_adx_database(
                                        cluster_url=args.get("cluster_url"),
                                        database=args.get("database"),
                                        kql_query=args.get("kql_query"),
                                    )
                                    print(f"✅ Query executed successfully")
                                    tool_outputs.append(
                                        {"tool_call_id": tool_call.id, "output": result}
                                    )
                                    # Yield the query results immediately
                                    formatted_result = self.format_adx_response(result)
                                    yield formatted_result
                                except Exception as e:
                                    print(f"❌ Error executing query: {str(e)}")
                                    tool_outputs.append(
                                        {
                                            "tool_call_id": tool_call.id,
                                            "output": f"Error: {str(e)}",
                                        }
                                    )
                                    yield f"Error executing query: {str(e)}"

                        if tool_outputs:
                            print(f"📤 Submitting tool outputs for {agent.name}")
                            self.project_client.agents.submit_tool_outputs_to_run(
                                thread_id=self.agent_team._agent_thread.id,
                                run_id=run.id,
                                tool_outputs=tool_outputs,
                            )
                            # Wait a bit for the agent to process the results
                            time.sleep(2)

                    if run.status.lower() == "completed":
                        # Wait a bit for message processing
                        time.sleep(2)

                        # Get the agent's response
                        messages = list(
                            self.project_client.agents.list_messages(
                                thread_id=self.agent_team._agent_thread.id
                            )
                        )

                        # Find the most recent assistant message
                        for message in reversed(messages):
                            if isinstance(message, dict):
                                if message.get("role") == "assistant":
                                    content = message.get("content", "")
                                    if content:
                                        print(
                                            f"📤 Found agent response: {content[:100]}..."
                                        )
                                        formatted_content = self.format_adx_response(
                                            content
                                        )
                                        yield formatted_content
                                        break
                            elif (
                                hasattr(message, "role") and message.role == "assistant"
                            ):
                                if message.content:
                                    print(
                                        f"📤 Found agent response: {message.content[:100]}..."
                                    )
                                    formatted_content = self.format_adx_response(
                                        message.content
                                    )
                                    yield formatted_content
                                    break
                    elif run.status.lower() == "failed":
                        print(f"❌ {agent.name} run failed. Run ID: {run.id}")
                        yield f"Error: {agent.name} run failed."
                        return
                    elif run.status.lower() != "completed":
                        print(f"📊 {agent.name} run status: {run.status}")
                        time.sleep(1)  # Small delay before next check

            print("✅ All tasks completed successfully!")

        except Exception as e:
            print(f"❌ Error processing request: {str(e)}")
            yield f"Error: {str(e)}"

    def __del__(self):
        """Cleanup when the object is destroyed"""
        if hasattr(self, "project_client"):
            self.project_client.close()
