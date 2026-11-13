// The only place where the browser talks to the Web API.
// The browser never talks to SQL Server.
const API_URL = "http://localhost:5000/api";

// api("/plans")                         -> GET
// api("/plans", "POST", { PlanName })   -> POST with a JSON body
export async function api(path, method = "GET", body) {
  let response;

  try {
    response = await fetch(API_URL + path, {
      method: method,
      headers: { "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new Error("Cannot reach the API. Is it running on port 5000?");
  }

  // The API always answers JSON; if it does not, data stays null.
  const data = await response.json().catch(() => null);

  if (!response.ok) {
    // { error: "..." } comes from our SQL error handler in Program.cs
    throw new Error((data && (data.error || data.title)) || "Request failed.");
  }

  return data;
}

// Small display helpers used by the pages
export const money = (value) => Number(value).toFixed(2);
export const day = (value) => (value ? String(value).slice(0, 10) : "");
