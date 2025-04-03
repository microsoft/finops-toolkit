import sys, os
import json
from datetime import datetime

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import gradio as gr
import asyncio
from backend.finley_multiagent import handle_function_call
from utils.format_output import format_markdown_table, save_csv
from utils.json_extract import extract_json_from_text
from semantic_kernel.contents import AuthorRole, FunctionCallContent
from backend.agents_initializer import initialize_agents, create_chat

client = None
chat = None
agents = []

# Friendly agent display names
agent_display_names = {
    "Finley": "🤖 Finley [Planner]",
    "ADXQueryAgent": "🧠 ADXQueryAgent [KQL Master]",
    "ARGQueryAgent": "📊 ARGQueryAgent [Resource Explorer]"
}

async def startup():
    global client, agents
    if not chat:
        client, agents = await initialize_agents()

async def chat_with_agents_stream(user_input, history, show_inner):
    await startup()
    chat_instance = await create_chat(agents)
    await chat_instance.add_chat_message(message=user_input)

    timestamp = datetime.now().strftime("%H:%M:%S")
    history.append((f"🧑‍💻 You [{timestamp}]", user_input))
    yield history, "🧠 Finley is analyzing your request..."

    reasoning_log = []
    task_tree_log = ["🧠 Finley"]

    async for content in chat_instance.invoke():
        name = content.name or content.role
        display_name = agent_display_names.get(name, name)
        role = content.role
        time = datetime.now().strftime("%H:%M:%S")

        if isinstance(content, FunctionCallContent):
            task_tree_log.append(f"├── 🤖 {name} → `{content.function_name}`")
            task_tree_log.append(f"│   └── 🔧 Tool: `{content.function_name}()`")

            if show_inner:
                reasoning_log.append(
                    f"<details><summary>🧠 {name} [{time}]</summary>\n\n"
                    f"📞 Called `{content.function_name}`\n\n"
                    f"```json\n{json.dumps(content.arguments, indent=2)}\n```"
                    f"</details>"
                )

            yield history, f"⏳ {name} is working on `{content.function_name}`..."

            result = await handle_function_call(content)
            await chat_instance.add_chat_message(
                message=result,
                role=AuthorRole.TOOL,
                name=content.function_name
            )

            if show_inner:
                reasoning_log.append(
                    f"<details><summary>🔧 Result from `{content.function_name}`</summary>\n\n"
                    f"```json\n{result}\n```"
                    f"</details>"
                )

        elif role != AuthorRole.TOOL:
            if name != "Finley" and not any(name in line for line in task_tree_log):
                task_tree_log.append(f"├── 🤖 {name} → (direct response)")
            history.append((f"{display_name} [{time}]", content.content))
            yield history, f"💬 {name} responded..."

    # Final summary
    parsed = extract_json_from_text(content.content)
    summary = parsed.get("summary", "Query complete.") if parsed else "Query complete."
    preview = parsed.get("preview", []) if parsed else []
    markdown = format_markdown_table(summary, preview) if preview else ""
    final_message = f"**{summary}**\n\n{markdown}"

    if show_inner and reasoning_log:
        final_message += (
            f"\n\n<details><summary>🧠 Agent Reasoning</summary>\n\n"
            f"{chr(10).join(reasoning_log)}\n</details>"
        )

    if show_inner and len(task_tree_log) > 1:
        tree_md = "```\n" + "\n".join(task_tree_log) + "\n```"
        final_message += (
            f"\n\n<details><summary>🌳 Finley's Task Tree</summary>\n\n{tree_md}\n</details>"
        )

    history.append((f"📊 Summary [{datetime.now().strftime('%H:%M:%S')}]", final_message))
    yield history, "✅ Query complete. All agents have responded."

def launch_ui():
    with gr.Blocks(css="""
        #chatbot .wrap { white-space: pre-wrap }
        .scroll-to-bottom { animation: scrollDown 0.5s ease-in-out forwards; }
        @keyframes scrollDown { to { scroll-behavior: smooth; scroll-top: 100%; } }
    """) as demo:

        gr.Markdown("## 🤖 Finley Multi-Agent Chat")
        chatbot = gr.Chatbot(elem_id="chatbot", height=500)
        status_label = gr.Markdown("🟢 Idle", visible=True)

        with gr.Row():
            user_input = gr.Textbox(placeholder="Ask Finley a question...", scale=8)
            submit_btn = gr.Button("Submit", scale=1)

        show_inner = gr.Checkbox(label="🧠 Show Agent Reasoning", value=True)
        clear_btn = gr.Button("🧹 Clear Chat")

        async def reset_chat():
            global chat
            if chat:
                await chat.reset()
            return [], "🟢 Idle"

        submit_btn.click(
            fn=chat_with_agents_stream,
            inputs=[user_input, chatbot, show_inner],
            outputs=[chatbot, status_label],
            show_progress=True,
            scroll_to_output=True
        )

        clear_btn.click(fn=reset_chat, inputs=None, outputs=[chatbot, status_label])

    demo.launch()

if __name__ == "__main__":
    launch_ui()
