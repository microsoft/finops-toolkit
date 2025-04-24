import gradio as gr
from finley_team_gradio import FinleyTeam
import os
from dotenv import load_dotenv
import logging
import sys
from io import StringIO
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

# Configure logging
# logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

def initialize_team():
    """Initialize the Finley team with error handling"""
    try:
        # Initialize the team
        team = FinleyTeam()
        logger.info("Finley team initialized successfully")
        return team
    except Exception as e:
        logger.error(f"Failed to initialize Finley team: {str(e)}")
        raise

# Initialize the Finley team
try:
    team = initialize_team()
except Exception as e:
    logger.error(f"Failed to initialize team: {str(e)}")
    team = None

def chat(message, history):
    """Process the user message and stream the agent's responses"""
    if team is None:
        yield "Error: Team not initialized. Please check your environment variables and try again."
        return
    
    try:
        logger.info(f"Processing request: {message}")
        
        # Process the request and stream responses
        for response in team.process_request(message):
            if response:
                yield response
        
    except Exception as e:
        error_msg = f"Error processing request: {str(e)}"
        logger.error(error_msg)
        yield error_msg

# Create the Gradio interface
demo = gr.ChatInterface(
    chat,
    title="Finley AI Assistant",
    description="Ask me anything! I'm here to help.",
    theme=gr.themes.Ocean(),
    examples=[
        "Give me the list of the top 3 biggest consumers, meaning resource based on aggregated cost of the past 3 months.",
        "Give me a summary table of the consumption for AI and Machine Learning service category of this month and list the resources by name meaning resource based on aggregated cost by subscription name.",
        "Give me a list of the top 10 consumers of the service category of AI and Machine Learning by resource name and aggregated cost of the past 3 months."
    ],
    autoscroll=True,
    show_progress=True,
)



if __name__ == "__main__":
    try:
        # Launch the interface
        demo.launch(
            server_name="127.0.0.1",  # Allow external connections
            server_port=7860,       # Default Gradio port
            share=False             # Don't create public URL
        )
    except Exception as e:
        logger.error(f"Failed to launch Gradio interface: {str(e)}")
        raise 