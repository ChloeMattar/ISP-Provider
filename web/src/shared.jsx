// Helpers shared by all the pages.

// The browser only ever talks to the Web API, never to SQL Server.
const API_URL = "http://localhost:5000/api";

// Calls the API, e.g. api("/plans") or api("/customers", "POST", form).
// Throws an Error with the API's message if the request fails.
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

  const data = await response.json().catch(() => null);

  if (!response.ok) {
    // "error" is set by the SQL error handler in Program.cs
    throw new Error((data && (data.error || data.title)) || "Request failed.");
  }

  return data;
}

// 12.5 -> "12.50"
export const money = (value) => Number(value).toFixed(2);

// "2026-03-01T00:00:00" -> "2026-03-01"
export const day = (value) => (value ? String(value).slice(0, 10) : "");

// Table used by every page.
// columns: [{ key: "FullName", label: "Name", format?: (value, row) => ... }]
// actions: optional, returns the buttons for a row
export function DataTable({ columns, rows, actions }) {
  if (rows.length === 0) {
    return <p className="empty">No rows.</p>;
  }

  return (
    <table>
      <thead>
        <tr>
          {columns.map((column) => (
            <th key={column.key}>{column.label}</th>
          ))}
          {actions && <th></th>}
        </tr>
      </thead>
      <tbody>
        {rows.map((row, index) => (
          <tr key={index}>
            {columns.map((column) => (
              <td key={column.key}>
                {column.format ? column.format(row[column.key], row) : row[column.key]}
              </td>
            ))}
            {actions && <td className="actions">{actions(row)}</td>}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// Green box for success, red for errors.
export function Message({ message }) {
  if (!message) return null;
  return <div className={message.error ? "message error" : "message ok"}>{message.text}</div>;
}
