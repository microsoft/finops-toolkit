import { useState, useRef, useEffect } from "react";
import { Input, Button, Text } from "@fluentui/react-components";
import ChatBubble from "./ChatBubble";
import TypingBubble from "./TypingBubble";
import "./ChatWindow.css";
import { ChevronDown24Regular } from "@fluentui/react-icons";

type ChatMessage = {
  role: "user" | "agent" | "assistant" | "system";
  agent: string;
  content: string;
  sources?: string[];
};

const promptSuggestions = [
  "Educate me on the Finops Framework.",
  "What is FOCUS and why should I care?",
  "What are the top 5 costly services?",
  "Show me monthly trends for storage costs",
  "Which region has the highest usage?",
  "What were my total savings of the last 3 months?",
  "Identify resource outliers for this month based on cost.",
  "What was the cost of the top consuming resource in West Europe?",
  "List untagged resources with high costs.",
  "Can you provide the monthly cost consumption forecast for the next six months based on historical data? Please ensure a linear or average growth rate method is applied if more advanced plugins are unavailable.",
  // "Based on averaging past monthly costs, create a forecast for this environment for the next 3 months"
  // "Based on averaging past monthly costs, create a forecast for resource group rg-finopshubs0-7-adx for the next 3 months"
  "Give me the list of the top 3 biggest consumers, meaning resource based on aggregated cost of the past 3 months.",
//   "Can you provide a detailed analysis of aggregated costs for each individual resource in the resource group rg-mgmt over the past three months? I want to identify trends and spikes for Virtual Machines, Storage Accounts, and Azure Cognitive Services, and highlight any opportunities for cost optimization.Please ensure the analysis includes all costs across the entire three-month period.",
  // "Are there any cost optimization recommendations for this resource group, such as underutilized resources or resizing opportunities?",
  "Give me a summary table of the consumption for AI and Machine Learning service category of this month and list the resources by name meaning resource based on aggregated cost by subscription name.",
  // "Give me a list of the top 10 consumers of the service category of AI and Machine Learning by resource name and aggregated cost of the past 3 months.",
//   "Can you detect any cost anomalies over the past 7 days by comparing daily cost deviations from the weekly average using standard deviation?"
];

export default function ChatWindow() {
  const [input, setInput] = useState("");
  const sessionIdRef = useRef(
    localStorage.getItem("sessionId") || crypto.randomUUID()
  );
  useEffect(() => {
    localStorage.setItem("sessionId", sessionIdRef.current);
  }, []);
  
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const containerRef = useRef<HTMLDivElement>(null);
  const [isTyping, setIsTyping] = useState(false);
  const [typingMessage, setTypingMessage] = useState<string>("Finley is thinking...");
  const [showScrollButton, setShowScrollButton] = useState(false);

  const scrollToBottom = () => {
    containerRef.current?.scrollTo({
      top: containerRef.current.scrollHeight,
      behavior: "smooth",
    });
  };

  const handleSend = async () => {
    if (!input.trim()) return;

    setMessages((prev) => [
      ...prev,
      {
        role: "user",
        agent: "You",
        content: input,
      },
    ]);

    setIsTyping(true);
    const encodedPrompt = encodeURIComponent(input);
    const baseUrl = import.meta.env.VITE_BACKEND_URL;
    const eventSource = new EventSource(
    `${baseUrl}/api/ask-stream?prompt=${encodedPrompt}&sessionId=${sessionIdRef.current}`
    );
    eventSource.onmessage = (event) => {
      const data = JSON.parse(event.data);

      if (data.content === "[DONE]") {
        setIsTyping(false);
        setTypingMessage("");
        eventSource.close();
        return;
      }

      if (!data.content?.trim()) return;

      const msg: ChatMessage = {
        role: data.role || "agent",
        agent: data.agent || "Finley",
        content: data.content,
        sources: data.sources || [],
      };

      if (msg.role === "system") {
        setIsTyping(true);
        setTypingMessage(msg.content);
      } else {
        setMessages((prev) => [...prev, msg]);
      }
    };

    eventSource.onerror = (err) => {
      console.error("❌ Stream error:", err);
      setIsTyping(false);
      setMessages((prev) => [
        ...prev,
        {
          role: "agent",
          agent: "Finley",
          content: "⚠️ Something went wrong. Please try again or check the server.",
        },
      ]);
      eventSource.close();
    };

    setInput("");
  };

  // Smooth scroll on new message or typing
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
  
    const handleScroll = () => {
      const isAtBottom =
        Math.abs(container.scrollHeight - container.scrollTop - container.clientHeight) < 80;
      setShowScrollButton(!isAtBottom);
    };
  
    container.addEventListener("scroll", handleScroll);
    return () => container.removeEventListener("scroll", handleScroll);
  }, []);
  

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", padding: 16 }}>
      <div
        ref={containerRef}
        id="chat-container"
        style={{
          flex: 1,
          overflowY: "auto",
          paddingBottom: 80,
          position: "relative",
        }}
      >
        {messages.length === 0 ? (
          <div className="welcome-container">
            <Text
              size={800}
              weight="semibold"
              style={{
                background: "linear-gradient(to right, #4f46e5, #9333ea)",
                WebkitBackgroundClip: "text",
                color: "transparent",
              }}
            >
              Hello, FinOps Explorer
            </Text>
            <Text size={400} style={{ marginTop: 8 }}>
              Ask Finley anything about your Azure environment.
            </Text>
            <div
              style={{
                marginTop: 24,
                display: "flex",
                gap: 8,
                flexWrap: "wrap",
                justifyContent: "center",
              }}
            >
              {promptSuggestions.map((suggestion, idx) => (
                <Button
                  key={idx}
                  appearance="secondary"
                  className="prompt-tile-glow"
                  onClick={() => {
                    setInput(suggestion);
                    handleSend();
                  }}
                >
                  {suggestion}
                </Button>
              ))}
            </div>
          </div>
        ) : (
          <div
            style={{
              maxWidth: 800,
              margin: "0 auto",
              display: "flex",
              flexDirection: "column",
              gap: 12,
            }}
          >
            {messages.map((msg, idx) => (
              <ChatBubble
                key={idx}
                role={msg.role}
                agent={msg.agent}
                content={msg.content}
                sources={msg.sources}
              />
            ))}
            {isTyping && <TypingBubble message={typingMessage} />}
          </div>
        )}


      </div>
      {/* Floating scroll-to-bottom button OUTSIDE chat container */}

      {showScrollButton && (
  <button className="ftk-scroll-btn" onClick={scrollToBottom} aria-label="Scroll to bottom">
    <ChevronDown24Regular />
  </button>
)}

      {/* Input Bar */}
      <div
        style={{
          position: "fixed",
          bottom: 24,
          left: "50%",
          transform: "translateX(-50%)",
          width: "100%",
          maxWidth: 800,
          padding: "0 16px",
        }}
      >
        <div style={{ display: "flex", gap: 8 }}>
          <Input
            size="large"
            value={input}
            placeholder="Ask Finley anything..."
            onChange={(_e, data) => setInput(data.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSend()}
            style={{ flex: 1 }}
          />
          <Button appearance="primary" onClick={handleSend}>
            Send
          </Button>
        </div>
      </div>
    </div>
  );
}
