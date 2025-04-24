# Multiagent Finley AI Foundry SDK

A sophisticated multi-agent system built on Azure AI Foundry, enabling collaborative AI agents to work together on complex tasks.

## Overview

This project implements a team-based AI agent system that leverages Azure AI Foundry's capabilities to create, manage, and coordinate multiple AI agents. The system allows for dynamic task delegation, inter-agent communication, and collaborative problem-solving.

## Features

- **Team-based Architecture**: Create and manage teams of AI agents with specialized roles
- **Dynamic Task Delegation**: Agents can delegate tasks to other team members
- **Configurable Agent Roles**: Define custom roles and capabilities for each agent
- **Azure Integration**: Built on Azure AI Foundry for enterprise-grade AI capabilities
- **OpenTelemetry Support**: Built-in tracing and monitoring capabilities
- **YAML-based Configuration**: Easy configuration of agent teams and their capabilities

## Project Structure

```
multiagent_finley_aifoundrysdk/
├── adxqueries/          # Azure Data Explorer query definitions
├── outputs/            # Generated outputs and results
├── user_functions/     # Custom user-defined functions
├── utils/             # Utility functions and helpers
├── agent_team.py      # Core agent team implementation
├── agent_team_config.yaml  # Team configuration
├── finley_team.py     # Finley-specific team implementation
├── requirements.txt   # Project dependencies
└── adxagent_instructions.txt  # Agent instructions and guidelines
.env # For local dev and to be able to run the solution
```

## Prerequisites

- Python 3.8 or higher
- Azure subscription with AI Foundry access
- Required Azure credentials and permissions

## Installation

1. Clone the repository
2. Create a virtual environment:
   ```bash
   python -m venv venvmultiagentaifoundry
   source venvmultiagentaifoundry/bin/activate  # On Windows: venvmultiagentaifoundry\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Configuration

Create a `.env` file in the project root with:
```
PROJECT_CONNECTION_STRING=your_connection_string_here
AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME=your_deployment_name_here
```

## Usage

### Quick Start Guide

1. **Create .env file**
   Create a file named `.env` in the project root with:
   ```
   PROJECT_CONNECTION_STRING=your_connection_string_here
   AZURE_AI_AGENT_MODEL_DEPLOYMENT_NAME=your_deployment_name_here
   ```

2. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the Solution**
   You can run the solution in two ways:

   **Command Line Interface:**
   ```bash
   python finley_team.py
   ```

   **Web Interface (Recommended):**
   ```bash
   python gradio_app.py
   ```
   This will launch a user-friendly web interface where you can chat with the agent.

## Testing

### Quick Start Guide for Testing

1. **Setup**
   ```bash
   # Create a directory for your test results
   mkdir prompt_test_results
   cd prompt_test_results
   ```

2. **Running Tests**
   - Open a Python terminal or notebook
   - Import and initialize the team as shown in the Usage section
   - Start asking questions using `team.process_request()`
   - Save responses in your `prompt_test_results` folder

3. **Documentation**
   - Keep a simple text file or spreadsheet to track:
     - Questions asked
     - Responses received
     - Any issues or observations

4. **Tips**
   - Start with simple questions to verify basic functionality
   - Test different types of queries (analytical, creative, technical)
   - Note any unexpected responses or behaviors
   - Keep track of response times and quality

## Development

The project uses OpenTelemetry for tracing and monitoring. To enable tracing:

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider

trace.set_tracer_provider(TracerProvider())
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Azure AI Foundry team
- OpenTelemetry community
- Contributors and maintainers
