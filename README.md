# ISP Management System (GIN401 Lab Project)

A database application for an Internet Service Provider: customers, internet plans,
subscriptions, monthly billing with overage charges, payments and daily usage tracking.

```
React (localhost:3000)  ->  C# Web API with ADO.NET (localhost:5000)  ->  SQL Server (ISPManagement)
```

The browser never talks to the database. The API only calls stored procedures, with parameters.

## The files

**Database: 6 scripts, run in this order**

| File | Content |
|---|---|
| `sql/01_tables.sql` | The database, the 7 tables, keys and constraints |
| `sql/02_logic.sql` | Part 1: 2 functions. Part 2: 14 procedures. Part 3: 2 triggers |
| `sql/03_data.sql` | Test data: 1,000 customers, about 360,000 usage rows, invoices, payments |
| `sql/04_security.sql` | The least-privilege login used by the application |
| `sql/05_performance.sql` | Indexes on the large table, with before / after queries |
| `sql/06_tests.sql` | Tests that print PASS / FAIL, and the two-users test |

**API: 3 C# files**

| File | Content |
|---|---|
| `api/Program.cs` | Starts the server, allows the React page (CORS), turns SQL errors into JSON |
| `api/Db.cs` | The only ADO.NET code: connection, command, parameters, reader |
| `api/IspController.cs` | Every URL of the API; each one calls one stored procedure |

`IspApi.csproj`, `appsettings.json` and `Properties/launchSettings.json` are project settings (package, port 5000), not logic.

**Frontend: 7 React files**

| File | Content |
|---|---|
| `web/src/main.jsx` | Starts React |
| `web/src/App.jsx` | The five tabs |
| `web/src/shared.jsx` | `api()` (the call to the Web API), the table and the message box used by every page |
| `web/src/pages/*.jsx` | One file per tab: Customers, Plans, Subscriptions, Billing, Usage |

## Where is what

**From a button to the database**

| Screen and action | Page (`web/src/pages`) | URL | Method in `IspController.cs` | Procedure in `02_logic.sql` |
|---|---|---|---|---|
| Customers: search | `Customers.jsx` | `GET /api/customers` | `SearchCustomers` | `usp_SearchCustomers` |
| Customers: add | `Customers.jsx` | `POST /api/customers` | `AddCustomer` | `usp_AddCustomer` |
| Customers: edit | `Customers.jsx` | `PUT /api/customers/{id}` | `UpdateCustomer` | `usp_UpdateCustomer` |
| Plans: list | `Plans.jsx` | `GET /api/plans` | `GetPlans` | `usp_GetPlans` |
| Subscriptions: list / filter | `Subscriptions.jsx` | `GET /api/subscriptions` | `GetSubscriptions` | `usp_GetSubscriptions` |
| Subscriptions: activate | `Subscriptions.jsx` | `POST /api/subscriptions` | `ActivateSubscription` | `usp_ActivateSubscription` |
| Subscriptions: cancel | `Subscriptions.jsx` | `PUT /api/subscriptions/{id}/cancel` | `CancelSubscription` | `usp_CancelSubscription` |
| Billing: list invoices | `Billing.jsx` | `GET /api/invoices` | `GetInvoices` | `usp_GetInvoices` |
| Billing: generate a month | `Billing.jsx` | `POST /api/invoices/generate` | `GenerateInvoices` | `usp_GenerateMonthlyInvoices` |
| Billing: payments of an invoice | `Billing.jsx` | `GET /api/invoices/{id}/payments` | `GetPayments` | `usp_GetPayments` |
| Billing: record a payment | `Billing.jsx` | `POST /api/invoices/{id}/payments` | `RecordPayment` | `usp_RecordPayment` |
| Usage: one subscription, one month | `Usage.jsx` | `GET /api/usage/monthly/{id}` | `GetMonthlyUsage` | `usp_GetMonthlyUsage` |
| Usage: daily detail of that month | `Usage.jsx` | `GET /api/usage/daily/{id}` | `GetDailyUsage` | `usp_GetDailyUsage` |
| Usage: report between two dates | `Usage.jsx` | `GET /api/usage/report` | `GetUsageReport` | `usp_GetUsageReport` |

**Each grading requirement**

| Requirement | Where |
|---|---|
| Tables, keys, constraints | `01_tables.sql` |
| Table above 100,000 rows | `UsageRecords`, filled in `03_data.sql` section 4 |
| Functions | `02_logic.sql` part 1: `fn_OverageCharge`, `fn_CustomerBalance` |
| Procedures | `02_logic.sql` part 2 |
| Triggers | `02_logic.sql` part 3: `trg_Subscriptions_Audit`, `trg_Payments_Protect` |
| Transactions with TRY...CATCH | `02_logic.sql`: `usp_RecordPayment`, `usp_GenerateMonthlyInvoices` |
| Two users at once | the `WITH (UPDLOCK)` line in `usp_RecordPayment`; demonstrated by test 10 in `06_tests.sql` |
| Indexes and execution plans | `05_performance.sql` |
| Least privilege | `04_security.sql` (login `isp_app`, `GRANT EXECUTE` only) |
| No password in the code | `Db.cs` constructor reads the connection string from user secrets |
| Parameters (no SQL injection) | `Db.Param` in `Db.cs`, used by every method of `IspController.cs` |
| ADO.NET | `Db.cs`, method `RunProcedureAsync` |
| Error messages shown to the user | `THROW` in the procedures, then the `catch (SqlException)` block in `Program.cs`, then `Message` in `shared.jsx` |

## Requirements

- SQL Server 2017 or newer (Express or Developer edition is fine) and SSMS
- .NET SDK 8 or newer (`dotnet --version`)
- Node.js 18 or newer (`node --version`)

## How to run

### 1. Database (SSMS)

Open each script in SSMS and press F5, **in this order**:

1. `01_tables.sql`
2. `02_logic.sql`
3. `03_data.sql` (takes less than a minute; the last grid shows the row counts)
4. `04_security.sql` (first replace `Replace_This_Passw0rd!` with your own password)
5. `05_performance.sql` (for the report, run it block by block: see the instructions at its top)
6. `06_tests.sql` (optional: every line of the Messages tab should say PASS)

To start again from zero: `USE master; DROP DATABASE ISPManagement; DROP LOGIN isp_app;` then run the scripts again.

### 2. API (terminal)

```
cd api
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost;Database=ISPManagement;User Id=isp_app;Password=YOUR_PASSWORD;TrustServerCertificate=True"
dotnet run
```

- Replace `YOUR_PASSWORD` with the password you chose in `04_security.sql`.
- If your SQL Server is a named instance, replace `localhost` with its name, for example `localhost\SQLEXPRESS`
  (it is the "Server name" you type in the SSMS connect dialog).
- The `user-secrets` command is needed only once. It stores the connection string in your Windows
  user profile, outside the project folder, so the password is never in the code or in git.

Check: open http://localhost:5000/api/plans in the browser. You should see the 6 plans as JSON.

### Shortcut: `run.bat`

Once the database exists and the `dotnet user-secrets set` command above has been run once,
you can double-click `run.bat` instead of doing steps 2 and 3 by hand: it starts the API and the
React page in two windows and opens http://localhost:3000.

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
| Port 5000 or 3000 already used | Close the other program, or change the port in `api/Properties/launchSettings.json` / `web/vite.config.js` (and the two matching addresses in `api/Program.cs` and `web/src/shared.jsx`). |
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
| Every status change is logged | trigger `trg_Subscriptions_Audit` |
| Customers, plans and subscriptions with history are never deleted | foreign keys (no cascade); subscriptions use `Cancelled` |
| A cancelled subscription is final | `usp_CancelSubscription` (the `AND Status = 'Active'` of its UPDATE) |
| A text longer than its column is refused, never silently cut | `usp_AddCustomer`, `usp_UpdateCustomer` (error 50012) |
| `%` and `_` in a search box are ordinary characters | `CHARINDEX` in `usp_SearchCustomers`, `usp_GetSubscriptions` |

## Demo (2 minutes)

1. **Customers**: search `khoury`, then type `x' OR 1=1 --` in the search box: no rows, the input is treated as data.
2. **Subscriptions**: cancel a subscription, then show the new row in `SubscriptionAudit` (trigger).
3. **Billing**: generate October 2026 (about 960 invoices created from the usage table);
   click Generate again: 0 created. Pay an invoice; try to pay more than the balance: refused.
4. **Usage**: subscription 509, September 2026: totals against the quota (red when over), its invoice, the daily detail; then the usage report for a date range.
5. **Two users at once**: test 10 of `06_tests.sql`, in two SSMS windows.

## AI usage

Claude (Anthropic) was used to help design the schema and to write and explain the SQL scripts,
the C# API and the React pages. Describe here, in your own words, what you used it for and what you changed.
