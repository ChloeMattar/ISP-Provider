/* =====================================================================
   06_security.sql : least privilege

   The application does NOT connect as sa or as your Windows account.
   It connects as isp_app, a login that can do one thing only:
   EXECUTE the procedures and functions of the dbo schema.
   It has no SELECT / INSERT / UPDATE / DELETE permission on any table.

   Why can the procedures still read the tables? "Ownership chaining":
   the procedures and the tables have the same owner (dbo), so SQL Server
   only checks the EXECUTE permission on the procedure.

   Result: even if an attacker steals this login, they cannot run
   SELECT * FROM Customers or DROP TABLE: only our procedures.

   BEFORE RUNNING: replace the password below with your own.
   The real password is then given to the app with "dotnet user-secrets"
   (see README.md), never written in the C# code or in appsettings.json.
   ===================================================================== */
USE master;
GO
CREATE LOGIN isp_app WITH PASSWORD = 'Replace_This_Passw0rd!';   -- <-- change it
GO

USE ISPManagement;
GO
-- The login lets isp_app enter the server; the user lets it enter this database.
CREATE USER isp_app FOR LOGIN isp_app;
GO
-- The only permission it gets.
GRANT EXECUTE ON SCHEMA::dbo TO isp_app;
GO
