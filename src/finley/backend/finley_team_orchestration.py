import os
import sys
import time
import re
from urllib.parse import urlparse
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    FunctionTool,
    ToolSet,
    SubmitToolOutputsAction,
    AzureAISearchTool,
    MessageRole,
    ListSortOrder,
    ResponseFormatJsonSchema,
    ResponseFormatJsonSchemaType,
    RunStep,
    ThreadRun,
    ThreadMessage,
    AgentEventHandler,
    MessageDeltaChunk,
)
from agent_team import AgentTeam, AgentTask
from agent_trace_configurator import AgentTraceConfigurator
from utils.safe_serialize import safe_serialize

# from user_functions.vector_search import run_vector_search
from utils.format_output import format_markdown_table
from utils.json_extract import extract_json_from_text
from utils.schemas import ADXQueryResult
from user_functions.adxagent_functions import query_adx_database, run_vector_search2
from user_functions.search_kql_docs import search_kql_docs_vector_only
from datetime import datetime

import json
import logging

# === Setup ===
load_dotenv()
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(parent_dir)


# === Globals ===
_team_instance = None
# Setup logging
logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)


# === Load Prompts ===
def load_prompt(filepath: str) -> str:
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()


today = datetime.utcnow().strftime("%A, %Y-%m-%d")

# TEAM_LEADER_INSTRUCTIONS = load_prompt("agent_instructions/team_leader.txt")
ADX_QUERY_AGENT_INSTRUCTIONS = load_prompt("agent_instructions/adx_query_agent.txt")
ADX_QUERY_AGENT_INSTRUCTIONS += f"\n\nToday's date is {today} (UTC). Use this if you're analyzing time ranges or forecasting."
TEAM_LEADER_INSTRUCTIONS = load_prompt("agent_instructions/team_leader.txt")
TEAM_LEADER_INSTRUCTIONS += f"\n\nToday's date is {today}."

model = os.environ["AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME"]


def safe_tool_output(result, max_length=1048576):
    try:
        serialized = safe_serialize(result)
        if len(serialized) > max_length:
            print(f"⚠️ Tool output too large ({len(serialized)} chars), truncating.")
            return json.dumps(
                {
                    "summary": "Output was too large and has been truncated.",
                    "truncated": True,
                    "preview": (
                        result.get("preview", [])[:50]
                        if isinstance(result, dict)
                        else "Truncated output"
                    ),
                }
            )
        return serialized
    except Exception as e:
        return json.dumps({"error": f"Serialization failed: {str(e)}"})


def create_task(team_name: str, recipient: str, request: str, requestor: str) -> str:
    global _team_instance
    print(f"📌 Creating task for {recipient} in {team_name}")
    if _team_instance is None:
        return "❌ Agent team is not registered"
    try:
        task = AgentTask(
            recipient=recipient, task_description=request, requestor=requestor
        )
        _team_instance.add_task(task)
        print(f"✅ Task added: {request} ➜ {recipient}")
        return "True"
    except Exception as e:
        return f"❌ Failed to create task: {e}"


class StreamingEventHandler(AgentEventHandler):
    def __init__(self, project_client, functions: FunctionTool) -> None:
        super().__init__()
        self.functions = functions
        self.project_client = project_client
        self.submitted_tool_ids = set()

    def on_message_delta(self, delta: MessageDeltaChunk) -> None:
        if delta.text:
            print(f"🔹 Delta: {delta.text}")

    def on_thread_message(self, message: ThreadMessage) -> None:
        print(f"📨 Message status: {message.status}")

    def on_thread_run(self, run: ThreadRun) -> None:  # type: ignore
        print(f"🧠 Run status: {run.status}")

        if run.status == "failed":
            print(f"❌ Run failed. Error: {run.last_error}")

        if run.status == "requires_action" and isinstance(
            run.required_action, SubmitToolOutputsAction
        ):
            print("🔧 Agent run requires tool execution...")
            tool_outputs = []

            for tool_call in run.required_action.submit_tool_outputs.tool_calls:
                if tool_call.type == "function":
                    args = tool_call.function.arguments
                    if isinstance(args, str):
                        args = json.loads(args)
                    print(
                        f"🛠 Tool '{tool_call.function.name}' called with args: {args}"
                    )

                    if tool_call.function.name == "run_vector_search2":
                        try:
                            query = args.get(
                                "question"
                            )  # Match param to function signature
                            print(f"🔍 Running vector search: {query}")
                            result = run_vector_search2(query)
                            tool_outputs.append(
                                {
                                    "tool_call_id": tool_call.id,
                                    "output": safe_serialize(result),
                                }
                            )
                            yield f"**Vector search result:** {result}"
                        except Exception as e:
                            print(f"❌ Error in run_vector_search: {str(e)}")
                            tool_outputs.append(
                                {
                                    "tool_call_id": tool_call.id,
                                    "output": f"Error: {str(e)}",
                                }
                            )
                            yield f"Error: {str(e)}"

                    elif tool_call.function.name == "query_adx_database":
                        try:
                            print(f"📊 Executing ADX query: {args}")
                            result = query_adx_database(
                                cluster_url=args.get("cluster_url"),
                                database=args.get("database"),
                                kql_query=args.get("kql_query"),
                            )
                            print("✅ ADX query complete")
                            tool_outputs.append(
                                {
                                    "tool_call_id": tool_call.id,
                                    "output": safe_tool_output(result),
                                }
                            )
                        except Exception as e:
                            print(f"❌ Error in query_adx_database: {str(e)}")
                            tool_outputs.append(
                                {
                                    "tool_call_id": tool_call.id,
                                    "output": f"Error: {str(e)}",
                                }
                            )
                            yield f"Error: {str(e)}"

                    elif tool_call.function.name == "azure_ai_search_tool":
                        try:
                            query = args.get(
                                "search_text",
                                args.get("question") or args.get("query_text"),
                            )
                            print(f"🔎 Running Azure AI Search tool: {query}")
                            result = "⚠️ Replace with real AzureAISearchTool execution if needed"
                            tool_outputs.append(
                                {
                                    "tool_call_id": tool_call.id,
                                    "output": safe_serialize(result),
                                }
                            )
                            yield f"**AI Search result:** {result}"
                        except Exception as e:
                            print(f"❌ Error in AzureAISearchTool: {str(e)}")
                            tool_outputs.append(
                                {
                                    "tool_call_id": tool_call.id,
                                    "output": f"Error: {str(e)}",
                                }
                            )
                            yield f"Error: {str(e)}"

    def on_run_step(self, step: RunStep) -> None:
        print(f"🔄 Step: {step.type}, Status: {step.status}")

    def on_error(self, data: str) -> None:
        print(f"❌ Stream error: {data}")

    def on_done(self) -> None:
        print("✅ Streaming completed")

    def on_unhandled_event(self, event_type: str, event_data: any) -> None:
        print(f"📦 Unhandled event: {event_type}, data: {event_data}")


class FinleyTeam:
    def __init__(self, user_request: str = ""):
        global _team_instance
        print("🔄 Initializing FinleyTeam...")

        # ✅ Create Azure AI Project Client
        self.project_client = AIProjectClient.from_connection_string(
            credential=DefaultAzureCredential(),
            conn_str=os.environ["PROJECT_CONNECTION_STRING"],
            connection={"timeout": (5, 60)},
        )
        # Optional tracing
        AgentTraceConfigurator(self.project_client).setup_tracing()

        self.model_deployment_name = os.getenv("AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME")
        if not self.model_deployment_name:
            raise RuntimeError("❌ Missing AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME")
        self.modelstructured = os.environ[
            "AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME_STRUCTURED"
        ]

        print(f"📝 Using model deployment: {self.model_deployment_name}")

        # 🔍 Azure Cognitive Search tool setup
        search_connection_id = os.getenv("AI_SEARCH_CONNECTION_ID")
        if not search_connection_id:
            raise RuntimeError(
                "❌ Missing AI_SEARCH_CONNECTION_ID. Please set it in environment."
            )

        search_index = os.environ.get("AI_SEARCH_INDEX_NAME", "azureblob-index")
        print(f"⚠️ Debug: AI Search index = '{search_index}'")

        ai_search_tool = AzureAISearchTool(
            index_connection_id=search_connection_id,
            index_name=search_index,
            top_k=1,
        )

        # ✅ Setup default toolset for TeamLeader
        default_function_tool = FunctionTool(functions={create_task})
        toolset = ToolSet()
        toolset.add(default_function_tool)

        # ✅ Toolset for ADXQueryAgent
        adx_toolset = ToolSet()
        # Add Azure AI Search tool to ADXQueryAgent
        # adx_grounding_tool = FunctionTool(functions={search_kql_docs_hybrid})
        adx_combined_tool = FunctionTool(
            functions={search_kql_docs_vector_only, query_adx_database}
        )
        adx_toolset.add(adx_combined_tool)

        adx_response_format = ResponseFormatJsonSchemaType(
            json_schema=ResponseFormatJsonSchema(
                name="adx_query_result",
                description="Structured output from ADX queries with required BillingCurrency and dynamic row data.",
                schema=ADXQueryResult.model_json_schema(),
            )
        )

        # ✅ Set up Agent Team
        print("👥 Setting up team leader...")
        self.agent_team = AgentTeam("finley_team", project_client=self.project_client)
        _team_instance = self.agent_team  # so create_task can access it

        print(f"🔑 Agent team instance ID: {id(self.agent_team)}")

        # 🧠 Register Team Leader
        self.agent_team.set_team_leader(
            model=self.model_deployment_name,
            name="TeamLeader",
            instructions=TEAM_LEADER_INSTRUCTIONS,
            toolset=toolset,
            headers={
                "x-azureai-temperature": "0.7",
                "x-azureai-top-p": "0.9",
                "x-azureai-frequency-penalty": "0",
                "x-azureai-presence-penalty": "0",
            },
        )

        # ➕ Add ADX Query Agent
        print("➕ Adding ADXQueryAgent...")
        # Only build prompt if a request is passed
        self.agent_team.add_agent(
            model=self.modelstructured,
            name="ADXQueryAgent",
            instructions=ADX_QUERY_AGENT_INSTRUCTIONS,
            toolset=adx_toolset,
            can_delegate=True,
            headers={
                "x-azureai-temperature": "0.3",
                "x-azureai-top-p": "0.95",
                # "x-azureai-max-tokens": "2048",
                "x-ms-enable-preview": "true",
            },
            response_format=adx_response_format,
            # headers={"x-ms-enable-preview": "true"}
        )

        # ✅ Show registered agents
        print("📋 Registered agents:")
        for member in self.agent_team._members:
            print(
                f" - {member.name}: instance set = {member.agent_instance is not None}"
            )

        # 🧱 Finalize team
        print("🔄 Assembling team...")
        self.agent_team.assemble_team()
        _team_instance = self.agent_team

        print("✅ Finley and team are available for requests.")

    def submit_tool_outputs(self, thread_id, run_id, tool_outputs):
        try:
            self.project_client.agents.submit_tool_outputs_to_run(
                thread_id=thread_id,
                run_id=run_id,
                tool_outputs=tool_outputs,
            )
            print(f"📤 Submitted {len(tool_outputs)} tool output(s) for run {run_id}")
        except Exception as e:
            print(f"❌ Failed to submit tool outputs: {e}")
            raise

    def get_messages(self, thread_id):
        all_messages = []
        messages = self.project_client.agents.list_messages(thread_id=thread_id)
        logger.debug("Debug: printing all messages from the thread:")
        for i, m in enumerate(messages):
            role = m.get("role")
            content = m.get("content", "")
            logger.debug(f"[{i}] role={role} content={content[:80]}...")
        for msg in messages:
            if isinstance(msg, dict):
                if "data" in msg:
                    all_messages.extend(msg["data"])
                else:
                    all_messages.append(msg)
            else:
                all_messages.append(msg)
        return all_messages

    def get_assistant_message(self, messages):
        for msg in reversed(messages):
            try:
                if isinstance(
                    msg, dict
                ):  # Ensure msg is a dictionary before accessing .get()
                    if msg.get("role") == "assistant":
                        return msg.get("content", "")
                    elif "messages" in msg:
                        for nested_msg in reversed(msg["messages"]):
                            if nested_msg.get("role") == "assistant":
                                return nested_msg.get("content", "")
                elif isinstance(msg, str) and not any(
                    x in msg
                    for x in ["object", "data", "first_id", "last_id", "has_more"]
                ):
                    return msg
                else:
                    logger.warning(f"Unexpected message type: {type(msg)}. Skipping...")
            except Exception as e:
                logger.error(f"Error processing message: {str(e)}")
                continue
        return None

    def format_adx_response(self, content):
        try:
            parsed = extract_json_from_text(content)
            if not parsed:
                return content

            summary = parsed.get("summary", "Query complete.")
            preview = parsed.get("preview", [])

            # 🌟 Format summary with better structure
            summary_lines = []

            if isinstance(summary, str):
                summary_lines.append(f"**Summary**\n\n{summary.strip()}")
            elif isinstance(summary, list):
                summary_lines.append("**Summary**\n")
                for item in summary:
                    summary_lines.append(f"- {item}")
            elif isinstance(summary, dict):
                summary_lines.append("**Summary**\n")
                for key, value in summary.items():
                    summary_lines.append(f"- **{key}**: {value}")

            summary_md = "\n".join(summary_lines).strip()
            table_md = format_markdown_table(summary, preview)

            return f"{summary_md}\n\n{table_md}" if table_md else summary_md

        except Exception as e:
            logger.error(f"Error formatting response: {e}")
            return content

    def map_role_name(self, role_str):
        return {
            "assistant": "TeamLeader",
            "agent": "TeamLeader",
            "user": "You",
            "system": "",  # Optional
        }.get(role_str.lower(), "")

    def yield_all_messages(self, thread_id):
        sorted_msgs = self.project_client.agents.list_messages(
            thread_id=thread_id, order=ListSortOrder.DESCENDING, limit=1
        )
        for msg2 in sorted_msgs.data:
            placeholder_map = {}
            if msg2.role == MessageRole.AGENT and msg2.url_citation_annotations:
                placeholder_map = {
                    ann.text: f" [see {ann.url_citation.title}]({ann.url_citation.url})"
                    for ann in msg2.url_citation_annotations
                }
            role_label = self.map_role_name(msg2.role)
            if hasattr(msg2, "text_messages") and msg2.text_messages:
                for text_msg in msg2.text_messages:
                    text_val = text_msg.text.value
                    for k, v in placeholder_map.items():
                        text_val = text_val.replace(k, v)
                    # Apply formatting: if JSON is embedded, remove it and add formatted table.
                    parsed = extract_json_from_text(text_val)
                    if parsed and "summary" in parsed:
                        formatted_table = format_markdown_table(
                            parsed.get("summary"), parsed.get("preview", [])
                        )
                        # Remove JSON block (assumed enclosed in triple backticks) from text_val.
                        text_val = re.sub(
                            r"(MessageRole\.\w+:\s*)", "", text_val
                        ).strip()
                        cleaned_text = re.sub(
                            r"```json.*?```", "", text_val, flags=re.DOTALL
                        ).strip()
                        combined = f"{cleaned_text}\n\n{formatted_table}"
                    else:
                        combined = text_val
                    if role_label:
                        # yield f"**{role_label}**: {combined}"
                        yield f"{combined}"
                    else:
                        yield combined

            else:
                if msg2.content:
                    text_val = msg2.content
                    parsed = extract_json_from_text(text_val)
                    if parsed and "summary" in parsed:
                        formatted_table = format_markdown_table(
                            parsed.get("summary"), parsed.get("preview", [])
                        )
                        cleaned_text = re.sub(
                            r"```json.*?```", "", text_val, flags=re.DOTALL
                        ).strip()
                        combined = f"{cleaned_text}\n\n{formatted_table}"
                    else:
                        combined = text_val
                    yield f"**{role_label}**: {combined}"
                else:
                    yield f"**{role_label}**: (no content)"

    def process_request(self, user_input):
        try:
            logger.debug("Starting request processing...")
            logger.debug(f"User input: {user_input}")
            # Check if agent thread exists, if not create one
            if (
                not hasattr(self.agent_team, "_agent_thread")
                or not self.agent_team._agent_thread
            ):
                self.agent_team._agent_thread = (
                    self.project_client.agents.create_thread()
                )

            # Create message
            message = self.project_client.agents.create_message(
                thread_id=self.agent_team._agent_thread.id,
                role="user",
                content=user_input,
            )
            logger.debug(f"Created message ID: {message.id}")

            # Create TeamLeader run
            run = self.project_client.agents.create_run(
                thread_id=self.agent_team._agent_thread.id,
                agent_id=self.agent_team._team_leader.agent_instance.id,
            )
            logger.debug(f"Created TeamLeader run: {run.id}")
            yield json.dumps(
                {
                    "role": "system",
                    "agent": "TeamLeader",
                    "content": "Finley is planning your request...",
                }
            )

            start_time = time.time()
            max_wait_time = 30
            action_attempts = 0
            max_action_attempts = 10

            while run.status in ["queued", "in_progress", "requires_action"]:
                if time.time() - start_time > max_wait_time:
                    logger.warning("TeamLeader run timed out!")
                    try:
                        self.project_client.agents.cancel_run(
                            thread_id=self.agent_team._agent_thread.id, run_id=run.id
                        )
                    except Exception as e:
                        logger.error(f"Error canceling timed out run: {str(e)}")
                    yield "I apologize, but the request is taking too long. Please try again."
                    return

                run = self.project_client.agents.get_run(
                    thread_id=self.agent_team._agent_thread.id, run_id=run.id
                )
                logger.debug(f"TeamLeader run status: {run.status}")

                if run.status == "requires_action":
                    action_attempts += 1
                    if action_attempts > max_action_attempts:
                        logger.warning("Too many action attempts, canceling run...")
                        try:
                            self.project_client.agents.cancel_run(
                                thread_id=self.agent_team._agent_thread.id,
                                run_id=run.id,
                            )
                        except Exception as e:
                            logger.error(f"Error canceling run: {str(e)}")
                        yield "I'm having trouble processing your request. Please try again."
                        return

                    # Handle the action if required
                    if isinstance(run.required_action, SubmitToolOutputsAction):
                        logger.debug(
                            "TeamLeader run requires action - handling tools..."
                        )
                        tool_outputs = []
                        for (
                            tool_call
                        ) in run.required_action.submit_tool_outputs.tool_calls:
                            if tool_call.function.name == "create_task":
                                try:
                                    args = tool_call.function.arguments

                                    # Ensure args is a dictionary, if it's a string, parse it as JSON
                                    if isinstance(args, str):
                                        args = json.loads(args)

                                    logger.debug(f"Creating task with args: {args}")
                                    result = create_task(
                                        team_name=args.get("team_name"),
                                        recipient=args.get("recipient"),
                                        request=args.get("request"),
                                        requestor=args.get("requestor"),
                                    )

                                    # Convert the result to a string (JSON if necessary)
                                    if isinstance(result, dict) or isinstance(
                                        result, list
                                    ):
                                        result = json.dumps(
                                            result
                                        )  # Serialize to string

                                    tool_outputs.append(
                                        {"tool_call_id": tool_call.id, "output": result}
                                    )
                                except Exception as e:
                                    logger.error(f"Error creating task: {str(e)}")
                                    tool_outputs.append(
                                        {
                                            "tool_call_id": tool_call.id,
                                            "output": f"Error: {str(e)}",
                                        }
                                    )

                        if tool_outputs:
                            logger.debug(f"Submitting tool outputs: {tool_outputs}")
                            self.project_client.agents.submit_tool_outputs_to_run(
                                thread_id=self.agent_team._agent_thread.id,
                                run_id=run.id,
                                tool_outputs=tool_outputs,
                            )
                            time.sleep(1)

                time.sleep(1)

            if run.status.lower() == "failed":
                logger.error(f"TeamLeader run failed. Run ID: {run.id}")
                yield "Error: TeamLeader run failed."
                return

            while self.agent_team._tasks:
                task = self.agent_team._tasks.pop(0)
                agent = self.agent_team._get_member_by_name(task.recipient)

                if not agent or not agent.agent_instance:
                    logger.error(
                        f"Agent '{task.recipient}' not found or has no instance!"
                    )
                    continue

                message = self.project_client.agents.create_message(
                    thread_id=self.agent_team._agent_thread.id,
                    role="user",
                    content=f"@{task.recipient} {task.task_description}",
                )
                run = self.project_client.agents.create_run(
                    thread_id=self.agent_team._agent_thread.id,
                    agent_id=agent.agent_instance.id,
                )

                # yield f"{agent.name} just got activated"
                yield json.dumps(
                    {
                        "role": "system",
                        "agent": "TeamLeader",
                        "content": f"{agent.name} is now working on the task...",
                    }
                )

                while run.status in ["queued", "in_progress", "requires_action"]:
                    run = self.project_client.agents.get_run(
                        thread_id=self.agent_team._agent_thread.id, run_id=run.id
                    )
                    if run.status == "requires_action" and isinstance(
                        run.required_action, SubmitToolOutputsAction
                    ):
                        tool_outputs = []
                        for (
                            tool_call
                        ) in run.required_action.submit_tool_outputs.tool_calls:
                            if tool_call.type == "function":
                                if tool_call.function.name == "query_adx_database":
                                    try:
                                        args = tool_call.function.arguments

                                        # Parse arguments if needed
                                        if isinstance(args, str):
                                            args = json.loads(args)

                                        logger.debug(
                                            f"Executing ADX query with args: {args}"
                                        )
                                        yield json.dumps(
                                            {
                                                "role": "system",
                                                "agent": "CostAnalysis Agent",
                                                "content": f"Executing the following Kusto query {args.get('kql_query')}",
                                            }
                                        )
                                        result = query_adx_database(
                                            cluster_url=args.get("cluster_url"),
                                            database=args.get("database"),
                                            kql_query=args.get("kql_query"),
                                        )

                                        logger.debug("Query executed successfully")
                                        tool_outputs.append(
                                            {
                                                "tool_call_id": tool_call.id,
                                                "output": safe_tool_output(result),
                                            }
                                        )

                                        # result
                                        # formatted_result = self.format_adx_response(result)
                                        # yield formatted_result
                                    except Exception as e:
                                        logger.error(
                                            f"Error executing ADX query: {str(e)}"
                                        )
                                        tool_outputs.append(
                                            {
                                                "tool_call_id": tool_call.id,
                                                "output": f"Error: {str(e)}",
                                            }
                                        )
                                        yield f"Error: {str(e)}"
                                elif tool_call.function.name == "run_vector_search2":
                                    try:
                                        args = tool_call.function.arguments
                                        if isinstance(args, str):
                                            args = json.loads(args)

                                        query = args.get("query_text")
                                        print(
                                            f"🔍 ADXQueryAgent is running vector search: {query}"
                                        )
                                        yield json.dumps(
                                            {
                                                "role": "system",
                                                "agent": "Cost Analysis Agent",
                                                "content": f"Running vector search for: {query}",
                                            }
                                        )
                                        result = run_vector_search2(query)
                                        print(result)
                                        # yield result  # stream to UI, maybe remove it as it gets overridden in the final yield

                                        tool_outputs.append(
                                            {
                                                "tool_call_id": tool_call.id,
                                                "output": result,
                                            }
                                        )
                                    except Exception as e:
                                        yield f"❌ Error running vector search: {str(e)}"
                                        tool_outputs.append(
                                            {
                                                "tool_call_id": tool_call.id,
                                                "output": f"Error: {str(e)}",
                                            }
                                        )
                                elif (
                                    tool_call.function.name
                                    == "search_kql_docs_vector_only"
                                ):
                                    try:
                                        args = tool_call.function.arguments
                                        if isinstance(args, str):
                                            args = json.loads(args)

                                        query = args.get(
                                            "query",
                                            args.get(
                                                "query_text", args.get("question")
                                            ),
                                        )
                                        print(
                                            f"📚 Retrieving KQL grounding docs for: {query}"
                                        )
                                        results = search_kql_docs_vector_only(query)
                                        tool_outputs.append(
                                            {
                                                "tool_call_id": tool_call.id,
                                                "output": json.dumps(results),
                                            }
                                        )
                                        yield json.dumps(
                                            {
                                                "role": "system",
                                                "agent": "ADXQueryAgent",
                                                "content": f"Found relevant documentation for: '{query}'",
                                            }
                                        )
                                        # formatted = format_markdown_table(None, results)
                                        # yield formatted

                                    except Exception as e:
                                        print(
                                            f"❌ Error running search_kql_docs_hybrid: {str(e)}"
                                        )
                                        tool_outputs.append(
                                            {
                                                "tool_call_id": tool_call.id,
                                                "output": f"Error: {str(e)}",
                                            }
                                        )
                                        yield f"Error: {str(e)}"
                        if tool_outputs:
                            logger.debug(f"Submitting tool outputs for {agent.name}")
                            self.project_client.agents.submit_tool_outputs_to_run(
                                thread_id=self.agent_team._agent_thread.id,
                                run_id=run.id,
                                tool_outputs=tool_outputs,
                            )
                            time.sleep(2)

                # Handle completed run for agent
                if run.status.lower() == "completed":
                    time.sleep(2)
                    # Combine formatted result and return as final response
                    final_response = ""
                    messages = list(
                        self.project_client.agents.list_messages(
                            thread_id=self.agent_team._agent_thread.id
                        )
                    )
                    for m in reversed(messages):
                        if isinstance(m, dict) and m.get("role") == "assistant":
                            content = m.get("content", "")
                            if content:
                                formatted_table = self.format_adx_response(content)
                                final_response = f"{formatted_table}"
                                break
                    yield json.dumps({
                        "role": "agent",
                        "agent": agent.name,
                        "content": final_response
                    })
                                        
                    # yield from self.yield_all_messages(self.agent_team._agent_thread.id)

            logger.debug("All tasks completed successfully!")
            yield from self.yield_all_messages(self.agent_team._agent_thread.id)
            yield json.dumps(
                {"role": "system", "agent": "TeamLeader", "content": "[DONE]"}
            )
        except Exception as e:
            logger.error(f"Error processing request: {str(e)}")
            yield f"Error: {str(e)}"

        def __del__(self):
            if hasattr(self, "project_client"):
                self.project_client.close()
