import { useEffect, useState } from "react";
import { api, money, DataTable, Message } from "../shared";

const columns = [
  { key: "PlanID", label: "ID" },
  { key: "PlanName", label: "Plan" },
  { key: "SpeedMbps", label: "Speed (Mbps)" },
  { key: "QuotaGB", label: "Quota (GB)" },
  { key: "MonthlyPrice", label: "Price / month ($)", format: money },
  { key: "OveragePricePerGB", label: "Extra GB ($)", format: money },
  { key: "IsActive", label: "On sale", format: (value) => (value ? "Yes" : "No") },
];

// Read-only: plans are created by the SQL data script.
export default function Plans() {
  const [rows, setRows] = useState([]);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    api("/plans")
      .then(setRows)
      .catch((error) => setMessage({ error: true, text: error.message }));
  }, []);

  return (
    <>
      <Message message={message} />

      <section>
        <h2>Internet plans</h2>
        <DataTable columns={columns} rows={rows} />
      </section>
    </>
  );
}
