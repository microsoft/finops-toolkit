import time
import json
from datetime import datetime
from typing import Generator, Dict
import os

from azure.identity import (
    ChainedTokenCredential,
    AzureCliCredential,
    ManagedIdentityCredential,
)
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    FunctionTool,
    RequiredFunctionToolCall,
    SubmitToolOutputsAction,
    ToolOutput,
    ListSortOrder,
)

from core import config
from user_functions.query_adx_strict import query_adx_database
from user_functions.search_web_docs import search_web_docs
from utils.format_output import format_markdown_table
from utils.json_extract import extract_json_from_text
# === Azure Monitor and OpenTelemetry setup ===
from azure.monitor.opentelemetry import configure_azure_monitor

try:
    monitor_conn = os.getenv("AZURE_MONITOR_CONNECTION_STRING")
    if monitor_conn:
        configure_azure_monitor(connection_string=monitor_conn)
    else:
        print("⚠️ AZURE_MONITOR_CONNECTION_STRING not set, skipping Azure Monitor setup.")
except Exception as e:
    print(f"⚠️ Azure Monitor setup failed: {str(e)}")
from opentelemetry import trace

tracer = trace.get_tracer(__name__)
# === Global caches ===
session_threads: Dict[str, str] = {}
agent_id_cache: str | None = None


def load_prompt() -> str:
    try:
        prompt_path = os.path.abspath(config.PROMPT_PATH)
        with open(prompt_path, encoding="utf-8") as f:
            return f.read()
    except Exception as e:
        return f"You are Finley, the FinOps assistant. Prompt file failed to load: {str(e)}"


def safe_tool_output(result, max_length=config.MAX_TOOL_OUTPUT_LENGTH) -> str:
    try:
        serialized = json.dumps(result)
        if len(serialized) > max_length:
            return json.dumps({
                "summary": "Output was too large and has been truncated.",
                "truncated": True,
                "preview": (
                    result.get("preview", [])[:50]
                    if isinstance(result, dict)
                    else "Truncated"
                ),
            })
        return serialized
    except Exception as e:
        return json.dumps({"error": f"Serialization failed: {str(e)}"})


def format_adx_response(content: str) -> str:
    try:
        parsed = extract_json_from_text(content)
        if not parsed or not isinstance(parsed, dict):
            return content

        summary = parsed.get("summary", "Query complete.").strip()
        preview = parsed.get("preview", [])
        return "\n\n".join(
            p for p in [f"**Summary**\n\n{summary}", format_markdown_table(preview)] if p
        )
    except Exception:
        return content


def stream_response(user_input: str, session_id: str) -> Generator[str, None, None]:
    global agent_id_cache

    try:
        credential = ChainedTokenCredential(
            ManagedIdentityCredential(),
            AzureCliCredential(),
        )

        project_client = AIProjectClient.from_connection_string(
            credential=credential,
            conn_str=config.PROJECT_CONNECTION_STRING,
        )

        with project_client:
            # === Agent caching ===
            if not agent_id_cache:
                agent = project_client.agents.create_agent(
                    model=config.AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME,
                    name="Finley",
                    instructions=load_prompt(),
                    tools=FunctionTool(
                        functions=[query_adx_database, search_web_docs]
                    ).definitions,
                    temperature=0.2,
                    top_p=0.3,
                )
                agent_id_cache = agent.id
            else:
                agent = project_client.agents.get_agent(agent_id_cache)

            # === Thread management ===
            thread_id = session_threads.get(session_id)
            if thread_id:
                thread = project_client.agents.get_thread(thread_id)
                runs = project_client.agents.list_runs(
                    thread_id=thread.id, order=ListSortOrder.DESCENDING, limit=1
                )
                if runs.data and runs.data[0].status in (
                    "queued", "in_progress", "requires_action"
                ):
                    thread = project_client.agents.create_thread()
                    session_threads[session_id] = thread.id
            else:
                thread = project_client.agents.create_thread()
                session_threads[session_id] = thread.id

            # === Create message ===
            today_str = datetime.utcnow().strftime("%Y-%m-%d")
            enhanced_input = f"(Today is {today_str})\n\n{user_input}"
            project_client.agents.create_message(
                thread_id=thread.id, role="user", content=enhanced_input
            )

            # === Create run ===
            run = project_client.agents.create_run(
                thread_id=thread.id, agent_id=agent.id
            )

            yield f"data: {json.dumps({'role': 'system', 'agent': 'Finley', 'content': 'Finley is thinking...'})}\n\n"

            while run.status in ("queued", "in_progress", "requires_action"):
                time.sleep(1)
                run = project_client.agents.get_run(thread_id=thread.id, run_id=run.id)

                if run.status == "requires_action" and isinstance(
                    run.required_action, SubmitToolOutputsAction
                ):
                    tool_outputs = []
                    for tool_call in run.required_action.submit_tool_outputs.tool_calls:
                        if isinstance(tool_call, RequiredFunctionToolCall):
                            try:
                                output = FunctionTool(
                                    functions=[query_adx_database, search_web_docs]
                                ).execute(tool_call)
                                tool_outputs.append(
                                    ToolOutput(
                                        tool_call_id=tool_call.id,
                                        output=safe_tool_output(output),
                                    )
                                )
                                yield f"data: {json.dumps({'role': 'agent', 'agent': 'Finley', 'content': f'🛠 Tool {tool_call.function.name} executed.'})}\n\n"
                            except Exception as e:
                                tool_outputs.append(
                                    ToolOutput(
                                        tool_call_id=tool_call.id,
                                        output=f"Error: {str(e)}",
                                    )
                                )
                                yield f"data: {json.dumps({'role': 'agent', 'agent': 'Finley', 'content': f'❌ Tool {tool_call.function.name} failed: {str(e)}'})}\n\n"

                    if tool_outputs:
                        project_client.agents.submit_tool_outputs_to_run(
                            thread_id=thread.id,
                            run_id=run.id,
                            tool_outputs=tool_outputs,
                        )

            # === Final response ===
            sorted_msgs = project_client.agents.list_messages(
                thread_id=thread.id, order=ListSortOrder.DESCENDING, limit=1
            )
            for msg in sorted_msgs.data:
                if msg.role in ("agent", "assistant"):
                    try:
                        full_text = ""
                        if hasattr(msg, "text_messages") and msg.text_messages:
                            full_text = "\n".join(
                                tm.text.value for tm in msg.text_messages
                                if hasattr(tm.text, "value")
                            ).strip()
                        elif hasattr(msg, "content") and isinstance(msg.content, str):
                            full_text = msg.content.strip()
                        else:
                            full_text = str(msg)

                        formatted = format_adx_response(full_text)
                        yield f"data: {json.dumps({'role': 'agent', 'agent': 'Finley', 'content': formatted})}\n\n"
                    except Exception as e:
                        yield f"data: {json.dumps({'role': 'agent', 'agent': 'Finley', 'content': f'❌ Failed to process final message: {str(e)}'})}\n\n"

            yield f"data: {json.dumps({'content': '[DONE]'})}\n\n"

    except Exception as e:
        yield f"data: {json.dumps({'role': 'error', 'agent': 'Finley', 'content': f'❌ Unexpected error: {str(e)}'})}\n\n"
