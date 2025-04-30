from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
import os
from dotenv import load_dotenv
# Load environment variables
load_dotenv()
# Load your project
credential = DefaultAzureCredential()
project_client = AIProjectClient.from_connection_string(
    credential=credential,
    conn_str=os.environ["PROJECT_CONNECTION_STRING"]
)


def delete_all_agents():
    agents = project_client.agents.list_agents().data
    if not agents:
        print("✅ No agents found to delete.")
        return

    for agent in agents:
        try:
            print(f"🗑 Deleting agent: {agent.name} (id: {agent.id})")
            project_client.agents.delete_agent(agent.id)
        except Exception as e:
            print(f"❌ Failed to delete agent {agent.name}: {e}")
    print("✅ Agent cleanup completed.")

delete_all_agents()
