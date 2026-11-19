import { useEffect, useState } from "react";
import { api, money, DataTable, Message } from "../shared";

const emptyForm = { FullName: "", Phone: "", Email: "", City: "" };

const columns = [
  { key: "CustomerID", label: "ID" },
  { key: "FullName", label: "Name" },
  { key: "Phone", label: "Phone" },
  { key: "Email", label: "Email" },
  { key: "City", label: "City" },
  { key: "Balance", label: "Owes ($)", format: money },
];

export default function Customers() {
  const [search, setSearch] = useState("");
  const [rows, setRows] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null); // null while adding a new customer
  const [message, setMessage] = useState(null);

  async function load() {
    try {
      setRows(await api("/customers?search=" + encodeURIComponent(search)));
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  useEffect(() => {
    load();
  }, []);

  function onSearch(event) {
    event.preventDefault(); // stop the browser from reloading the page
    setMessage(null);
    load();
  }

  function change(event) {
    setForm({ ...form, [event.target.name]: event.target.value });
  }

  async function save(event) {
    event.preventDefault();
    try {
      if (editingId) {
        await api("/customers/" + editingId, "PUT", form);
        setMessage({ text: "Customer " + editingId + " updated." });
      } else {
        const result = await api("/customers", "POST", form);
        setMessage({ text: "Customer " + result.CustomerID + " added." });
      }
      setForm(emptyForm);
      setEditingId(null);
      load();
    } catch (error) {
      setMessage({ error: true, text: error.message });
    }
  }

  function startEdit(row) {
    setEditingId(row.CustomerID);
    setForm({
      FullName: row.FullName,
      Phone: row.Phone,
      Email: row.Email || "",
      City: row.City,
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
        <h2>{editingId ? "Edit customer " + editingId : "Add a customer"}</h2>
        <form onSubmit={save}>
          <label>
            Full name
            <input name="FullName" value={form.FullName} onChange={change} required maxLength={100} />
          </label>
          <label>
            Phone
            <input name="Phone" value={form.Phone} onChange={change} required maxLength={20} />
          </label>
          <label>
            Email
            <input name="Email" type="email" value={form.Email} onChange={change} maxLength={100} />
          </label>
          <label>
            City
            <input name="City" value={form.City} onChange={change} required maxLength={50} />
          </label>
          <button type="submit">{editingId ? "Save" : "Add"}</button>
          {editingId && (
            <button type="button" className="light" onClick={cancelEdit}>
              Cancel
            </button>
          )}
        </form>
      </section>

      <section>
        <h2>Customers</h2>
        <form onSubmit={onSearch}>
          <label>
            Search by name or phone
            <input value={search} onChange={(event) => setSearch(event.target.value)} />
          </label>
          <button type="submit">Search</button>
        </form>
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
