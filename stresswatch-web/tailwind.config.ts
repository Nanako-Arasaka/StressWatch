import type { Config } from "tailwindcss";

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#1d1d1f",
        "ink-2": "#6e6e73",
        blue: "#0066cc",
        "blue-focus": "#0071e3",
        "blue-sky": "#2997ff",
        parchment: "#f5f5f7",
        tile: "#272729",
        "tile-alt": "#2a2a2c",
        "tile-deep": "#252527",
        green: "#34c759",
        "sleep-deep": "#0A84FF",
        "sleep-core": "#5AC8FA",
        "sleep-rem": "#BF5AF2",
        "sleep-awake": "#FF9F0A"
      },
      boxShadow: {
        product: "rgba(0,0,0,0.22) 3px 5px 30px",
        "product-dark": "rgba(0,0,0,0.55) 3px 5px 30px"
      },
      fontFamily: {
        sans: ['"Noto Sans SC"', "-apple-system", "BlinkMacSystemFont", '"SF Pro Display"', '"Segoe UI"', "sans-serif"]
      },
      maxWidth: {
        apple: "980px"
      }
    }
  },
  plugins: []
} satisfies Config;
