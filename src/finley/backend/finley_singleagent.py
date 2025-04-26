"""
finley_singleagent.py

This module implements a FastAPI-based service for interacting with an AI agent named "Finley." 
The agent is designed to process user inputs, execute various tools, and return structured responses 
in a streaming format. The service integrates with Azure AI services, supports multiple tools for 
data querying and processing, and provides a real-time streaming API for client interactions.

Key Features:
- **Azure AI Integration**: Uses Azure AI Project Client for managing agents, threads, and runs.
- **Tool Execution**: Supports tools for querying databases, running vector searches, and searching documentation.
- **Streaming Responses**: Provides real-time streaming responses to user queries.
- **FastAPI Framework**: Implements RESTful endpoints for POST and GET requests.
- **In-Memory Session Management**: Tracks user sessions and threads in memory.
- **Error Handling**: Includes robust error handling for tool execution and response formatting.
- **Markdown Formatting**: Formats responses into Markdown for better readability.

Modules and Libraries:
- **FastAPI**: For building the web service.
- **Azure SDK**: For interacting with Azure AI services.
- **Pydantic**: For request validation and data modeling.
- **OpenTelemetry**: For monitoring and tracing.
- **Custom Utilities**: Includes functions for formatting output, extracting JSON, and managing tools.

Endpoints:
- `POST /ask`: Accepts user input and streams the agent's response.
- `GET /api/ask-stream`: Streams the agent's response for a given prompt.

Environment Variables:
- `AZURE_MONITOR_CONNECTION_STRING`: Connection string for Azure Monitor.
- `PROJECT_CONNECTION_STRING`: Connection string for Azure AI Project.
- `AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME_STRUCTURED`: Name of the deployed AI model.

Dependencies:
- Requires a `.env` file for loading environment variables.
- Relies on custom user functions for querying and processing data.

Usage:
1. Start the FastAPI server.
2. Use the `/ask` or `/api/ask-stream` endpoints to interact with the Finley agent.
3. Monitor and trace interactions using Azure Monitor and OpenTelemetry.

"""
import os
import time
import json
import re
from dotenv import load_dotenv
from fastapi import FastAPI, Request, Query
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    FunctionTool,
    RequiredFunctionToolCall,
    SubmitToolOutputsAction,
    ToolOutput,
    ListSortOrder,
    ResponseFormatJsonSchemaType,
    ResponseFormatJsonSchema
)
from user_functions.finley_functions import query_adx_database, run_vector_search2
from user_functions.search_web_docs import search_web_docs
from user_functions.search_kql_docs import search_kql_docs_vector_only
from user_functions.fabric_query import query_fabric_sql
from utils.format_output import format_markdown_table
from typing import Dict
from datetime import datetime
from utils.json_extract import extract_json_from_text  # if not already imported


# === Load .env and prompt ===
load_dotenv()
PROMPT_PATH = os.path.join(
    os.path.dirname(__file__), "agent_instructions", "finley_agent.txt"
)


def load_prompt() -> str:
    with open(PROMPT_PATH, encoding="utf-8") as f:
        return f.read()


# === Azure Monitor and OpenTelemetry setup ===
from azure.monitor.opentelemetry import configure_azure_monitor

configure_azure_monitor(
    connection_string=os.getenv("AZURE_MONITOR_CONNECTION_STRING"),
)
from opentelemetry import trace

tracer = trace.get_tracer(__name__)


# === Utils ===
def safe_tool_output(result, max_length=1048576):
    """
    Safely serialize the result of a tool execution to JSON.
    If the serialized output exceeds max_length, return a truncated version.
    """
    try:
        serialized = json.dumps(result)
        if len(serialized) > max_length:
            return json.dumps(
                {
                    "summary": "Output was too large and has been truncated.",
                    "truncated": True,
                    "preview": (
                        result.get("preview", [])[:50]
                        if isinstance(result, dict)
                        else "Truncated"
                    ),
                }
            )
        return serialized
    except Exception as e:
        return json.dumps({"error": f"Serialization failed: {str(e)}"})


def format_adx_response(content: str) -> str:
    """
    Format the response from the AI agent for better readability.
    - Extracts JSON data from the content.
    - Formats the summary and preview into Markdown.
    - Returns the formatted content.
    """
    try:
        parsed = extract_json_from_text(content)
        if not parsed or not isinstance(parsed, dict):
            return content

        summary = parsed.get("summary", "Query complete.").strip()
        preview = parsed.get("preview", [])

        # build the two pieces
        summary_md = f"**Summary**\n\n{summary}"
        table_md = format_markdown_table(preview)  # always pass (None, preview)

        # filter out None/"" and join
        parts = [summary_md, table_md]
        return "\n\n".join(p for p in parts if p)

    except Exception:
        return content

    except Exception:
        return content



def extract_text_content(msg):
    """
    Extract text content from a message object.
    Handles different structures of the message object.
    """
    if hasattr(msg, "text") and msg.text:
        return msg.text.value
    if hasattr(msg, "content"):
        return msg.content
    return str(msg)

# === FunctionTool setup ===
function_tool = FunctionTool(
    functions=[
        query_adx_database,
        query_fabric_sql,
        run_vector_search2,
        search_kql_docs_vector_only,
        search_web_docs
    ]
)

# === FastAPI setup ===
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class UserInput(BaseModel):
    message: str


# === In-memory session map ===
session_threads: Dict[str, str] = {}


# === Streaming core logic ===
def stream_response(user_input: str, session_id: str):
    """
    Stream the response from the Finley agent.
    This function handles the interaction with the Azure AI Project Client,
    manages the agent and thread, and streams the response back to the client.
    """
    try:
        project_client = AIProjectClient.from_connection_string(
            credential=DefaultAzureCredential(),
            conn_str=os.environ["PROJECT_CONNECTION_STRING"],
        )
        with project_client:
            # Create agent
            agent = project_client.agents.create_agent(
                model=os.environ["AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME_STRUCTURED"],
                name="Finley",
                instructions=load_prompt(),
                tools=function_tool.definitions,
                temperature=0.0,
                top_p=0.3,
                )

            # Use or create thread
            if session_id not in session_threads:
                thread = project_client.agents.create_thread()
                session_threads[session_id] = thread.id
            else:
                thread = project_client.agents.get_thread(session_threads[session_id])

            # Create message
            # Add today's date to the user input as context
            today_str = datetime.utcnow().strftime("%Y-%m-%d")
            enhanced_input = f"(Today is {today_str})\n\n{user_input}"

            project_client.agents.create_message(
                thread_id=thread.id, role="user", content=enhanced_input
            )

            # Create run
            run = project_client.agents.create_run(
                thread_id=thread.id, agent_id=agent.id
            )

            yield f"data: {json.dumps({'role': 'system', 'agent': 'Finley', 'content': 'Finley is thinking...'})}\n\n"

            while run.status in ["queued", "in_progress", "requires_action"]:
                time.sleep(1)
                run = project_client.agents.get_run(thread_id=thread.id, run_id=run.id)

                if run.status == "requires_action" and isinstance(
                    run.required_action, SubmitToolOutputsAction
                ):
                    tool_outputs = []
                    for tool_call in run.required_action.submit_tool_outputs.tool_calls:
                        if isinstance(tool_call, RequiredFunctionToolCall):
                            try:
                                output = function_tool.execute(tool_call)
                                output = safe_tool_output(output)
                                tool_outputs.append(
                                    ToolOutput(tool_call_id=tool_call.id, output=output)
                                )
                                response = {
                                    "role": "agent",
                                    "agent": "Finley",
                                    "content": f"🛠 Tool '{tool_call.function.name}' executed.",
                                }
                                yield f"data: {json.dumps(response)}\n\n"
                            except Exception as e:
                                tool_outputs.append(
                                    ToolOutput(
                                        tool_call_id=tool_call.id,
                                        output=f"Error: {str(e)}",
                                    )
                                )
                                error_response = {
                                    "role": "agent",
                                    "agent": "Finley",
                                    "content": f"❌ Error in {tool_call.function.name}: {str(e)}",
                                }
                                yield f"data: {json.dumps(error_response)}\n\n"

                    if tool_outputs:
                        project_client.agents.submit_tool_outputs_to_run(
                            thread_id=thread.id,
                            run_id=run.id,
                            tool_outputs=tool_outputs,
                        )
            # ✅ Final assistant message handling
            sorted_msgs = project_client.agents.list_messages(
                thread_id=thread.id, order=ListSortOrder.DESCENDING, limit=1
            )

            for msg in sorted_msgs.data:
                if msg.role in ("assistant", "agent"):
                    try:
                        full_text = ""

                        if hasattr(msg, "text_messages") and msg.text_messages:
                            full_text = "\n".join(
                                tm.text.value
                                for tm in msg.text_messages
                                if hasattr(tm.text, "value")
                            ).strip()

                        # Legacy fallback
                        elif hasattr(msg, "content") and isinstance(msg.content, str):
                            full_text = msg.content.strip()

                        # Fallback: log unknown object
                        else:
                            full_text = str(msg)

                        formatted = format_adx_response(full_text)
                        payload = {
                            "role": "agent",
                            "agent": "Finley",
                            "content": formatted,
                        }
                        yield f"data: {json.dumps(payload)}\n\n"
                    except Exception as e:
                        error_payload = {
                            "role": "agent",
                            "agent": "Finley",
                            "content": f"❌ Failed to process final message: {str(e)}",
                        }
                        yield f"data: {json.dumps(error_payload)}\n\n"

            done_message = {"content": "[DONE]"}
            yield f"data: {json.dumps(done_message)}\n\n"

    except Exception as e:
        yield f"data: {json.dumps({ 'role': 'error', 'agent': 'Finley', 'content': f'❌ Error: {str(e)}' })}\n\n"

    finally:
        yield f"data: {json.dumps({ 'content': '[DONE]' })}\n\n"


# === API routes ===
@app.post("/ask")
async def ask_finley_post(request: Request):
    """
    Handle POST requests to the /ask endpoint.
    Expects a JSON body with a 'message' field.
    Streams the response from the Finley agent.
    """
    body = await request.json()
    user_input = body["message"]
    session_id = request.headers.get("x-session-id", "default")
    return StreamingResponse(
        stream_response(user_input, session_id), media_type="text/event-stream"
    )


@app.get("/api/ask-stream")
async def ask_finley_get(prompt: str = Query(...), request: Request = None):
    """
    Handle GET requests to the /api/ask-stream endpoint.
    Expects a query parameter 'prompt'.
    Streams the response from the Finley agent.
    """
    session_id = request.headers.get("x-session-id", "default")
    return StreamingResponse(
        stream_response(prompt, session_id), media_type="text/event-stream"
    )
