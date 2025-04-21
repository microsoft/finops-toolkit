import React, { useMemo } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import rehypeHighlight from "rehype-highlight";
import "highlight.js/styles/github.css";
import "./ChatBubble.css";
import { agentEmojis } from "../constants/agents";
import "katex/dist/katex.min.css";
import rehypeKatex from "rehype-katex";
import './ftk-markdown.css';
import { Copy20Regular } from "@fluentui/react-icons";


interface ChatBubbleProps {
    role: "user" | "agent" | "system" | "assistant";
    agent?: string;
    content: string;
    sources?: string[];
}

function tryRenderJsonTable(jsonString: string): JSX.Element | null {
    try {
        const parsed = JSON.parse(jsonString.trim());

        if (!Array.isArray(parsed) || parsed.length === 0 || typeof parsed[0] !== "object") {
            return null;
        }

        const headers = Object.keys(parsed[0]);

        return (
            <div style={{ overflowX: "auto" }}>
                <table className="ftk-table">
                    <thead>
                        <tr>
                            {headers.map((key) => (
                                <th key={key}>{key}</th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {parsed.map((row, idx) => (
                            <tr key={idx}>
                                {headers.map((key) => (
                                    <td key={key}>{String(row[key] ?? "")}</td>
                                ))}
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        );
    } catch (e) {
        return null;
    }
}

const ChatBubble: React.FC<ChatBubbleProps> = ({
    role,
    agent = "TeamLeader",
    content,
    sources = [],
}) => {
    const isUser = role === "user";

    const cleanedContent = useMemo(() => {
        if (content.includes("Service1.") || content.includes("Service2.")) {
            return content.replace(/Service\d+\./g, "");
        }
        return content.trim();
    }, [content]);

    const jsonTable = tryRenderJsonTable(cleanedContent);

    return (
        <div className={`ftk-chat-bubble ${isUser ? "ftk-user" : "ftk-agent"}`}>
            <div className="ftk-chat-meta">
                <span className={`ftk-chat-role ftk-tag-${role}`}>
                    {isUser ? "🧑 You" : `${agentEmojis[agent] || "🤖"} ${agent}`}
                </span>
                {!isUser && (
                    <span className="ftk-chat-time">{new Date().toLocaleTimeString()}</span>
                )}
            </div>
            <div className="ftk-chat-content">
                {jsonTable ? (
                    jsonTable
                ) : (
                    <ReactMarkdown
                        children={cleanedContent}
                        remarkPlugins={[remarkGfm]}
                        rehypePlugins={[rehypeHighlight, rehypeKatex]}
                        components={{
                            a: (props) => (
                                <a {...props} target="_blank" rel="noopener noreferrer">
                                    {props.children}
                                </a>
                            ),
                            img: ({ node, ...props }) => (
                                <img
                                    {...props}
                                    style={{ maxWidth: "100%", borderRadius: 6, marginTop: 8 }}
                                    alt="chart"
                                />
                            ),
                            code: (props) => {
                                const { inline, className, children, ...rest } = props as any;
                                const codeText = (children || "").toString().trim();

                                // JSON → table logic (preserve as-is)
                                if (!inline && className?.includes("language-json")) {
                                    try {
                                        const parsed = JSON.parse(codeText);
                                        if (Array.isArray(parsed) && typeof parsed[0] === "object") {
                                            const headers = Object.keys(parsed[0]);
                                            return (
                                                <div style={{ overflowX: "auto" }}>
                                                    <table className="ftk-table">
                                                        <thead>
                                                            <tr>{headers.map((key) => <th key={key}>{key}</th>)}</tr>
                                                        </thead>
                                                        <tbody>
                                                            {parsed.map((row, idx) => (
                                                                <tr key={idx}>
                                                                    {headers.map((key) => (
                                                                        <td key={key}>{String(row[key] ?? "")}</td>
                                                                    ))}
                                                                </tr>
                                                            ))}
                                                        </tbody>
                                                    </table>
                                                </div>
                                            );
                                        }
                                    } catch (err) { }
                                }

                                return !inline ? (
                                    <div className="ftk-code-wrapper">
                                        <button
                                            className="ftk-copy-button"
                                            onClick={() => navigator.clipboard.writeText(codeText)}
                                            title="Copy to clipboard"
                                        >
                                            <Copy20Regular />
                                        </button>

                                        <pre className="ftk-code-block">
                                            <code className={className} {...rest}>{children}</code>
                                        </pre>
                                    </div>
                                ) : (
                                    <code className={className} {...rest}>{children}</code>
                                );
                            },
                            details: ({ children }) => (
                                <details style={{ marginTop: 8 }}>{children}</details>
                            ),
                            summary: ({ children }) => (
                                <summary style={{ cursor: "pointer", fontWeight: 600 }}>{children}</summary>
                            ),

                            table: ({ children }) => (
                                <div style={{ overflowX: "auto" }}>
                                    <table className="ftk-table">{children}</table>
                                </div>
                            ),
                        }}
                    />


                )}
                {sources.length > 0 && (
                    <div className="ftk-chat-sources">
                        <strong>📚 Sources:</strong>
                        <ul>
                            {sources.map((src, i) => (
                                <li key={i}>
                                    <a href={src} target="_blank" rel="noopener noreferrer">
                                        [{i + 1}] {src}
                                    </a>
                                </li>
                            ))}
                        </ul>
                    </div>
                )}
            </div>
        </div>
    );
};

export default ChatBubble;
