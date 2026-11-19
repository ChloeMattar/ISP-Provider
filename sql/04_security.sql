-- ISP Management System - the application's login (least privilege).
--
-- The app doesn't connect as sa or as a Windows account. It uses isp_app,
-- which can only EXECUTE our procedures and functions. It can't SELECT,
-- INSERT, UPDATE or DELETE on any table directly.
--
-- The procedures can still read and write the tables because of ownership
-- chaining: they belong to the same owner (dbo) as the tables, so SQL Server
-- only checks the EXECUTE permission.
--
-- So even if someone gets hold of this login, all they can do is call our
-- procedures - no SELECT * FROM Customers, no DROP TABLE.
--
-- Change the password below before running. The app gets it through
-- "dotnet user-secrets" (see README.md), never from the code.

USE master;
GO
CREATE LOGIN isp_app WITH PASSWORD = 'Replace_This_Passw0rd!';   -- change this
GO

USE ISPManagement;
GO
-- the login gets isp_app into the server, the user gets it into this database
CREATE USER isp_app FOR LOGIN isp_app;
GO
GRANT EXECUTE ON SCHEMA::dbo TO isp_app;
GO
