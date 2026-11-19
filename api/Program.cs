using IspApi;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddSingleton<Db>();

// Let the React app on port 3000 call this API.
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
        policy.WithOrigins("http://localhost:3000").AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

app.UseCors();

// Turns SQL Server errors into a JSON { "error": "..." } reply,
// so the page can show a readable message instead of the request crashing.
app.Use(async (context, next) =>
{
    try
    {
        await next(context);
    }
    catch (SqlException ex)
    {
        Console.WriteLine($"SQL error {ex.Number}: {ex.Message}");

        string message;
        int statusCode = 400;

        if (ex.Number >= 50000)                            // our own THROW in a procedure
            message = ex.Message;
        else if (ex.Number == 2601 || ex.Number == 2627)   // unique index / constraint
            message = "This value already exists (duplicate).";
        else if (ex.Number == 547)                         // CHECK or foreign key
            message = "The value breaks a rule of the database (constraint).";
        else
        {
            // anything else: don't leak database details to the user
            message = "Database error.";
            statusCode = 500;
        }

        context.Response.StatusCode = statusCode;
        await context.Response.WriteAsJsonAsync(new { error = message });
    }
});

app.MapControllers();

app.Run();
