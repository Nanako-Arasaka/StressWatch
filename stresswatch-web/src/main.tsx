import { StrictMode } from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./typography.css";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <StrictMode>
    <App />
  </StrictMode>
);
