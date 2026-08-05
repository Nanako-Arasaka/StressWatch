import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./typography.css";
import "./styles.css";

const container = document.getElementById("root");
if (container) {
  createRoot(container).render(
    <React.StrictMode>
      <App variant="about" />
    </React.StrictMode>
  );
}