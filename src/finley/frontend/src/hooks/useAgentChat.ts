export const useAgentChat = (prompt: string): EventSource => {
    const url = `${import.meta.env.VITE_API_URL}/ask-stream?prompt=${encodeURIComponent(prompt)}`;
    return new EventSource(url);
  };