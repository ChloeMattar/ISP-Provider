import { useState } from "react";
import { api, money, day, DataTable, Message } from "../shared";

const monthlyColumns = [
  { key: "FullName", label: "Customer" },
  { key: "PlanName", label: "Plan" },
  { key: "DownloadGB", label: "Download (GB)" },
  { key: "UploadGB", label: "Upload (GB)" },
  {
    key: "TotalGB",
    label: "Total (GB)",
    // shown in red when over the plan's quota
    format: (value, row) => <span className={value > row.QuotaGB ? "over" : ""}>{value}</span>,
  },
  { key: "QuotaGB", label: "Quota (GB)" },
  // invoice columns are null until the month is billed
  { key: "InvoiceAmount", label: "Invoice ($)", format: (value) => (value == null ? "Not billed yet" : money(value)) },
  { key: "InvoicePaid", label: "Paid ($)", format: (value) => (value == null ? "" : money(value)) },
  { key: "InvoiceStatus", label: "Invoice status" },
];

const dailyColumns = [
  { key: "UsageDate", label: "Day", format: day },
  { key: "DownloadMB", label: "Download (MB)" },
  { key: "UploadMB", label: "Upload (MB)" },
];

const reportColumns = [
  { key: "SubscriptionID", label: "Subscription" },
  { key: "FullName", label: "Customer" },
  { key: "PlanName", label: "Plan" },
  { key: "DaysCounted", label: "Days" },
  { key: "DownloadGB", label: "Download (GB)" },
  { key: "UploadGB", label: "Upload (GB)" },
  { key: "TotalGB", label: "Total (GB)" },
];

export default function Usage() {
  // one subscription, one month
  const [subscriptionId, setSubscriptionId] = useState("509");
  const [year, setYear] = useState(2026);
  const [month, setMonth] = useState(9);
  const [monthly, setMonthly] = useState([]);
  const [daily, setDaily] = useState([]);

  // report for all subscriptions between two dates
  const [reportFrom, setReportFrom] = useState("2026-10-01");
  const [reportTo, setReportTo] = useState("2026-10-31");
  const [report, setReport] = useState([]);

  const [message, setMessage] = useState(null);

  async function loadSubscription(event) {
    event.preventDefault();
    setMessage(null);

    // First and last day of the month.
    // Day 0 of the next month is the last day of this one.
    const twoDigitMonth = String(month).padStart(2, "0");
    const lastDay = new Date(year, month, 0).getDate();
    const from = year + "-" + twoDigitMonth + "-01";
    const to = year + "-" + twoDigitMonth + "-" + lastDay;

    try {
      setMonthly(await api("/usage/monthly/" + subscriptionId + "?year=" + year + "&month=" + month));
      setDaily(await api("/usage/daily/" + subscriptionId + "?from=" + from + "&to=" + to));
    } catch (error) {
      setMonthly([]);
      setDaily([]);
      setMessage({ error: true, text: error.message });
    }
  }

  async function loadReport(event) {
    event.preventDefault();
    setMessage(null);
    try {
      setReport(await api("/usage/report?from=" + reportFrom + "&to=" + reportTo));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  // totals for the whole report
  let totalDownload = 0;
  let totalUpload = 0;
  let totalAll = 0;
  for (const row of report) {
    totalDownload += row.DownloadGB;
    totalUpload += row.UploadGB;
    totalAll += row.TotalGB;
  }

  return (
    <>
      <Message message={message} />

      <section>
        <h2>Monthly usage of one subscription</h2>
        <form onSubmit={loadSubscription}>
          <label>
            Subscription ID
            <input type="number" value={subscriptionId} onChange={(event) => setSubscriptionId(event.target.value)} required />
          </label>
          <label>
            Year
            <input type="number" min="2000" max="2100" value={year} onChange={(event) => setYear(event.target.value)} required />
          </label>
          <label>
            Month
            <input type="number" min="1" max="12" value={month} onChange={(event) => setMonth(event.target.value)} required />
          </label>
          <button type="submit">Show</button>
        </form>
        {monthly.length > 0 && <DataTable columns={monthlyColumns} rows={monthly} />}
        {monthly.length > 0 && <DataTable columns={dailyColumns} rows={daily} />}
      </section>

      <section>
        <h2>Usage report between two dates (all subscriptions)</h2>
        <form onSubmit={loadReport}>
          <label>
            From
            <input type="date" value={reportFrom} onChange={(event) => setReportFrom(event.target.value)} required />
          </label>
          <label>
            To
            <input type="date" value={reportTo} onChange={(event) => setReportTo(event.target.value)} required />
          </label>
          <button type="submit">Show report</button>
        </form>
        {report.length > 0 && (
          <p className="total">
            Total for the period: <strong>{report.length}</strong> subscriptions, download{" "}
            <strong>{totalDownload.toFixed(2)} GB</strong>, upload <strong>{totalUpload.toFixed(2)} GB</strong>,
            total <strong>{totalAll.toFixed(2)} GB</strong>
          </p>
        )}
        {report.length > 0 && <DataTable columns={reportColumns} rows={report} />}
      </section>
    </>
  );
}
