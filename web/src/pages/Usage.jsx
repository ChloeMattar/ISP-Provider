import { useState } from "react";
import { api, day } from "../api";
import DataTable from "../DataTable";
import Message from "../Message";

const summaryColumns = [
  { key: "MonthStart", label: "Month", format: (value) => day(value).slice(0, 7) },
  { key: "DownloadGB", label: "Download (GB)" },
  { key: "UploadGB", label: "Upload (GB)" },
  {
    key: "TotalGB",
    label: "Total (GB)",
    // red when the customer went over the quota of the plan
    format: (value, row) => <span className={value > row.QuotaGB ? "over" : ""}>{value}</span>,
  },
  { key: "QuotaGB", label: "Quota (GB)" },
];

const dailyColumns = [
  { key: "UsageDate", label: "Day", format: day },
  { key: "DownloadMB", label: "Download (MB)" },
  { key: "UploadMB", label: "Upload (MB)" },
];

const topColumns = [
  { key: "SubscriptionID", label: "Subscription" },
  { key: "FullName", label: "Customer" },
  { key: "PlanName", label: "Plan" },
  { key: "QuotaGB", label: "Quota (GB)" },
  { key: "TotalGB", label: "Used (GB)" },
];

export default function Usage() {
  const [subscriptionId, setSubscriptionId] = useState("509");
  const [from, setFrom] = useState("2026-10-01");
  const [to, setTo] = useState("2026-10-31");
  const [summary, setSummary] = useState([]);
  const [daily, setDaily] = useState([]);

  const [year, setYear] = useState(2026);
  const [month, setMonth] = useState(10);
  const [top, setTop] = useState([]);

  const [newUsage, setNewUsage] = useState({ SubscriptionID: "", UsageDate: "", DownloadMB: "", UploadMB: "" });
  const [message, setMessage] = useState(null);

  async function loadSubscription(event) {
    event.preventDefault();
    setMessage(null);
    try {
      setSummary(await api("/usage/summary/" + subscriptionId));
      setDaily(await api("/usage/daily/" + subscriptionId + "?from=" + from + "&to=" + to));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  async function loadTop(event) {
    event.preventDefault();
    setMessage(null);
    try {
      setTop(await api("/usage/top?year=" + year + "&month=" + month + "&top=10"));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  function changeNewUsage(event) {
    setNewUsage({ ...newUsage, [event.target.name]: event.target.value });
  }

  async function addUsage(event) {
    event.preventDefault();
    try {
      await api("/usage", "POST", {
        SubscriptionID: Number(newUsage.SubscriptionID),
        UsageDate: newUsage.UsageDate,
        DownloadMB: Number(newUsage.DownloadMB),
        UploadMB: Number(newUsage.UploadMB),
      });
      setMessage({ text: "Usage saved." });
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  return (
    <>
      <Message message={message} />

      <section>
        <h2>Usage of one subscription</h2>
        <form onSubmit={loadSubscription}>
          <label>
            Subscription ID
            <input type="number" value={subscriptionId} onChange={(event) => setSubscriptionId(event.target.value)} required />
          </label>
          <label>
            Daily detail from
            <input type="date" value={from} onChange={(event) => setFrom(event.target.value)} required />
          </label>
          <label>
            to
            <input type="date" value={to} onChange={(event) => setTo(event.target.value)} required />
          </label>
          <button type="submit">Show</button>
        </form>
        {summary.length > 0 && <DataTable columns={summaryColumns} rows={summary} />}
        {daily.length > 0 && <DataTable columns={dailyColumns} rows={daily} />}
      </section>

      <section>
        <h2>Top 10 consumers of a month</h2>
        <form onSubmit={loadTop}>
          <label>
            Year
            <input type="number" value={year} onChange={(event) => setYear(event.target.value)} required />
          </label>
          <label>
            Month
            <input type="number" min="1" max="12" value={month} onChange={(event) => setMonth(event.target.value)} required />
          </label>
          <button type="submit">Show</button>
        </form>
        {top.length > 0 && <DataTable columns={topColumns} rows={top} />}
      </section>

      <section>
        <h2>Record usage for one day</h2>
        <form onSubmit={addUsage}>
          <label>
            Subscription ID
            <input name="SubscriptionID" type="number" value={newUsage.SubscriptionID} onChange={changeNewUsage} required />
          </label>
          <label>
            Day
            <input name="UsageDate" type="date" value={newUsage.UsageDate} onChange={changeNewUsage} required />
          </label>
          <label>
            Download (MB)
            <input name="DownloadMB" type="number" value={newUsage.DownloadMB} onChange={changeNewUsage} required />
          </label>
          <label>
            Upload (MB)
            <input name="UploadMB" type="number" value={newUsage.UploadMB} onChange={changeNewUsage} required />
          </label>
          <button type="submit">Save</button>
        </form>
      </section>
    </>
  );
}
