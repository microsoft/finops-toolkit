import os
"""
This script demonstrates the creation and execution of an AI agent using the Azure AI Projects SDK. 
The agent is designed to process user queries and interact with external tools to provide results.
Modules:
- os: Provides functions for interacting with the operating system.
- time: Used for adding delays during polling.
- dotenv: Loads environment variables from a .env file.
- azure.ai.projects: Contains the AIProjectClient for managing AI projects.
- azure.identity: Provides authentication via DefaultAzureCredential.
- azure.ai.projects.models: Includes models for defining tools and actions.
- user_functions: Custom user-defined functions for the agent's tools.
- json: Used for parsing and handling JSON data.
- utils.format_output: Contains helper functions for formatting and saving output.
Workflow:
1. Load environment variables from a `.env` file.
2. Initialize the AIProjectClient using a connection string and credentials.
3. Load agent instructions from an external text file.
4. Register user-defined functions as tools for the agent.
5. Create an agent with a specified model, name, instructions, and tools.
6. Create a conversation thread and a user message with a query.
7. Start a run for the agent and poll for its completion.
8. Handle tool execution when the agent requires action, process the output, and save results.
9. Optionally delete the agent after the run is complete.
Key Features:
- Supports querying an ADX cluster for resource cost analysis.
- Handles tool execution and output formatting (Markdown and CSV).
- Provides status updates during the agent's run lifecycle.
Note:
Ensure that the required environment variables (e.g., `PROJECT_CONNECTION_STRING`, `MODEL_DEPLOYMENT_NAME`) 
are set in the `.env` file before running the script.
"""
import time
from dotenv import load_dotenv
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.projects.models import FunctionTool, RequiredFunctionToolCall, SubmitToolOutputsAction, ToolOutput
from user_functions import user_functions
import json
import sys
from utils.format_output import format_markdown_table, save_csv
# === Setup ===
load_dotenv()
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(parent_dir)


# Initialize client
project_client = AIProjectClient.from_connection_string(
    credential=DefaultAzureCredential(),
    conn_str=os.environ["PROJECT_CONNECTION_STRING"],
)
# Load instructions from external .txt file
instructions_path = "agent_instructions.txt"
with open(instructions_path, "r", encoding="utf-8") as f:
    agent_instructions = f.read()
# Register functions
functions = FunctionTool(functions=user_functions)

with project_client:
    # Create agent
    agent = project_client.agents.create_agent(
        model=os.environ["MODEL_DEPLOYMENT_NAME"],
        name="FinOps Resource Graph Expert",
        instructions=agent_instructions,
        tools=functions.definitions,
    )

    print(f"✅ Agent created: {agent.id}")

    # Create conversation thread
    thread = project_client.agents.create_thread()
    print(f"🧵 Thread created: {thread.id}")

    # Create user message
    message = project_client.agents.create_message(
        thread_id=thread.id,
        role="user",
        content="""Give me the list of the top 5 biggest consumers, meaning resource based on aggregated cost of the past 3 months.
        Query my ADX Cluser: "https://finopshubs0-7-adx.westeurope.kusto.windows.net"
        Database: "Hub"""
    )
    print(f"📩 Message created: {message.id}")

    # Start run
    run = project_client.agents.create_run(thread_id=thread.id, agent_id=agent.id)
    print(f"🏃 Run started: {run.id}")

    # Poll for completion
    while run.status in ["queued", "in_progress", "requires_action"]:
        time.sleep(1)
        run = project_client.agents.get_run(thread_id=thread.id, run_id=run.id)

        if run.status == "requires_action" and isinstance(run.required_action, SubmitToolOutputsAction):
            tool_calls = run.required_action.submit_tool_outputs.tool_calls
            tool_outputs = []

            for tool_call in tool_calls:
                if isinstance(tool_call, RequiredFunctionToolCall):
                    try:
                        print(f"⚙️ Executing tool: {tool_call.function.name}")
                        output = functions.execute(tool_call)
                        try:
                            result = json.loads(output)
                            summary = result.get("summary", "")
                            preview = result.get("preview", [])
                            md = format_markdown_table(summary, preview)
                            print("\n📄🔁 Tool Output (Generic Markdown):\n")
                            print(md)
                            # Optional: save to file
                            with open("resource-query-output.md", "w", encoding="utf-8") as f:
                                f.write(md)
                            save_csv(preview, "outputs/resource-query-output.csv")

                        except Exception as e:
                            print("⚠️ Could not parse tool output. Raw output:")
                            print(output)
                            print(f"Error: {e}")
                        tool_outputs.append(
                            ToolOutput(
                                tool_call_id=tool_call.id,
                                output=output,
                            )
                        )
                    except Exception as e:
                        print(f"❌ Error in tool execution: {e}")

            if tool_outputs:
                project_client.agents.submit_tool_outputs_to_run(
                    thread_id=thread.id,
                    run_id=run.id,
                    tool_outputs=tool_outputs,
                )

        print(f"⏳ Run status: {run.status}")

    # Optionally delete agent
    project_client.agents.delete_agent(agent.id)
    print("🧹 Agent deleted.")
