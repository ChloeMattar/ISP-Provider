import { useEffect, useState } from "react";
import { api, money, day, DataTable, Message } from "../shared";

const invoiceColumns = [
  { key: "InvoiceID", label: "Invoice" },
  { key: "CustomerID", label: "Customer ID" },
  { key: "FullName", label: "Customer" },
  { key: "PeriodStart", label: "Month", format: (value) => day(value).slice(0, 7) },
  { key: "Amount", label: "Amount ($)", format: money },
  { key: "AmountPaid", label: "Paid ($)", format: money },
  { key: "Balance", label: "Balance ($)", format: money },
  { key: "Status", label: "Status" },
  { key: "DueDate", label: "Due", format: day },
];

const paymentColumns = [
  { key: "PaymentID", label: "Payment" },
  { key: "Amount", label: "Amount ($)", format: money },
  { key: "Method", label: "Method" },
  { key: "PaidAt", label: "Date", format: day },
];

// Default to last month, since the current one can't be billed yet
const lastMonth = new Date();
lastMonth.setDate(1);
lastMonth.setMonth(lastMonth.getMonth() - 1);

export default function Billing() {
  const [rows, setRows] = useState([]);
  const [onlyUnpaid, setOnlyUnpaid] = useState(true);
  const [filterCustomer, setFilterCustomer] = useState("");
  const [year, setYear] = useState(lastMonth.getFullYear());
  const [month, setMonth] = useState(lastMonth.getMonth() + 1);
  const [selected, setSelected] = useState(null); // invoice open in the payment panel
  const [payments, setPayments] = useState([]);
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("Cash");
  const [message, setMessage] = useState(null);

  async function load() {
    try {
      setRows(await api("/invoices?onlyUnpaid=" + onlyUnpaid + "&customerId=" + filterCustomer));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  useEffect(() => {
    load();
  }, []);

  function onFilter(event) {
    event.preventDefault();
    setMessage(null);
    load();
  }

  async function generate(event) {
    event.preventDefault();
    try {
      const result = await api("/invoices/generate", "POST", { Year: Number(year), Month: Number(month) });
      setMessage({ text: result.InvoicesCreated + " invoices created for " + month + "/" + year + "." });
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  async function select(row) {
    setSelected(row);
    setAmount(row.Balance);
    try {
      setPayments(await api("/invoices/" + row.InvoiceID + "/payments"));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  async function pay(event) {
    event.preventDefault();
    try {
      const result = await api("/invoices/" + selected.InvoiceID + "/payments", "POST", {
        Amount: Number(amount),
        Method: method,
      });
      setMessage({
        text: "Payment saved. Invoice " + result.InvoiceID + " is " + result.Status +
              ", balance " + money(result.Balance) + " $.",
      });
      setSelected(null);
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  return (
    <>
      <Message message={message} />

      <section>
        <h2>Generate the invoices of a month</h2>
        <form onSubmit={generate}>
          <label>
            Year
            <input type="number" value={year} onChange={(event) => setYear(event.target.value)} required />
          </label>
          <label>
            Month
            <input type="number" min="1" max="12" value={month} onChange={(event) => setMonth(event.target.value)} required />
          </label>
          <button type="submit">Generate</button>
        </form>
      </section>

      {selected && (
        <section>
          <h2>
            Pay invoice {selected.InvoiceID} ({selected.FullName}), balance {money(selected.Balance)} $
          </h2>
          <form onSubmit={pay}>
            <label>
              Amount ($)
              <input type="number" step="0.01" value={amount} onChange={(event) => setAmount(event.target.value)} required />
            </label>
            <label>
              Method
              <select value={method} onChange={(event) => setMethod(event.target.value)}>
                <option>Cash</option>
                <option>Card</option>
                <option>Transfer</option>
              </select>
            </label>
            <button type="submit">Record payment</button>
            <button type="button" className="light" onClick={() => setSelected(null)}>
              Close
            </button>
          </form>
          <DataTable columns={paymentColumns} rows={payments} />
        </section>
      )}

      <section>
        <h2>Invoices</h2>
        <form onSubmit={onFilter}>
          <label>
            Customer ID
            <input type="number" value={filterCustomer} onChange={(event) => setFilterCustomer(event.target.value)} />
          </label>
          <label className="check">
            <input type="checkbox" checked={onlyUnpaid} onChange={(event) => setOnlyUnpaid(event.target.checked)} />
            Only unpaid
          </label>
          <button type="submit">Filter</button>
        </form>
        <DataTable
          columns={invoiceColumns}
          rows={rows}
          actions={(row) => (
            <button className="light" onClick={() => select(row)}>
              {row.Status === "Paid" ? "Payments" : "Pay"}
            </button>
          )}
        />
      </section>
    </>
  );
}
