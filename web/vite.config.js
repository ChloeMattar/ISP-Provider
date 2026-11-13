import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The page is served on http://localhost:3000 (the API allows this address in its CORS rule).
export default defineConfig({
  plugins: [react()],
  server: { port: 3000, strictPort: true },
});
