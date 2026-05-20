import type { Config } from "tailwindcss";

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#14352e",
        pine: "#20493f",
        teal: "#2f7e70",
        mint: "#9ee8cb",
        aqua: "#8be4e8",
        cream: "#f6fbf6",
        sun: "#f2cc4d"
      },
      boxShadow: {
        glass: "0 26px 80px rgba(22, 63, 53, 0.18)",
        soft: "0 18px 48px rgba(25, 80, 68, 0.12)"
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
          "50%": { transform: "translateY(-14px)" }
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
        float: "float 6s ease-in-out infinite",
        rise: "rise 700ms ease-out both",
        draw: "draw 1.4s ease-out both"
      }
    }
  },
  plugins: []
} satisfies Config;
