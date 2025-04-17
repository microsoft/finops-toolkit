import axios from "axios";

export const askFinley = async (prompt: string) => {
  const response = await axios.post("http://localhost:8000/ask", { prompt });
  return response.data.response;
};
