# SRECTL - SRE Agent CLI Instructions

This file contains comprehensive documentation for all SRECTL commands and their usage.
Generated on: 2026-05-02 03:51:06 UTC

## Table of Contents

1. [Main Command](#main-command)
2. [General Commands](#general-commands)
   - [init](#init-command)
   - [list](#list-command)
   - [apply-yaml](#apply-yaml-command)
3. [Agent Commands](#agent-commands)
   - [agent create](#agent-create-command)
   - [agent validate](#agent-validate-command)
   - [agent apply](#agent-apply-command)
   - [agent run](#agent-run-command)
4. [Tool Commands](#tool-commands)
   - [tool create](#tool-create-command)
   - [tool validate](#tool-validate-command)
   - [tool apply](#tool-apply-command)
   - [tool show-types](#tool-show-types-command)
   - [tool show-connectors](#tool-show-connectors-command)
5. [Skills Commands](#skills-commands)
   - [skill create](#skill-create-command)
   - [skill upload](#skill-upload-command)
   - [skill list](#skill-list-command)
   - [skill delete](#skill-delete-command)
   - [skill convert](#skill-convert-command)
   - [skill download](#skill-download-command)

## Main Command

### Main Command {#main-command}

```
$ srectl --help

Description:
  SRE Agent CLI - Your intelligent assistant for managing SRE agents and automating incident response

Usage:
  srectl <command> [options]
  srectl <subgroup> <command> [options]

Options:
  -h, /h, -?, /?  Show help and usage information
  --version       Show version information
  --debug         Enable debug logging
  --quiet         Minimize output

Subgroups:
  agent              Agent commands for managing SRE automation agents
  tool               Tool commands for managing SRE automation tools
  common-prompt      Common prompt commands for managing shared prompts
  extension          Extension commands for generating deployment files and configurations
  mcp                Model Context Protocol server for building SRE agents
  doc                Document management commands. Upload and manage documents like TSGs, architecture docs, runbooks, and other reference materials for agents to use
  workspace          Workspace management commands. Upload, download, and delete workspace files.
  incident-filter    Incident filter commands for managing incident routing rules
  hook               Manage hooks for agent safety and governance
  thread             Thread management commands
  profile            Profile management commands. Profiles store connection settings for different SRE Agent instances (local or remote)
  repo               Manage Azure DevOps repository connectors for TSG documents
  skill              Skill management commands. Apply and manage custom skills for agents to use, or convert an existing agent into a skill.
  incidenthandler    Manage incident response plans and filters
  scheduledtask      Manage scheduled tasks for automated agent operations
  release-trigger    Release trigger commands for managing pipeline event response plans

Commands:
  welcome            Show welcome screen and getting started guide
  version            Show version information and build details
  init               Initialize SREAgent CLI configuration and workspace
                     
                     Examples:
                       # Initialize with local development server
                       srectl init --resource-url https://localhost:7023
                     
                       # Initialize with remote server
                       srectl init --resource-url https://my-sreagent-dev.1abcdef.eastus2.azuresre.ai
                     
                       # Initialize with production environment
                       srectl init --resource-url https://my-sreagent-prod.2abcdef.eastus2.azuresre.ai
  status             Show workspace status and health check
  apply-yaml, apply  Apply YAML configuration files to the server
                     Supports multi-document YAML files (separated by ---) similar to Kubernetes manifests.
                     Automatically detects and applies tools, agents, and common prompts.
                     
                     Examples:
                       # Apply a single resource YAML file
                       srectl apply-yaml --file agents/MyAgent/MyAgent.yaml
                     
                       # Apply a multi-document YAML file
                       srectl apply-yaml --file manifests/all-resources.yaml
                     
                       # Apply a tool YAML file
                       srectl apply-yaml --file tools/KustoTool.yaml
                     
                       # Apply a common prompt YAML file
                       srectl apply-yaml --file CommonPrompts/prompt.yaml
  interactive        Start interactive guided mode for step-by-step assistance
  sync               Sync agents and tools YAML from the remote server into the local workspace (agents/, tools/)
                     
                     Examples:
                       # Sync all remote configurations
                       srectl sync
                     
                     Note: Requires prior 'srectl init --resource-url <url>'
  chat               Start an interactive chat session with the SRE Agent
                     
                     Examples:
                       # Start interactive chat
                       srectl chat
                     
                       # Start chat with debug logging
                       srectl chat --debug
                     
                       # Start chat with minimal output
                       srectl chat --quiet
```

## General Commands

### init Command {#init-command}

```
$ srectl init --help

Description:
  Initialize SREAgent CLI configuration and workspace
  
  Examples:
    # Initialize with local development server
    srectl init --resource-url https://localhost:7023
  
    # Initialize with remote server
    srectl init --resource-url https://my-sreagent-dev.1abcdef.eastus2.azuresre.ai
  
    # Initialize with production environment
    srectl init --resource-url https://my-sreagent-prod.2abcdef.eastus2.azuresre.ai

Usage:
  srectl init [options]

Options:
  --resource-url <resource-url> (REQUIRED)  Base URL of the SRE Agent server
  -?, -h, --help                            Show help and usage information
  --debug                                   Enable debug logging
  --quiet                                   Minimize output
```

### list Command {#list-command}

```
$ srectl list --help

Description:
  SRE Agent CLI - Your intelligent assistant for managing SRE agents and automating incident response

Usage:
  srectl <command> [options]
  srectl <subgroup> <command> [options]

Options:
  -h, /h, -?, /?  Show help and usage information
  --version       Show version information
  --debug         Enable debug logging
  --quiet         Minimize output

Subgroups:
  agent              Agent commands for managing SRE automation agents
  tool               Tool commands for managing SRE automation tools
  common-prompt      Common prompt commands for managing shared prompts
  extension          Extension commands for generating deployment files and configurations
  mcp                Model Context Protocol server for building SRE agents
  doc                Document management commands. Upload and manage documents like TSGs, architecture docs, runbooks, and other reference materials for agents to use
  workspace          Workspace management commands. Upload, download, and delete workspace files.
  incident-filter    Incident filter commands for managing incident routing rules
  hook               Manage hooks for agent safety and governance
  thread             Thread management commands
  profile            Profile management commands. Profiles store connection settings for different SRE Agent instances (local or remote)
  repo               Manage Azure DevOps repository connectors for TSG documents
  skill              Skill management commands. Apply and manage custom skills for agents to use, or convert an existing agent into a skill.
  incidenthandler    Manage incident response plans and filters
  scheduledtask      Manage scheduled tasks for automated agent operations
  release-trigger    Release trigger commands for managing pipeline event response plans

Commands:
  welcome            Show welcome screen and getting started guide
  version            Show version information and build details
  init               Initialize SREAgent CLI configuration and workspace
                     
                     Examples:
                       # Initialize with local development server
                       srectl init --resource-url https://localhost:7023
                     
                       # Initialize with remote server
                       srectl init --resource-url https://my-sreagent-dev.1abcdef.eastus2.azuresre.ai
                     
                       # Initialize with production environment
                       srectl init --resource-url https://my-sreagent-prod.2abcdef.eastus2.azuresre.ai
  status             Show workspace status and health check
  apply-yaml, apply  Apply YAML configuration files to the server
                     Supports multi-document YAML files (separated by ---) similar to Kubernetes manifests.
                     Automatically detects and applies tools, agents, and common prompts.
                     
                     Examples:
                       # Apply a single resource YAML file
                       srectl apply-yaml --file agents/MyAgent/MyAgent.yaml
                     
                       # Apply a multi-document YAML file
                       srectl apply-yaml --file manifests/all-resources.yaml
                     
                       # Apply a tool YAML file
                       srectl apply-yaml --file tools/KustoTool.yaml
                     
                       # Apply a common prompt YAML file
                       srectl apply-yaml --file CommonPrompts/prompt.yaml
  interactive        Start interactive guided mode for step-by-step assistance
  sync               Sync agents and tools YAML from the remote server into the local workspace (agents/, tools/)
                     
                     Examples:
                       # Sync all remote configurations
                       srectl sync
                     
                     Note: Requires prior 'srectl init --resource-url <url>'
  chat               Start an interactive chat session with the SRE Agent
                     
                     Examples:
                       # Start interactive chat
                       srectl chat
                     
                       # Start chat with debug logging
                       srectl chat --debug
                     
                       # Start chat with minimal output
                       srectl chat --quiet
```

### list agents Command {#list-agents-command}

```
$ srectl list agents --help

Description:
  SRE Agent CLI - Your intelligent assistant for managing SRE agents and automating incident response

Usage:
  srectl <command> [options]
  srectl <subgroup> <command> [options]

Options:
  -h, /h, -?, /?  Show help and usage information
  --version       Show version information
  --debug         Enable debug logging
  --quiet         Minimize output

Subgroups:
  agent              Agent commands for managing SRE automation agents
  tool               Tool commands for managing SRE automation tools
  common-prompt      Common prompt commands for managing shared prompts
  extension          Extension commands for generating deployment files and configurations
  mcp                Model Context Protocol server for building SRE agents
  doc                Document management commands. Upload and manage documents like TSGs, architecture docs, runbooks, and other reference materials for agents to use
  workspace          Workspace management commands. Upload, download, and delete workspace files.
  incident-filter    Incident filter commands for managing incident routing rules
  hook               Manage hooks for agent safety and governance
  thread             Thread management commands
  profile            Profile management commands. Profiles store connection settings for different SRE Agent instances (local or remote)
  repo               Manage Azure DevOps repository connectors for TSG documents
  skill              Skill management commands. Apply and manage custom skills for agents to use, or convert an existing agent into a skill.
  incidenthandler    Manage incident response plans and filters
  scheduledtask      Manage scheduled tasks for automated agent operations
  release-trigger    Release trigger commands for managing pipeline event response plans

Commands:
  welcome            Show welcome screen and getting started guide
  version            Show version information and build details
  init               Initialize SREAgent CLI configuration and workspace
                     
                     Examples:
                       # Initialize with local development server
                       srectl init --resource-url https://localhost:7023
                     
                       # Initialize with remote server
                       srectl init --resource-url https://my-sreagent-dev.1abcdef.eastus2.azuresre.ai
                     
                       # Initialize with production environment
                       srectl init --resource-url https://my-sreagent-prod.2abcdef.eastus2.azuresre.ai
  status             Show workspace status and health check
  apply-yaml, apply  Apply YAML configuration files to the server
                     Supports multi-document YAML files (separated by ---) similar to Kubernetes manifests.
                     Automatically detects and applies tools, agents, and common prompts.
                     
                     Examples:
                       # Apply a single resource YAML file
                       srectl apply-yaml --file agents/MyAgent/MyAgent.yaml
                     
                       # Apply a multi-document YAML file
                       srectl apply-yaml --file manifests/all-resources.yaml
                     
                       # Apply a tool YAML file
                       srectl apply-yaml --file tools/KustoTool.yaml
                     
                       # Apply a common prompt YAML file
                       srectl apply-yaml --file CommonPrompts/prompt.yaml
  interactive        Start interactive guided mode for step-by-step assistance
  sync               Sync agents and tools YAML from the remote server into the local workspace (agents/, tools/)
                     
                     Examples:
                       # Sync all remote configurations
                       srectl sync
                     
                     Note: Requires prior 'srectl init --resource-url <url>'
  chat               Start an interactive chat session with the SRE Agent
                     
                     Examples:
                       # Start interactive chat
                       srectl chat
                     
                       # Start chat with debug logging
                       srectl chat --debug
                     
                       # Start chat with minimal output
                       srectl chat --quiet
```

### list tools Command {#list-tools-command}

```
$ srectl list tools --help

Description:
  SRE Agent CLI - Your intelligent assistant for managing SRE agents and automating incident response

Usage:
  srectl <command> [options]
  srectl <subgroup> <command> [options]

Options:
  -h, /h, -?, /?  Show help and usage information
  --version       Show version information
  --debug         Enable debug logging
  --quiet         Minimize output

Subgroups:
  agent              Agent commands for managing SRE automation agents
  tool               Tool commands for managing SRE automation tools
  common-prompt      Common prompt commands for managing shared prompts
  extension          Extension commands for generating deployment files and configurations
  mcp                Model Context Protocol server for building SRE agents
  doc                Document management commands. Upload and manage documents like TSGs, architecture docs, runbooks, and other reference materials for agents to use
  workspace          Workspace management commands. Upload, download, and delete workspace files.
  incident-filter    Incident filter commands for managing incident routing rules
  hook               Manage hooks for agent safety and governance
  thread             Thread management commands
  profile            Profile management commands. Profiles store connection settings for different SRE Agent instances (local or remote)
  repo               Manage Azure DevOps repository connectors for TSG documents
  skill              Skill management commands. Apply and manage custom skills for agents to use, or convert an existing agent into a skill.
  incidenthandler    Manage incident response plans and filters
  scheduledtask      Manage scheduled tasks for automated agent operations
  release-trigger    Release trigger commands for managing pipeline event response plans

Commands:
  welcome            Show welcome screen and getting started guide
  version            Show version information and build details
  init               Initialize SREAgent CLI configuration and workspace
                     
                     Examples:
                       # Initialize with local development server
                       srectl init --resource-url https://localhost:7023
                     
                       # Initialize with remote server
                       srectl init --resource-url https://my-sreagent-dev.1abcdef.eastus2.azuresre.ai
                     
                       # Initialize with production environment
                       srectl init --resource-url https://my-sreagent-prod.2abcdef.eastus2.azuresre.ai
  status             Show workspace status and health check
  apply-yaml, apply  Apply YAML configuration files to the server
                     Supports multi-document YAML files (separated by ---) similar to Kubernetes manifests.
                     Automatically detects and applies tools, agents, and common prompts.
                     
                     Examples:
                       # Apply a single resource YAML file
                       srectl apply-yaml --file agents/MyAgent/MyAgent.yaml
                     
                       # Apply a multi-document YAML file
                       srectl apply-yaml --file manifests/all-resources.yaml
                     
                       # Apply a tool YAML file
                       srectl apply-yaml --file tools/KustoTool.yaml
                     
                       # Apply a common prompt YAML file
                       srectl apply-yaml --file CommonPrompts/prompt.yaml
  interactive        Start interactive guided mode for step-by-step assistance
  sync               Sync agents and tools YAML from the remote server into the local workspace (agents/, tools/)
                     
                     Examples:
                       # Sync all remote configurations
                       srectl sync
                     
                     Note: Requires prior 'srectl init --resource-url <url>'
  chat               Start an interactive chat session with the SRE Agent
                     
                     Examples:
                       # Start interactive chat
                       srectl chat
                     
                       # Start chat with debug logging
                       srectl chat --debug
                     
                       # Start chat with minimal output
                       srectl chat --quiet
```

### apply-yaml Command {#apply-yaml-command}

```
$ srectl apply-yaml --help

Description:
  Apply YAML configuration files to the server
  Supports multi-document YAML files (separated by ---) similar to Kubernetes manifests.
  Automatically detects and applies tools, agents, and common prompts.
  
  Examples:
    # Apply a single resource YAML file
    srectl apply-yaml --file agents/MyAgent/MyAgent.yaml
  
    # Apply a multi-document YAML file
    srectl apply-yaml --file manifests/all-resources.yaml
  
    # Apply a tool YAML file
    srectl apply-yaml --file tools/KustoTool.yaml
  
    # Apply a common prompt YAML file
    srectl apply-yaml --file CommonPrompts/prompt.yaml

Usage:
  srectl apply-yaml [options]

Options:
  -f, --file <file> (REQUIRED)  Path to the YAML file to apply
  -?, -h, --help                Show help and usage information
  --debug                       Enable debug logging
  --quiet                       Minimize output
```

## Agent Commands

### agent Command {#agent-command}

```
$ srectl agent --help

Description:
  Agent commands for managing SRE automation agents

Usage:
  srectl agent [command] [options]

Options:
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output

Commands:
  create    Create a new agent YAML configuration file
  
            Examples:
              # Create a basic agent
              srectl agent create --name DevOpsAgent --instructions "Help with DevOps tasks such as monitoring and incident response"
  
              # Create an agent with tools
              srectl agent create --name KustoAgent --tools QueryKusto AnalyzeMetrics
  
              # Create an agent with AI assistance (smart mode)
              srectl agent create --name StorageAgent --smart --instructions "Help troubleshoot Azure Storage issues"
  
              # Create an advanced agent with all options
              srectl agent create --name AdvancedAgent \
                --instructions "Complex multi-step agent" \
                --tools Tool1 Tool2 \
                --handoffs Agent1 Agent2 \
                --temperature 0.7 \
                --max-reflection-count 3
  validate  Validate agent YAML configuration files
  
            Examples:
              # Validate by agent name (searches in agents/ folder)
              srectl agent validate --name MyAgent
  
              # Validate specific agent by name and check tools
              srectl agent validate --name KustoAgent --check-tools
  
              # Validate all agent files
              srectl agent validate --all
  
              # Validate with tool availability checking
              srectl agent validate --all --check-tools
  
              # Alternative: Validate a specific agent file path
              srectl agent validate --file agents/MyAgent/MyAgent.yaml
  apply     Apply an agent configuration to the remote server
  
            Examples:
              # Apply an agent to the server
              srectl agent apply --name DevOpsAgent
  
              # Preview what would be applied (dry run)
              srectl agent apply --name KustoAgent --dry-run
  
              # Apply with debug logging
              srectl agent apply --name MyAgent --debug
  delete    Delete an agent from the remote server
  
            Examples:
              # Delete an agent from the server
              srectl agent delete --name OldAgent
  
              # Delete with debug logging
              srectl agent delete --name TestAgent --debug
  test      Test an agent with a specific message (starts interactive session)
  
            Examples:
              # Test an agent interactively
              srectl agent test --name DevOpsAgent --message "Check pod status in namespace production"
  
              # Send test message without waiting for response
              srectl agent test --name KustoAgent --message "Query memory usage" --no-wait
  
              # Start interactive session with specific agent
              srectl agent test --name MyAgent --message "Help me debug this issue"
  
            Note: This command is equivalent to 'srectl thread new --agent <name> --message <message>'
                  and will start an interactive chat session unless --no-wait is specified.
  diff      Compare local and remote agent configurations
  
            Examples:
              # Compare default using git-diff (default)
              srectl agent diff --name DevOpsAgent
  
              # Use VS Code diff
              srectl agent diff --name KustoAgent --tool code
  
              # Show inline diff
              srectl agent diff --name MyAgent --raw
  migrate   Migrate V1 agent format to V2
  
            Examples:
              # Migrate a specific agent
              srectl agent migrate --name MyAgent
  
              # Migrate all agents
              srectl agent migrate --all
  
              # Preview migration changes (dry run)
              srectl agent migrate --all --dry-run
  
              # Migrate specific agent with dry run
              srectl agent migrate --name MyAgent --dry-run
  list      List remote extended agents from the server
  
            Examples:
              # List all agents
              srectl agent list
  
              # List all agents with full YAML details
              srectl agent list --detail
  
              # Get a specific agent by name (full YAML output)
              srectl agent list --name MyAgent
  
              # Search for specific agents
              srectl agent list --search devops
```

### agent create Command {#agent-create-command}

```
$ srectl agent create --help

Description:
  Create a new agent YAML configuration file
  
  Examples:
    # Create a basic agent
    srectl agent create --name DevOpsAgent --instructions "Help with DevOps tasks such as monitoring and incident response"
  
    # Create an agent with tools
    srectl agent create --name KustoAgent --tools QueryKusto AnalyzeMetrics
  
    # Create an agent with AI assistance (smart mode)
    srectl agent create --name StorageAgent --smart --instructions "Help troubleshoot Azure Storage issues"
  
    # Create an advanced agent with all options
    srectl agent create --name AdvancedAgent \
      --instructions "Complex multi-step agent" \
      --tools Tool1 Tool2 \
      --handoffs Agent1 Agent2 \
      --temperature 0.7 \
      --max-reflection-count 3

Usage:
  srectl agent create [options]

Options:
  --name <name> (REQUIRED)                           Name of the agent
  --instructions <instructions>                      Instructions for the agent
  --tools <tools>                                    Tools the agent can use
  --mcp-tools <mcp-tools>                            MCP tools the agent can use
  --handoff-description <handoff-description>        Description for handoff capabilities
  --handoffs <handoffs>                              Agents this agent can hand off to
  --allow-parallel-tool-calls                        Allow parallel tool execution
  --max-reflection-count <max-reflection-count>      Maximum number of reflection iterations
  --critic-prompt-path <critic-prompt-path>          Path to critic prompt file
  --critic-on-handoff                                Enable critic on handoff
  --custom-reflection-note <custom-reflection-note>  Custom note for reflection
  --common-prompts <common-prompts>                  Common prompts to include
  --temperature <temperature>                        Model temperature setting
  --output-type <output-type>                        Expected output format
  --vanilla-mode                                     Use vanilla mode without enhancements
  --smart                                            Use AI to generate instructions and recommend tools
  --enable-skills                                    Enable skills for the agent
  --add-system-skills                                Add system skills (not recommended for custom meta-agents)
  -?, -h, --help                                     Show help and usage information
  --debug                                            Enable debug logging
  --quiet                                            Minimize output
```

### agent validate Command {#agent-validate-command}

```
$ srectl agent validate --help

Description:
  Validate agent YAML configuration files
  
  Examples:
    # Validate by agent name (searches in agents/ folder)
    srectl agent validate --name MyAgent
  
    # Validate specific agent by name and check tools
    srectl agent validate --name KustoAgent --check-tools
  
    # Validate all agent files
    srectl agent validate --all
  
    # Validate with tool availability checking
    srectl agent validate --all --check-tools
  
    # Alternative: Validate a specific agent file path
    srectl agent validate --file agents/MyAgent/MyAgent.yaml

Usage:
  srectl agent validate [options]

Options:
  --name <name>   Agent name to validate
  --file <file>   YAML file to validate
  --all           Validate all agents
  --check-tools   Validate that referenced tools exist
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output
```

### agent apply Command {#agent-apply-command}

```
$ srectl agent apply --help

Description:
  Apply an agent configuration to the remote server
  
  Examples:
    # Apply an agent to the server
    srectl agent apply --name DevOpsAgent
  
    # Preview what would be applied (dry run)
    srectl agent apply --name KustoAgent --dry-run
  
    # Apply with debug logging
    srectl agent apply --name MyAgent --debug

Usage:
  srectl agent apply [options]

Options:
  --name <name> (REQUIRED)  Name of the agent to apply
  --dry-run                 Preview changes without applying
  -?, -h, --help            Show help and usage information
  --debug                   Enable debug logging
  --quiet                   Minimize output
```

### agent run Command {#agent-run-command}

```
$ srectl agent run --help

Description:
  Agent commands for managing SRE automation agents

Usage:
  srectl agent [command] [options]

Options:
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output

Commands:
  create    Create a new agent YAML configuration file
  
            Examples:
              # Create a basic agent
              srectl agent create --name DevOpsAgent --instructions "Help with DevOps tasks such as monitoring and incident response"
  
              # Create an agent with tools
              srectl agent create --name KustoAgent --tools QueryKusto AnalyzeMetrics
  
              # Create an agent with AI assistance (smart mode)
              srectl agent create --name StorageAgent --smart --instructions "Help troubleshoot Azure Storage issues"
  
              # Create an advanced agent with all options
              srectl agent create --name AdvancedAgent \
                --instructions "Complex multi-step agent" \
                --tools Tool1 Tool2 \
                --handoffs Agent1 Agent2 \
                --temperature 0.7 \
                --max-reflection-count 3
  validate  Validate agent YAML configuration files
  
            Examples:
              # Validate by agent name (searches in agents/ folder)
              srectl agent validate --name MyAgent
  
              # Validate specific agent by name and check tools
              srectl agent validate --name KustoAgent --check-tools
  
              # Validate all agent files
              srectl agent validate --all
  
              # Validate with tool availability checking
              srectl agent validate --all --check-tools
  
              # Alternative: Validate a specific agent file path
              srectl agent validate --file agents/MyAgent/MyAgent.yaml
  apply     Apply an agent configuration to the remote server
  
            Examples:
              # Apply an agent to the server
              srectl agent apply --name DevOpsAgent
  
              # Preview what would be applied (dry run)
              srectl agent apply --name KustoAgent --dry-run
  
              # Apply with debug logging
              srectl agent apply --name MyAgent --debug
  delete    Delete an agent from the remote server
  
            Examples:
              # Delete an agent from the server
              srectl agent delete --name OldAgent
  
              # Delete with debug logging
              srectl agent delete --name TestAgent --debug
  test      Test an agent with a specific message (starts interactive session)
  
            Examples:
              # Test an agent interactively
              srectl agent test --name DevOpsAgent --message "Check pod status in namespace production"
  
              # Send test message without waiting for response
              srectl agent test --name KustoAgent --message "Query memory usage" --no-wait
  
              # Start interactive session with specific agent
              srectl agent test --name MyAgent --message "Help me debug this issue"
  
            Note: This command is equivalent to 'srectl thread new --agent <name> --message <message>'
                  and will start an interactive chat session unless --no-wait is specified.
  diff      Compare local and remote agent configurations
  
            Examples:
              # Compare default using git-diff (default)
              srectl agent diff --name DevOpsAgent
  
              # Use VS Code diff
              srectl agent diff --name KustoAgent --tool code
  
              # Show inline diff
              srectl agent diff --name MyAgent --raw
  migrate   Migrate V1 agent format to V2
  
            Examples:
              # Migrate a specific agent
              srectl agent migrate --name MyAgent
  
              # Migrate all agents
              srectl agent migrate --all
  
              # Preview migration changes (dry run)
              srectl agent migrate --all --dry-run
  
              # Migrate specific agent with dry run
              srectl agent migrate --name MyAgent --dry-run
  list      List remote extended agents from the server
  
            Examples:
              # List all agents
              srectl agent list
  
              # List all agents with full YAML details
              srectl agent list --detail
  
              # Get a specific agent by name (full YAML output)
              srectl agent list --name MyAgent
  
              # Search for specific agents
              srectl agent list --search devops
```

## Tool Commands

### tool Command {#tool-command}

```
$ srectl tool --help

Description:
  Tool commands for managing SRE automation tools

Usage:
  srectl tool [command] [options]

Options:
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output

Commands:
  create           Create a new tool YAML configuration file
  validate         Validate tool YAML configuration files
  
                   Examples:
                     # Validate a specific tool
                     srectl tool validate --name QueryMetrics
  
                     # Validate all tools
                     srectl tool validate --all
  
                     # Validate with debug output
                     srectl tool validate --name MyTool --debug
  apply            Apply a tool configuration to the remote server
  
                   Examples:
                     # Apply a tool to the server
                     srectl tool apply --name QueryMetrics
  
                     # Preview what would be applied (dry run)
                     srectl tool apply --name StorageOps --dry-run
  
                     # Apply with debug logging
                     srectl tool apply --name CustomTool --debug
  delete           Delete a tool from the remote server
  
                   Examples:
                     # Delete a tool from the server
                     srectl tool delete --name OldTool
  
                     # Preview what would be deleted (dry run)
                     srectl tool delete --name TestTool --dry-run
  
                     # Delete with debug logging
                     srectl tool delete --name UnusedTool --debug
  diff             Compare local and remote tool configurations
  
                   Examples:
                     # Compare default using git
                     srectl tool diff --name QueryMetrics
  
                     # Use VS Code diff
                     srectl tool diff --name MyTool --tool code
  
                     # Show inline diff
                     srectl tool diff --name MyTool --raw
  migrate          Migrate V1 tool configurations to V2 format
  
                   Examples:
                     # Migrate a specific tool
                     srectl tool migrate --name MyKustoTool
  
                     # Migrate all V1 tools
                     srectl tool migrate --all
  
                     # Migrate specific tool with dry run
                     srectl tool migrate --name MyKustoTool --dry-run
  
                     # Preview migration without making changes (dry run)
                     srectl tool migrate --all --dry-run
  show-types       Display available tool types and their details
  
                   Examples:
                     # List all available tool types
                     srectl tool show-types
  
                     # Show detailed information for all types
                     srectl tool show-types --verbose
  
                     # Show details for a specific tool type
                     srectl tool show-types --type KustoTool
  
                     # Show specific type with verbose details
                     srectl tool show-types --type AzureTool --verbose
  show-connectors  Display configured data connectors (names to use in YAML) and available connector types
  
                   Examples:
                     # List all available connectors
                     srectl tool show-connectors
  list             List all tools from the remote server
  
                   Examples:
                     # List all tools
                     srectl tool list
  
                     # List all tools with full YAML details
                     srectl tool list --detail
  
                     # Get a specific tool by name (full YAML output)
                     srectl tool list --name TestMigrate
  
                     # Search for specific tools
                     srectl tool list --search kusto
```

### tool create Command {#tool-create-command}

```
$ srectl tool create --help

Description:
  Create a new tool YAML configuration file

Usage:
  srectl tool create [options]

Common Options:
  --name <name> (REQUIRED)            Name of the tool
  --type <type> (REQUIRED)            Type of the tool (KustoTool, LinkTool, PythonTool, HttpClientTool)
  --path <path>                       Custom path under tools directory (e.g., 'StorageOperations')
  --description <description>         Description of the tool
  --parameter <parameter>             Tool parameter in format 'name:type:description' (can be specified multiple times)

KustoTool Options:
  --connector <connector>             Connector name for the tool
  --database <database>               Database name for KustoTool
  --query <query>                     Query for KustoTool

  Examples:
    # Create a KustoTool with all parameters
    srectl tool create --name QueryMetrics --type KustoTool --connector analytics-cluster --database LogsDB --query "MyTable | take 10" --parameter limit
    # Create a KustoTool with minimal options
    srectl tool create --name GetLogs --type KustoTool --connector logs-cluster --database LogsDB

LinkTool Options:
  --template <template>               URL template for LinkTool

  Examples:
    # Create a LinkTool with template
    srectl tool create --name ServiceDashboard --type LinkTool --template "https://dashboard.example.com/{serviceId}" --parameter serviceId
    # Create a LinkTool with minimal options
    srectl tool create --name DocLink --type LinkTool --description "Link to documentation"

PythonTool Options:
  --function-code <function-code>     Python function code for PythonTool
  --timeout <timeout>                 Timeout in seconds (default: 30)
  --dependency <dependency>           Python package dependency for PythonTool (can be specified multiple times)

  Examples:
    # Create a PythonTool with dependencies
    srectl tool create --name ProcessData --type PythonTool --function-code "def run(params): return params" --dependency requests --timeout 60
    # Create a PythonTool with custom path
    srectl tool create --name DataProcessor --type PythonTool --path "Data/Processing" --dependency pandas

HttpClientTool Options:
  --url <url>                         URL template with optional {{param}} placeholders for HttpClientTool
  --method <method>                   HTTP method (GET, POST, PUT, DELETE, PATCH) for HttpClientTool
  --body <body>                       Request body template with {{param}} placeholders for HttpClientTool
  --header <header>                   HTTP header in format 'key:value' (can be specified multiple times)
  --auth-connector <auth-connector>   Data connector name for authentication
  --auth-scope <auth-scope>           OAuth scope to request for authentication
  --timeout <timeout>                 Timeout in seconds (default: 30)

  Examples:
    # Create a simple GET request tool
    srectl tool create --name GetUserInfo --type HttpClientTool --url "https://api.example.com/users/{{userId}}" --method GET --parameter userId:string:User ID
    # Create a POST request tool with body
    srectl tool create --name CreateTicket --type HttpClientTool --url "https://api.example.com/tickets" --method POST --body "{\"title\": \"{{title}}\"}" --header "Content-Type:application/json"
    # Create an authenticated API call
    srectl tool create --name CallSecureApi --type HttpClientTool --url "https://api.example.com/data" --method GET --auth-connector my-oauth-connector --auth-scope "api://example/.default"
```

### tool validate Command {#tool-validate-command}

```
$ srectl tool validate --help

Description:
  Validate tool YAML configuration files
  
  Examples:
    # Validate a specific tool
    srectl tool validate --name QueryMetrics
  
    # Validate all tools
    srectl tool validate --all
  
    # Validate with debug output
    srectl tool validate --name MyTool --debug

Usage:
  srectl tool validate [options]

Options:
  --name <name>   Name of the tool to validate
  --all           Validate all YAML files in the tools directory
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output
```

### tool apply Command {#tool-apply-command}

```
$ srectl tool apply --help

Description:
  Apply a tool configuration to the remote server
  
  Examples:
    # Apply a tool to the server
    srectl tool apply --name QueryMetrics
  
    # Preview what would be applied (dry run)
    srectl tool apply --name StorageOps --dry-run
  
    # Apply with debug logging
    srectl tool apply --name CustomTool --debug

Usage:
  srectl tool apply [options]

Options:
  --name <name> (REQUIRED)  Name of the tool to apply
  --dry-run                 Show what would be applied without making changes
  -?, -h, --help            Show help and usage information
  --debug                   Enable debug logging
  --quiet                   Minimize output
```

### tool show-types Command {#tool-show-types-command}

```
$ srectl tool show-types --help

Description:
  Display available tool types and their details
  
  Examples:
    # List all available tool types
    srectl tool show-types
  
    # Show detailed information for all types
    srectl tool show-types --verbose
  
    # Show details for a specific tool type
    srectl tool show-types --type KustoTool
  
    # Show specific type with verbose details
    srectl tool show-types --type AzureTool --verbose

Usage:
  srectl tool show-types [options]

Options:
  --type <type>   Show details for a specific tool type
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output
```

### tool show-connectors Command {#tool-show-connectors-command}

```
$ srectl tool show-connectors --help

Description:
  Display configured data connectors (names to use in YAML) and available connector types
  
  Examples:
    # List all available connectors
    srectl tool show-connectors

Usage:
  srectl tool show-connectors [options]

Options:
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output
```

## Skills Commands

### skill Command {#skill-command}

```
$ srectl skill --help

Description:
  Skill management commands. Apply and manage custom skills for agents to use, or convert an existing agent into a skill.

Usage:
  srectl skill [command] [options]

Options:
  -?, -h, --help  Show help and usage information
  --debug         Enable debug logging
  --quiet         Minimize output

Commands:
  create          Create a new skill directory with template files
  
                  Examples:
                    # Create a new skill with default template
                    srectl skill create --name my-skill
  
                    # Create with custom description
                    srectl skill create --name my-skill --description "Handles database queries and analysis"
  apply, upload   Apply a skill configuration to the remote server
  
                  Examples:
                    # Apply a skill to the server
                    srectl skill apply --name my-skill
  
                    # Preview what would be applied (dry run)
                    srectl skill apply --name database-analyzer --dry-run
  
                    # Apply with debug logging
                    srectl skill apply --name my-skill --debug
  convert         Convert an existing agent to a skill
  
                  Examples:
                    # Convert an agent to a skill
                    srectl skill convert --agent-name my-agent
  
                    # Convert with specific top-level agents for context
                    srectl skill convert --agent-name my-agent --top-level-agents triage-agent support-agent
  
                    # Specify custom output path
                    srectl skill convert --agent-name my-agent --output-path custom/path
  list            List all available skills from the remote server
  
                  Examples:
                    # List all skills
                    srectl skill list
  
                    # List all skills with full YAML details
                    srectl skill list --detail
  
                    # Get a specific skill by name (full YAML output)
                    srectl skill list --name my-skill
  
                    # Search for specific skills
                    srectl skill list --search database
  download, sync  Sync skill(s) from the server to local directory
  
                  Examples:
                    # Sync a single skill
                    srectl skill sync --name my-skill
  
                    # Sync a skill to a specific path
                    srectl skill sync --name my-skill --path custom/path
  
                    # Sync all skills
                    srectl skill sync --all
  
                    # Sync all skills to a specific directory
                    srectl skill sync --all --path my-skills
  delete          Delete a skill from the server
  
                  Examples:
                    # Delete a skill from the server
                    srectl skill delete --name old-skill
  
                    # Preview what would be deleted (dry run)
                    srectl skill delete --name test-skill --dry-run
  
                    # Delete with debug logging
                    srectl skill delete --name unused-skill --debug
  migrate         Migrate skills from metadata.yaml to SKILL.md frontmatter format
  
                  Examples:
                    # Migrate a specific skill
                    srectl skill migrate --name my-skill
  
                    # Migrate all skills in the skills/ directory
                    srectl skill migrate --all
  
                    # Preview migration without making changes (dry run)
                    srectl skill migrate --name my-skill --dry-run
  
                    # Migrate all skills with dry run
                    srectl skill migrate --all --dry-run
```

### skill create Command {#skill-create-command}

```
$ srectl skill create --help

Description:
  Create a new skill directory with template files
  
  Examples:
    # Create a new skill with default template
    srectl skill create --name my-skill
  
    # Create with custom description
    srectl skill create --name my-skill --description "Handles database queries and analysis"

Usage:
  srectl skill create [options]

Options:
  --name <name> (REQUIRED)     Name of the skill to create
  --description <description>  Description of what the skill does and when to use it
  -?, -h, --help               Show help and usage information
  --debug                      Enable debug logging
  --quiet                      Minimize output
```

### skill upload Command {#skill-upload-command}

```
$ srectl skill upload --help

Description:
  Apply a skill configuration to the remote server
  
  Examples:
    # Apply a skill to the server
    srectl skill apply --name my-skill
  
    # Preview what would be applied (dry run)
    srectl skill apply --name database-analyzer --dry-run
  
    # Apply with debug logging
    srectl skill apply --name my-skill --debug

Usage:
  srectl skill apply [options]

Options:
  --name <name> (REQUIRED)  Name of the skill to apply to the server
  --dry-run                 Preview changes without applying them
  -?, -h, --help            Show help and usage information
  --debug                   Enable debug logging
  --quiet                   Minimize output
```

### skill list Command {#skill-list-command}

```
$ srectl skill list --help

Description:
  List all available skills from the remote server
  
  Examples:
    # List all skills
    srectl skill list
  
    # List all skills with full YAML details
    srectl skill list --detail
  
    # Get a specific skill by name (full YAML output)
    srectl skill list --name my-skill
  
    # Search for specific skills
    srectl skill list --search database

Usage:
  srectl skill list [options]

Options:
  --search <search>  Search filter for skill names or descriptions
  --name <name>      Get a specific skill by name and output the full YAML
  --detail           Output the full YAML for all skills in the list
  -?, -h, --help     Show help and usage information
  --debug            Enable debug logging
  --quiet            Minimize output
```

### skill delete Command {#skill-delete-command}

```
$ srectl skill delete --help

Description:
  Delete a skill from the server
  
  Examples:
    # Delete a skill from the server
    srectl skill delete --name old-skill
  
    # Preview what would be deleted (dry run)
    srectl skill delete --name test-skill --dry-run
  
    # Delete with debug logging
    srectl skill delete --name unused-skill --debug

Usage:
  srectl skill delete [options]

Options:
  --name <name> (REQUIRED)  Name of the skill to delete
  --dry-run                 Preview deletion without actually removing the skill
  --delete-local-files      Also delete local configuration files without prompting (true=delete, false=skip, omit=prompt)
  -?, -h, --help            Show help and usage information
  --debug                   Enable debug logging
  --quiet                   Minimize output
```

### skill convert Command {#skill-convert-command}

```
$ srectl skill convert --help

Description:
  Convert an existing agent to a skill
  
  Examples:
    # Convert an agent to a skill
    srectl skill convert --agent-name my-agent
  
    # Convert with specific top-level agents for context
    srectl skill convert --agent-name my-agent --top-level-agents triage-agent support-agent
  
    # Specify custom output path
    srectl skill convert --agent-name my-agent --output-path custom/path

Usage:
  srectl skill convert [options]

Options:
  --agent-name <agent-name> (REQUIRED)   Name of the agent to convert to a skill
  --top-level-agents <top-level-agents>  List of top-level agent names for handoff context
  --output-path <output-path>            Output path for the generated skill (default: skills/{agent-name})
  -?, -h, --help                         Show help and usage information
  --debug                                Enable debug logging
  --quiet                                Minimize output
```

### skill download Command {#skill-download-command}

```
$ srectl skill download --help

Description:
  Sync skill(s) from the server to local directory
  
  Examples:
    # Sync a single skill
    srectl skill sync --name my-skill
  
    # Sync a skill to a specific path
    srectl skill sync --name my-skill --path custom/path
  
    # Sync all skills
    srectl skill sync --all
  
    # Sync all skills to a specific directory
    srectl skill sync --all --path my-skills

Usage:
  srectl skill sync [options]

Options:
  --name <name>                 Name of the skill to sync
  --all                         Sync all skills from the server
  --output-path, --path <path>  Output path for the synced skill(s) (default: skills/)
  -?, -h, --help                Show help and usage information
  --debug                       Enable debug logging
  --quiet                       Minimize output
```

## Common Usage Examples

### Quick Start

```bash
# Initialize SRECTL with a resource URL
srectl init --resource-url https://localhost:7023

# Create a new agent
srectl agent create --name my_agent --instructions "Agent instructions" --tools MyTool

# Validate the agent
srectl agent validate --name my_agent

# Apply the agent to the server
srectl agent apply --name my_agent
```

### Creating Tools

```bash
# Create a basic tool
srectl tool create --name MyTool --type KustoQuery

# Create a KustoTool with auto-generated template
srectl tool create --name GetServiceLogs --type KustoTool

# Validate and apply the tool
srectl tool validate --name MyTool
srectl tool apply --name MyTool
```

### Smart Agent Generation

```bash
# Use AI to generate comprehensive agent instructions and recommended tools
srectl agent create --name "RedisContainerAppDown" --smart

# Smart generation with custom guidance
srectl agent create --name "DatabasePerformanceIssue" --smart \
  --instructions "Focus on PostgreSQL performance optimization"
```

### Working with Skills

```bash
# Create a new skill with template files
srectl skill create --name my-skill

# Edit the generated files:
# - skills/my-skill/metadata.yaml (add tools and description)
# - skills/my-skill/SKILL.md (add instructions and workflows)

# Upload the skill to the server
srectl skill upload --path skills/my-skill

# Convert an existing agent to a skill
srectl skill convert --agent-name my-agent

# List all available skills
srectl skill list
```

### Remote Server Operations

```bash
# List all agents on the remote server
srectl list agents

# List all tools on the remote server
srectl list tools

# Apply a YAML file directly
srectl apply-yaml --file my-config.yaml
```

---

*This file was automatically generated by `srectl init`. For the most up-to-date information,*
*refer to the individual command help outputs using `srectl <command> --help`.*
