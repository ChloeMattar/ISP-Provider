import { useEffect, useState } from "react";
import { api, money } from "../api";
import DataTable from "../DataTable";
import Message from "../Message";

const emptyForm = {
  PlanName: "",
  SpeedMbps: "",
  QuotaGB: "",
  MonthlyPrice: "",
  OveragePricePerGB: "",
  IsActive: true,
};

const columns = [
  { key: "PlanID", label: "ID" },
  { key: "PlanName", label: "Plan" },
  { key: "SpeedMbps", label: "Speed (Mbps)" },
  { key: "QuotaGB", label: "Quota (GB)" },
  { key: "MonthlyPrice", label: "Price / month ($)", format: money },
  { key: "OveragePricePerGB", label: "Extra GB ($)", format: money },
  { key: "IsActive", label: "On sale", format: (value) => (value ? "Yes" : "No") },
];

export default function Plans() {
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [message, setMessage] = useState(null);

  async function load() {
    try {
      setRows(await api("/plans"));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  useEffect(() => {
    load();
  }, []);

  function change(event) {
    // a checkbox gives true/false in "checked", the other inputs give text in "value"
    const value = event.target.type === "checkbox" ? event.target.checked : event.target.value;
    setForm({ ...form, [event.target.name]: value });
  }

  async function save(event) {
    event.preventDefault();

    // The inputs give text; the API expects numbers
    const body = {
      PlanName: form.PlanName,
      SpeedMbps: Number(form.SpeedMbps),
      QuotaGB: Number(form.QuotaGB),
      MonthlyPrice: Number(form.MonthlyPrice),
      OveragePricePerGB: Number(form.OveragePricePerGB),
      IsActive: form.IsActive,
    };

    try {
      if (editingId) {
        await api("/plans/" + editingId, "PUT", body);
        setMessage({ text: "Plan updated." });
      } else {
        await api("/plans", "POST", body);
        setMessage({ text: "Plan added." });
      }
      setForm(emptyForm);
      setEditingId(null);
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  function startEdit(row) {
    setEditingId(row.PlanID);
    setForm({
      PlanName: row.PlanName,
      SpeedMbps: row.SpeedMbps,
      QuotaGB: row.QuotaGB,
      MonthlyPrice: row.MonthlyPrice,
      OveragePricePerGB: row.OveragePricePerGB,
      IsActive: row.IsActive,
    });
  }

  function cancelEdit() {
    setEditingId(null);
    setForm(emptyForm);
  }

  return (
    <>
      <Message message={message} />

      <section>
        <h2>{editingId ? "Edit plan " + editingId : "Add a plan"}</h2>
        <form onSubmit={save}>
          <label>
            Name
            <input name="PlanName" value={form.PlanName} onChange={change} required maxLength={50} />
          </label>
          <label>
            Speed (Mbps)
            <input name="SpeedMbps" type="number" value={form.SpeedMbps} onChange={change} required />
          </label>
          <label>
            Quota (GB)
            <input name="QuotaGB" type="number" value={form.QuotaGB} onChange={change} required />
          </label>
          <label>
            Price / month ($)
            <input name="MonthlyPrice" type="number" step="0.01" value={form.MonthlyPrice} onChange={change} required />
          </label>
          <label>
            Extra GB ($)
            <input name="OveragePricePerGB" type="number" step="0.01" value={form.OveragePricePerGB} onChange={change} required />
          </label>
          {editingId && (
            <label className="check">
              <input name="IsActive" type="checkbox" checked={form.IsActive} onChange={change} />
              On sale
            </label>
          )}
          <button type="submit">{editingId ? "Save" : "Add"}</button>
          {editingId && (
            <button type="button" className="light" onClick={cancelEdit}>
              Cancel
            </button>
          )}
        </form>
      </section>

      <section>
        <h2>Internet plans</h2>
        <DataTable
          columns={columns}
          rows={rows}
          actions={(row) => (
            <button className="light" onClick={() => startEdit(row)}>
              Edit
            </button>
          )}
        />
      </section>
    </>
  );
}
