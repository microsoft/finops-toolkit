import { Text, Button } from "@fluentui/react-components";
import { useNavigate } from "react-router-dom";

export default function HomePage() {
  const navigate = useNavigate();

  return (
    <div
      style={{
        height: "100vh",
        textAlign: "center",
        backgroundColor: "#fff",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        gap: "24px",
        padding: "0 16px",
      }}
    >
      <Text
        weight="bold"
        size={800}
        style={{
          background: "linear-gradient(to right, #2563eb, #9333ea)",
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
        }}
      >
        Hello, FinOps Explorer
      </Text>

      <Text size={400} style={{ color: "#666", maxWidth: "600px" }}>
        Finley is your intelligent FinOps assistant. Ask questions about Azure costs, KQL, or resources.
      </Text>

      <Button
        appearance="primary"
        size="large"
        onClick={() => navigate("/chat")}
      >
        💬 Chat with Finley
      </Button>
    </div>
  );
}
