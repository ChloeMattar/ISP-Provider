import { useEffect, useState } from "react";
import { api, money, day } from "../api";
import DataTable from "../DataTable";
import Message from "../Message";

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
  const [newCustomer, setNewCustomer] = useState("");
  const [newPlan, setNewPlan] = useState("");
  const [message, setMessage] = useState(null);

  async function load() {
    try {
      setRows(await api("/subscriptions?customerId=" + filterCustomer + "&status=" + filterStatus));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  // When the page opens: the list, and the plans for the drop-down lists
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

  async function setStatus(row, newStatus) {
    try {
      await api("/subscriptions/" + row.SubscriptionID + "/status", "PUT", { NewStatus: newStatus });
      setMessage({ text: "Subscription " + row.SubscriptionID + " is now " + newStatus + "." });
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  async function changePlan(row, planId) {
    if (!planId) return;
    try {
      await api("/subscriptions/" + row.SubscriptionID + "/plan", "PUT", { NewPlanID: Number(planId) });
      setMessage({ text: "Plan of subscription " + row.SubscriptionID + " changed." });
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  // Buttons shown on each row depend on the current status
  function actions(row) {
    if (row.Status === "Cancelled") return null;

    return (
      <>
        {row.Status === "Active" && (
          <button className="light" onClick={() => setStatus(row, "Suspended")}>
            Suspend
          </button>
        )}
        {row.Status === "Suspended" && (
          <button className="light" onClick={() => setStatus(row, "Active")}>
            Resume
          </button>
        )}
        <button className="danger" onClick={() => setStatus(row, "Cancelled")}>
          Cancel
        </button>
        <select value="" onChange={(event) => changePlan(row, event.target.value)}>
          <option value="">Change plan...</option>
          {plans
            .filter((plan) => plan.PlanID !== row.PlanID)
            .map((plan) => (
              <option key={plan.PlanID} value={plan.PlanID}>
                {plan.PlanName}
              </option>
            ))}
        </select>
      </>
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
            Customer ID
            <input type="number" value={filterCustomer} onChange={(event) => setFilterCustomer(event.target.value)} />
          </label>
          <label>
            Status
            <select value={filterStatus} onChange={(event) => setFilterStatus(event.target.value)}>
              <option value="">All</option>
              <option>Active</option>
              <option>Suspended</option>
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
