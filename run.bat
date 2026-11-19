@echo off
rem Starts the app: the API on http://localhost:5000 and the React page on
rem http://localhost:3000, each in its own window, then opens the browser.
rem
rem First time only (see README.md): run the SQL scripts and the
rem "dotnet user-secrets set ..." command. Close the two windows to stop.

rem %~dp0 is this file's folder, so it works from anywhere
start "ISP API" /D "%~dp0api" cmd /k dotnet run

rem install the packages first if node_modules isn't there yet
start "ISP Web" /D "%~dp0web" cmd /k "(if not exist node_modules call npm install) & call npm start"

rem give both a few seconds to start
timeout /t 10 /nobreak >nul
start "" http://localhost:3000
