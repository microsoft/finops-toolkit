import { useEffect, useState } from "react";
import "./TypingBubble.css";

const spinnerFrames = [
  "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏",
  "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇"
];

const TypingBubble = ({ message = "Finley is thinking..." }) => {
  const [frameIndex, setFrameIndex] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setFrameIndex((prev) => (prev + 1) % spinnerFrames.length);
    }, 80);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="ftk-chat-bubble ftk-agent">
      <div className="ftk-chat-meta">
        <span className="ftk-chat-role ftk-tag-agent">🤖 Finley</span>
        <span className="ftk-chat-time">{new Date().toLocaleTimeString()}</span>
      </div>
      <div className="ftk-chat-content">
        <div>{message}</div>
        <div className="braille-spinner" aria-label="Finley is typing" role="status">
          {spinnerFrames[frameIndex]}
        </div>
      </div>
    </div>
  );
};

export default TypingBubble;
