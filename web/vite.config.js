import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Port 3000 is the one the API allows in its CORS rule.
export default defineConfig({
  plugins: [react()],
  server: { port: 3000, strictPort: true },
});
