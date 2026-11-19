import { useEffect, useState } from "react";
import { api, money, day, DataTable, Message } from "../shared";

const columns = [
  { key: "SubscriptionID", label: "ID" },
  { key: "CustomerID", label: "Customer ID" },
  { key: "FullName", label: "Customer" },
  { key: "PlanName", label: "Plan" },
  { key: "MonthlyPrice", label: "Price ($)", format: money },
  { key: "StartDate", label: "Start", format: day },
  { key: "EndDate", label: "End", format: day },
  { key: "Status", label: "Status" },
];

export default function Subscriptions() {
  const [rows, setRows] = useState([]);
  const [plans, setPlans] = useState([]);
  const [filterCustomer, setFilterCustomer] = useState("");
  const [filterStatus, setFilterStatus] = useState("");
  const [filterPlan, setFilterPlan] = useState("");
  const [newCustomer, setNewCustomer] = useState("");
  const [newPlan, setNewPlan] = useState("");
  const [message, setMessage] = useState(null);

  async function load() {
    try {
      setRows(
        await api(
          "/subscriptions?customerName=" + encodeURIComponent(filterCustomer) +
            "&status=" + filterStatus +
            "&planId=" + filterPlan
        )
      );
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  // on load: the list, plus the plans for the drop-downs
  useEffect(() => {
    load();
    api("/plans")
      .then((all) => setPlans(all.filter((plan) => plan.IsActive)))
      .catch((error) => setMessage({ error: true, text: error.message }));
  }, []);

  function onFilter(event) {
    event.preventDefault();
    setMessage(null);
    load();
  }

  async function activate(event) {
    event.preventDefault();
    try {
      const result = await api("/subscriptions", "POST", {
        CustomerID: Number(newCustomer),
        PlanID: Number(newPlan),
      });
      setMessage({ text: "Subscription " + result.SubscriptionID + " activated." });
      setNewCustomer("");
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  async function cancel(row) {
    const sure = window.confirm(
      "Cancel subscription " + row.SubscriptionID + " of " + row.FullName + "? This cannot be undone."
    );
    if (!sure) return;

    try {
      await api("/subscriptions/" + row.SubscriptionID + "/cancel", "PUT");
      setMessage({ text: "Subscription " + row.SubscriptionID + " is now Cancelled." });
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  // only active subscriptions get a Cancel button
  function actions(row) {
    if (row.Status === "Cancelled") return null;

    return (
      <button className="danger" onClick={() => cancel(row)}>
        Cancel
      </button>
    );
  }

  return (
    <>
      <Message message={message} />

      <section>
        <h2>Activate a subscription</h2>
        <form onSubmit={activate}>
          <label>
            Customer ID
            <input type="number" value={newCustomer} onChange={(event) => setNewCustomer(event.target.value)} required />
          </label>
          <label>
            Plan
            <select value={newPlan} onChange={(event) => setNewPlan(event.target.value)} required>
              <option value="">Choose...</option>
              {plans.map((plan) => (
                <option key={plan.PlanID} value={plan.PlanID}>
                  {plan.PlanName} ({money(plan.MonthlyPrice)} $)
                </option>
              ))}
            </select>
          </label>
          <button type="submit">Activate</button>
        </form>
      </section>

      <section>
        <h2>Subscriptions</h2>
        <form onSubmit={onFilter}>
          <label>
            Customer name
            <input value={filterCustomer} onChange={(event) => setFilterCustomer(event.target.value)} />
          </label>
          <label>
            Plan
            <select value={filterPlan} onChange={(event) => setFilterPlan(event.target.value)}>
              <option value="">All</option>
              {plans.map((plan) => (
                <option key={plan.PlanID} value={plan.PlanID}>
                  {plan.PlanName}
                </option>
              ))}
            </select>
          </label>
          <label>
            Status
            <select value={filterStatus} onChange={(event) => setFilterStatus(event.target.value)}>
              <option value="">All</option>
              <option>Active</option>
              <option>Cancelled</option>
            </select>
          </label>
          <button type="submit">Filter</button>
        </form>
        <DataTable columns={columns} rows={rows} actions={actions} />
      </section>
    </>
  );
}
