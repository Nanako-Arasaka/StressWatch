import type { Config } from "tailwindcss";

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#111F2A",
        pine: "#1D5D70",
        teal: "#27A6CC",
        mint: "#80BFD4",
        aqua: "#B7DCE8",
        cream: "#F7FBFD",
        sun: "#FCC5C5"
      },
      boxShadow: {
        glass: "0 26px 80px rgba(39, 166, 204, 0.14)",
        soft: "0 18px 48px rgba(39, 166, 204, 0.10)"
      },
      fontFamily: {
        sans: [
          "Inter",
          "ui-sans-serif",
          "system-ui",
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "sans-serif"
        ]
      },
      keyframes: {
        float: {
          "0%, 100%": { transform: "translateY(0)" },
          "50%": { transform: "translateY(-2px)" }
        },
        rise: {
          "0%": { opacity: "0", transform: "translateY(22px)" },
          "100%": { opacity: "1", transform: "translateY(0)" }
        },
        draw: {
          "0%": { strokeDashoffset: "440" },
          "100%": { strokeDashoffset: "0" }
        }
      },
      animation: {
        float: "float 14s ease-in-out infinite",
        rise: "rise 700ms ease-out both",
        draw: "draw 1.4s ease-out both"
      }
    }
  },
  plugins: []
} satisfies Config;
