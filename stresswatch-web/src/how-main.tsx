import { StrictMode } from "react";
import ReactDOM from "react-dom/client";
import { HowPage } from "./App";
import "./typography.css";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <StrictMode>
    <HowPage />
  </StrictMode>
);