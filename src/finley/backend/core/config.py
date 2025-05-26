from dotenv import load_dotenv
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROMPT_PATH = os.getenv("PROMPT_PATH", os.path.join(BASE_DIR, "../agent_instructions/finley_agent.xml"))

# Load environment variables from .env file manually
load_dotenv()

# Basic constants from the environment
PROJECT_CONNECTION_STRING = os.getenv("PROJECT_CONNECTION_STRING")
AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME = os.getenv("AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME")
FRONTEND_ORIGIN = os.getenv("FRONTEND_ORIGIN", "http://localhost:5173")
MAX_TOOL_OUTPUT_LENGTH = int(os.getenv("MAX_TOOL_OUTPUT_LENGTH", 1048576))
