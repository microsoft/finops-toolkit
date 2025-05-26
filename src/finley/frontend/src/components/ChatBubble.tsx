/* eslint-disable @typescript-eslint/no-explicit-any */
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
import { Citation } from "../utils/citationUtils";
import CitationHandler from "./CitationHandler";

interface ChatBubbleProps {
    role: "user" | "agent" | "system" | "assistant";
    agent?: string;
    content: string;
    sources?: string[];
    citations?: Citation[];
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
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    } catch (e) {
        return null;
    }
}

const ChatBubble: React.FC<ChatBubbleProps> = ({
    role,
    agent = "TeamLeader",
    content,
    sources = [],
    citations = []
}) => {
    const isUser = role === "user";
    
    // Log for debugging
    if (citations && citations.length > 0) {
        console.log(`ChatBubble rendering with ${citations.length} citations:`, 
            citations.map(c => ({id: c.id, title: c.title || c.document_name})));
    }

    const cleanedContent = useMemo(() => {
        if (content.includes("Service1.") || content.includes("Service2.")) {
            return content.replace(/Service\d+\./g, "");
        }
        // Remove citation section from content if it will be rendered separately
        if (citations && citations.length > 0 && content.includes("## 📚 Citations and References")) {
            return content.split("## 📚 Citations and References")[0].trim();
        }
        return content.trim();
    }, [content, citations]);

    const jsonTable = role === "user" ? tryRenderJsonTable(cleanedContent) : null;

    return (
        <div className={`ftk-chat-bubble ${isUser ? "ftk-user" : "ftk-agent"}`}>
            <div className="ftk-chat-meta">
                <span className={`ftk-chat-role ftk-tag-${role}`}>
                    {isUser ? "🧑 You" : `${agentEmojis[agent] || "🤖"} ${agent}`}
                </span>
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
                            // eslint-disable-next-line @typescript-eslint/no-unused-vars
                            img: ({ node, ...props }) => (
                                <img
                                    {...props}
                                    style={{ maxWidth: "100%", borderRadius: 6, marginTop: 8 }}
                                    alt="chart"
                                />
                            ),
                            code: (props) => {
                                const { inline, className, children } = props as any;
                                const codeText = (children || "").toString().trim();
                              
                                // only intercept fenced JSON blocks
                                if (!inline && className?.includes("language-json")) {
                                  try {
                                    const parsed = JSON.parse(codeText);
                              
                                    // if it looks like { summary, preview: [ … ] }
                                    if (
                                      parsed &&
                                      typeof parsed === "object" &&
                                      typeof parsed.summary === "string" &&
                                      Array.isArray(parsed.preview)
                                    ) {
                                      // render the summary
                                      const summaryEl = (
                                        <div style={{ marginBottom: "1em" }}>
                                          <strong>Summary</strong>
                                          <p>{parsed.summary}</p>
                                        </div>
                                      );
                              
                                      // render the preview array as a table
                                      const headers = Object.keys(parsed.preview[0] || {});
                                      const rows = parsed.preview;
                              
                                      const tableEl = (
                                        <div style={{ overflowX: "auto" }}>
                                          <table className="ftk-table">
                                            <thead>
                                              <tr>{headers.map((h) => <th key={h}>{h}</th>)}</tr>
                                            </thead>
                                            <tbody>
                                              {rows.map((row: any, i: number) => (
                                                <tr key={i}>
                                                  {headers.map((h) => <td key={h}>{String(row[h] ?? "")}</td>)}
                                                </tr>
                                              ))}
                                            </tbody>
                                          </table>
                                        </div>
                                      );
                              
                                      return (
                                        <div style={{ margin: "1em 0" }}>
                                          {summaryEl}
                                          {tableEl}
                                        </div>
                                      );
                                    }
                                  // eslint-disable-next-line @typescript-eslint/no-unused-vars
                                  } catch (e) {
                                    // fall back to normal code block
                                  }
                                }

                                return inline ? (
                                    <code className={className}>{children}</code>
                                  ) : (
                                    <pre className="ftk-code-block">
                                      <code className={className}>{children}</code>
                                    </pre>
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


                )}                {sources.length > 0 && (
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
                )}                {/* Render citations if available */}
                {citations && citations.length > 0 && (
                    <div className="ftk-chat-citations">
                        <h4 className="ftk-citation-header">📚 Citations and References</h4>
                        <CitationHandler 
                            content={cleanedContent}
                            citations={citations}
                        />
                        {/* Debug info for citation data */}
                        <div style={{ fontSize: '12px', padding: '8px', marginTop: '8px', 
                                    backgroundColor: '#f0f0f0', borderRadius: '4px', 
                                    border: '1px dashed #ccc' }}>
                            <div><strong>Citation Debug:</strong> {citations.length} found</div>
                            <div><strong>Fields:</strong> {citations.length > 0 ? Object.keys(citations[0]).join(', ') : 'none'}</div>
                            <div style={{ maxHeight: '200px', overflow: 'auto', fontSize: '11px', 
                                        marginTop: '4px', fontFamily: 'monospace' }}>
                                {citations.map((c, i) => (
                                    <div key={i} style={{marginBottom: '8px', padding: '4px', borderBottom: '1px dotted #ccc'}}>
                                        <div><strong>[{i+1}] {c.document_name || c.title}</strong> (ID: {c.id})</div>
                                        {c.section && <div style={{color: '#444'}}>
                                            <strong>Section:</strong> {c.section}
                                        </div>}
                                        {c.filepath && <div style={{color: '#444'}}>
                                            <strong>Path:</strong> {c.filepath}
                                        </div>}
                                        {c.chunkId && <div style={{color: '#444'}}>
                                            <strong>Chunk:</strong> {c.chunkId}
                                        </div>}
                                        {c.content && <div style={{marginTop: '4px', color: '#555', 
                                                    fontStyle: 'italic', padding: '4px', backgroundColor: '#f8f8f8',
                                                    borderRadius: '2px', border: '1px solid #eee'}}>
                                            <strong>Content:</strong> "{c.content.substring(0, 100)}..."
                                        </div>}
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

export default ChatBubble;
