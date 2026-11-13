# ISP Management System (GIN401 Lab Project)

A database application for an Internet Service Provider: customers, internet plans,
subscriptions, monthly billing with overage charges, payments and daily usage tracking.

```
React (localhost:3000)  ->  C# Web API with ADO.NET (localhost:5000)  ->  SQL Server (ISPManagement)
```

The browser never talks to the database. The API only calls stored procedures, with parameters.

## What is in this folder

| Folder | Content |
|---|---|
| `sql/01_create_tables.sql` | Database, 7 tables, keys and constraints |
| `sql/02_functions.sql` | 3 scalar functions (overage charge, monthly usage, customer balance) |
| `sql/03_procedures.sql` | 18 stored procedures, including the two transactions |
| `sql/04_triggers.sql` | Audit trigger on subscriptions, protection trigger on payments |
| `sql/05_insert_data.sql` | Test data: 2,000 customers, about 720,000 usage rows, invoices, payments |
| `sql/06_security.sql` | The least-privilege login used by the application |
| `sql/07_performance.sql` | Indexes on the large table, with before / after queries |
| `sql/08_tests.sql` | Tests that print PASS / FAIL, and the two-users test |
| `api/` | ASP.NET Core Web API (C#, ADO.NET) |
| `web/` | React frontend (Vite) |

## Requirements

- SQL Server 2017 or newer (Express or Developer edition is fine) and SSMS
- .NET SDK 8 or newer (`dotnet --version`)
- Node.js 18 or newer (`node --version`)

## How to run

### 1. Database (SSMS)

Open each script in SSMS and press F5, **in this order**:

1. `01_create_tables.sql`
2. `02_functions.sql`
3. `03_procedures.sql`
4. `04_triggers.sql`
5. `05_insert_data.sql` (takes less than a minute; the last grid shows the row counts)
6. `06_security.sql` (first replace `Replace_This_Passw0rd!` with your own password)
7. `07_performance.sql` (for the report, run it block by block: see the instructions at its top)
8. `08_tests.sql` (optional: every line of the Messages tab should say PASS)

To start again from zero: `USE master; DROP DATABASE ISPManagement; DROP LOGIN isp_app;` then run the scripts again.

### 2. API (terminal)

```
cd api
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost;Database=ISPManagement;User Id=isp_app;Password=YOUR_PASSWORD;TrustServerCertificate=True"
dotnet run
```

- Replace `YOUR_PASSWORD` with the password you chose in `06_security.sql`.
- If your SQL Server is a named instance, replace `localhost` with its name, for example `localhost\SQLEXPRESS`
  (it is the "Server name" you type in the SSMS connect dialog).
- The `user-secrets` command is needed only once. It stores the connection string in your Windows
  user profile, outside the project folder, so the password is never in the code or in git.

Check: open http://localhost:5000/api/plans in the browser. You should see the 6 plans as JSON.

### 3. Frontend (second terminal)

```
cd web
npm install
npm start
```

Open http://localhost:3000.

## If something does not work

| Problem | Fix |
|---|---|
| `Login failed for user 'isp_app'` | SQL Server accepts only Windows logins by default. In SSMS: right-click the server > Properties > Security > "SQL Server and Windows Authentication mode", then restart the SQL Server service. Also check the password in the user-secrets command. |
| The API cannot find the server | Use the exact server name from SSMS in the connection string (for example `localhost\SQLEXPRESS`). |
| `Connection string 'DefaultConnection' is missing` | Run the `dotnet user-secrets set ...` command from inside the `api` folder. |
| Port 5000 or 3000 already used | Close the other program, or change the port in `api/Properties/launchSettings.json` / `web/vite.config.js` (and the two matching addresses in `api/Program.cs` and `web/src/api.js`). |
| The page says "Cannot reach the API" | Start the API first (`dotnet run`) and keep that terminal open. |

## Business rules (and where each one is enforced)

| Rule | Enforced by |
|---|---|
| A phone number belongs to one customer | `UQ_Customers_Phone` |
| Prices, speeds and quotas are positive | `CK_Plans_*` |
| A customer has at most one open subscription | filtered unique index `UX_Subscriptions_OneOpenPerCustomer` |
| One usage row per subscription per day | unique index `UX_UsageRecords_Subscription_Date` |
| One invoice per subscription per month | `UQ_Invoices_Subscription_Period` |
| Invoice = plan price + (GB over quota x overage price) | `usp_GenerateMonthlyInvoices` + `fn_OverageCharge` |
| A month can be billed only when it is finished | `usp_GenerateMonthlyInvoices` |
| Payments never exceed the invoice balance | `usp_RecordPayment` (UPDLOCK) + `CK_Invoices_AmountPaid` |
| Payments are never modified or deleted | trigger `trg_Payments_Protect` |
| Every status / plan change is logged | trigger `trg_Subscriptions_Audit` |
| Customers, plans and subscriptions with history are never deleted | foreign keys (no cascade); plans use `IsActive`, subscriptions use `Cancelled` |
| A cancelled subscription is final | `usp_SetSubscriptionStatus` |

## Demo (2 minutes)

1. **Customers**: search `khoury`, then type `x' OR 1=1 --` in the search box: no rows, the input is treated as data.
2. **Subscriptions**: suspend a subscription, then show the new row in `SubscriptionAudit` (trigger).
3. **Billing**: generate October 2026 (about 1,920 invoices created from the usage table);
   click Generate again: 0 created. Pay an invoice; try to pay more than the balance: refused.
4. **Usage**: subscription 509, monthly totals against the quota (over-quota months are red), top 10 consumers.
5. **Two users at once**: test 10 of `08_tests.sql`, in two SSMS windows.

## Performance results (fill in with your own numbers from `07_performance.sql`)

| Query | Before: operator / logical reads / time | After: operator / logical reads / time |
|---|---|---|
| 1. One subscription, one month | | |
| 2. Totals per subscription for one month | | |
| 3. `YEAR()`/`MONTH()` filter vs date range | | |

## Security summary

- **Parameters**: every value goes to SQL Server as a typed `SqlParameter` of a stored procedure call (`api/Db.cs`). No SQL text is built from user input.
- **Least privilege**: the app connects as `isp_app`, which has only `EXECUTE` on the `dbo` schema and no permission on the tables.
- **No password in the code**: the connection string is in .NET user secrets, outside the repository.

## Version control

```
git init
git add .
git commit -m "ISP Management System"
```

`.gitignore` already excludes `node_modules`, `bin`, `obj` and `dist`.

## AI usage

Claude (Anthropic) was used to help design the schema and to write and explain the SQL scripts,
the C# API and the React pages. Describe here, in your own words, what you used it for and what you changed.
