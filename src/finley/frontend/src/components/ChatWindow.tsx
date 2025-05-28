import { useState, useRef, useEffect } from "react";
import { Button, Text } from "@fluentui/react-components";
import ChatBubble from "./ChatBubble";
import TypingBubble from "./TypingBubble";
import "./ChatWindow.css";
import { ChevronDown24Regular, Send24Regular } from "@fluentui/react-icons";
import { Citation, formatCitationsForMarkdown } from "../utils/citationUtils";

type ChatMessage = {
  role: "user" | "agent" | "assistant" | "system";
  agent: string;
  content: string;
  sources?: string[];
  processedContent?: string;
  citations?: Citation[];
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
  const inputRef = useRef<HTMLTextAreaElement>(null);

  const scrollToBottom = () => {
    containerRef.current?.scrollTo({
      top: containerRef.current.scrollHeight,
      behavior: "smooth",
    });
  };
  const handleSend = async () => {
    if (!input.trim() || isTyping) return;  

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
    );    eventSource.onmessage = (event) => {
      const data = JSON.parse(event.data);      // Debug incoming data with more details
      console.log("API Response Data:", {
        content: data.content?.substring(0, 50) + "...",
        hasCitations: data.citations ? true : false,
        citationsCount: data.citations?.length || 0,
        citationFields: data.citations?.length > 0 ? Object.keys(data.citations[0]) : [],
        firstCitation: data.citations?.length > 0 ? JSON.stringify(data.citations[0]).substring(0, 100) + "..." : null,
        responseProperties: Object.keys(data)
      });
      
      if (data.content === "[DONE]") {
        setIsTyping(false);
        setTypingMessage("");
        eventSource.close();
        return;
      }

      // Validate API response structure
      if (!data || typeof data !== 'object') {
        console.error("Invalid API response:", data);
        return;
      }

      // Check if content is present
      if (!data.content?.trim()) return;      // Process citations if present
      let processedContent = data.content;
      let citations: Citation[] = [];
      
      // Improved citation detection - check data.citations for array type and length
      const hasCitations = Array.isArray(data.citations) && data.citations.length > 0;
      console.log("Citation detection:", {
        hasCitations,
        citationsLength: Array.isArray(data.citations) ? data.citations.length : 'not an array',
        firstCitationSample: hasCitations ? JSON.stringify(data.citations[0]).substring(0, 80) + '...' : 'none'
      });
      
      if (hasCitations) {
        try {
          console.log("Processing citations from API:", data.citations.length, 
                     "first citation:", data.citations[0]);          // Use the citations directly rather than trying to parse from content
          citations = data.citations.map((citation: unknown, index: number) => {
            // Ensure citation is an object before spreading
            const citationObj = typeof citation === 'object' && citation !== null ? citation : {};
            
            // Verify all backend fields are present
            const backendFields = [
              'id', 'title', 'section', 'filepath', 
              'document_name', 'chunkId', 'content'
            ];
            
            // Log any missing fields for debugging
            const missingFields = backendFields.filter(
              field => !(field in citationObj)
            );
            
            if (missingFields.length > 0) {
              console.warn(`Citation missing fields: ${missingFields.join(', ')}`);
            }
            
            // Create properly typed citation object, preserving all fields
            // Use type assertion to access specific fields
            const partialCitation = citationObj as Partial<Citation>;
            // Handle possible field name variations with a type-safe approach
            const content = partialCitation.content || 
                            (citationObj as Record<string, unknown>)['content_sample'] as string || 
                            partialCitation.snippet || '';
                            
            const title = partialCitation.title || 
                         partialCitation.document_name || 
                         `Citation ${index + 1}`;
                         
            return {
              ...citationObj,
              id: partialCitation.id || String(index + 1),
              reindex_id: String(index + 1), // Ensure each citation has a display ID
              content: content,
              title: title
            };
          });
          
          // Format and append citations section at the end for visibility
          const formattedCitations = formatCitationsForMarkdown(citations);
          
          // Keep the original content but add citations section at the end
          processedContent = `${data.content}\n\n${formattedCitations}`;
          
          console.log("Processed citations:", citations.length, 
            "with IDs:", citations.map(c => c.id).join(", "));
        } catch (error) {
          console.error('Error processing citations:', error);
          processedContent = data.content;
        }
      }      // Create message with correct structure for proper citation handling
      const msg: ChatMessage = {
        role: data.role || "agent",
        agent: data.agent || "Finley",
        content: processedContent,
        sources: data.sources || [],
        // Ensure citations are explicitly set if available
        citations: citations && citations.length > 0 ? citations : undefined,
      };

      // Create a final check to ensure citations are included in the message
      // If there are citations in the original data, make sure they're passed along
      if (msg.citations === undefined && hasCitations) {
        console.log("Citations were found in data but not properly processed - fixing", {
          citationsInMsg: msg.citations ? 'present' : 'undefined',
          citationsInData: hasCitations ? data.citations.length : 0
        });
        
        // Process citations thoroughly to ensure complete information
        msg.citations = processCitations(data.citations);
      }
      
      // Final legacy citation check
      if (!msg.citations && msg.content.includes('(Source:')) {
        console.log("No structured citations found, but source references exist in text - will be processed by CitationHandler");
      }

      if (msg.role === "system") {
        setIsTyping(true);
        setTypingMessage(msg.content);
      } else {
        // Log the message structure for debugging
        if (msg.citations) {
          console.log("Adding message with citations:", msg.citations.length);
        } else {
          console.log("Adding message with NO citations");
        }
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
    
    // Focus back on the input field after sending
    setTimeout(() => {
      inputRef.current?.focus();
    }, 50);
  };
  // Smooth scroll on new message or typing
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    const handleScroll = () => {
      const isAtBottom =
        Math.abs(container.scrollHeight - container.scrollTop - container.clientHeight) < 50;
      setShowScrollButton(!isAtBottom);
    };
  
    container.addEventListener("scroll", handleScroll);
    return () => container.removeEventListener("scroll", handleScroll);
  }, []);
    // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    if (messages.length > 0) {
      setTimeout(() => {
        scrollToBottom();
      }, 100);
    }
  }, [messages]);
  
  // Auto-scroll when typing indicator appears or disappears
  useEffect(() => {
    setTimeout(() => {
      scrollToBottom();
    }, 100);
  }, [isTyping]);
  
  // Update input rows based on content, but keep it compact and auto-expand
  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setInput(e.target.value);
    if (inputRef.current) {
      inputRef.current.style.height = 'auto';
      inputRef.current.style.height = Math.min(inputRef.current.scrollHeight, 120) + 'px';
    }
  };
  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.style.height = 'auto';
      inputRef.current.style.height = Math.min(inputRef.current.scrollHeight, 120) + 'px';
    }
  }, [input]);

  // Focus input field on component mount
  useEffect(() => {
    setTimeout(() => {
      inputRef.current?.focus();
    }, 500);
  }, []);
  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", padding: "16px 16px 0 16px" }}>
      <div
        ref={containerRef}
        id="chat-container"
        style={{
          flex: 1,
          overflowY: "auto",
          paddingBottom: 90, // Increased padding to ensure content doesn't hide behind input
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
        ) : (          <div
            style={{
              maxWidth: 800,
              margin: "0 auto",
              display: "flex",
              flexDirection: "column",
              gap: 12,
            }}
            className="ftk-chat-messages"
          >            {messages.map((msg, idx) => 
              (msg.role === 'agent' || msg.role === 'assistant') ? (
                <div key={idx}>
                  <ChatBubble
                    role={msg.role}
                    agent={msg.agent}
                    content={msg.content}
                    sources={msg.sources}
                    citations={msg.citations}                  />
                  {/* Debug info - only show in development */}
                  {process.env.NODE_ENV === 'development' && msg.citations && msg.citations.length > 0 && (
                    <div style={{ fontSize: '11px', opacity: 0.6, marginTop: '2px', textAlign: 'right' }}>
                      {msg.citations.length} citations
                    </div>
                  )}
                </div>
              ) : (
                <ChatBubble
                  key={idx}
                  role={msg.role}
                  agent={msg.agent}
                  content={msg.content}
                  sources={msg.sources}
                  citations={msg.citations}
                />
              )
            )}
            {isTyping && <TypingBubble message={typingMessage} />}
          </div>
        )}


      </div>
      {/* Floating scroll-to-bottom button OUTSIDE chat container */}      {showScrollButton && (
  <button className="ftk-scroll-btn" onClick={scrollToBottom} aria-label="Scroll to bottom">
    <ChevronDown24Regular style={{ width: '18px', height: '18px' }} />
  </button>
)}{/* Input Bar */}
      <div className="ftk-chat-inputbar">
        <div className="ftk-chat-inputbar-inner">
          <textarea
            ref={inputRef}
            className="ftk-chat-textarea"
            rows={1}
            value={input}
            placeholder="Ask Finley anything..."
            onChange={handleInputChange}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                handleSend();
              }
              // Focus back on input after Escape
              if (e.key === "Escape") {
                e.preventDefault();
                inputRef.current?.blur();
                setTimeout(() => inputRef.current?.focus(), 100);
              }
            }}
          />
          <Button 
            appearance="primary" 
            className="ftk-chat-send-btn" 
            onClick={handleSend} 
            disabled={!input.trim() || isTyping}
            aria-label="Send message"
          >
            <Send24Regular />
          </Button>
        </div>
      </div>
    </div>
  );
}

// Helper function to thoroughly process citations
function processCitations(rawCitations: Record<string, unknown>[]): Citation[] {
  if (!Array.isArray(rawCitations) || rawCitations.length === 0) return [];
  
  console.log('Processing citations:', rawCitations.length);
  
  return rawCitations.map((citation: Record<string, unknown>, idx: number) => {
    // Extract core fields with type safety
    const id = (citation.id as string) || String(idx + 1);
    const reindex_id = String(idx + 1);
    
    // Try multiple field names for title
    const title = (citation.title as string) || 
                 (citation.document_name as string) || 
                 `Citation ${idx + 1}`;
    
    // Try multiple field names for content
    const content = (citation.content as string) || 
                   (citation.content_sample as string) || 
                   (citation.snippet as string) || 
                   '';
    
    // Extract document name with fallbacks
    const document_name = (citation.document_name as string) || 
                         (citation.title as string) || 
                         `Document ${idx + 1}`;
    
    // Extract filename with multiple strategies
    let file_name = (citation.file_name as string) || '';
    
    // If no direct filename, try to extract from filepath
    if (!file_name && citation.filepath) {
      const filepath = citation.filepath as string;
      const pathParts = filepath.split(/[/\\]/);
      file_name = pathParts[pathParts.length - 1] || '';
    }
    
    // If still no filename but we have a document name, try to extract filename pattern
    if (!file_name && document_name) {
      const filePattern = document_name.match(/(\w+[-_]?\w+\.(pdf|docx|xlsx|html?|md|json|txt|csv))/i);
      if (filePattern) {
        file_name = filePattern[0];
      }
    }
    
    // For debugging
    console.log(`Processed citation ${idx + 1}:`, {
      id,
      title: title.substring(0, 30) + (title.length > 30 ? '...' : ''),
      document_name: document_name.substring(0, 30) + (document_name.length > 30 ? '...' : ''),
      file_name
    });
    
    return {
      id,
      reindex_id,
      title,
      content,
      section: (citation.section as string) || '',
      filepath: (citation.filepath as string) || '',
      chunkId: (citation.chunkId as string) || '',
      document_name,
      file_name,
      // Include any additional metadata that might be useful
      url: (citation.url as string) || '',
      source_info: (citation.source_info as string) || ''
    };
  });
}
