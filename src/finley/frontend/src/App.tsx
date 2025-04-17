// src/App.tsx
import { FluentProvider, webLightTheme } from "@fluentui/react-components";
import { Outlet } from "react-router-dom";
import NavBar from "./components/NavBar";

function App() {
  return (
    <FluentProvider theme={webLightTheme}>
      <div style={{ height: "100vh", display: "flex", flexDirection: "column" }}>
        <NavBar />
        <div style={{ flex: 1 }}>
          <Outlet />
        </div>
      </div>
    </FluentProvider>
  );
}

export default App;


