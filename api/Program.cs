using IspApi;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

// Controllers = the classes in the Controllers folder (one per screen).
builder.Services.AddControllers();

// One shared Db object (our ADO.NET helper) given to every controller.
builder.Services.AddSingleton<Db>();

// CORS: the React page (localhost:3000) is allowed to call this API (localhost:5000).
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
        policy.WithOrigins("http://localhost:3000").AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

app.UseCors();

// One place that turns SQL Server errors into a clean JSON answer.
// Every request passes through here; if the database raised an error
// we catch it and reply { "error": "..." } instead of crashing.
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
        int statusCode = 400;                       // 400 = the request was wrong

        if (ex.Number >= 50000)                     // our own THROW 5xxxx in the procedures
            message = ex.Message;
        else if (ex.Number == 2601 || ex.Number == 2627)   // UNIQUE index / constraint
            message = "This value already exists (duplicate).";
        else if (ex.Number == 547)                  // CHECK or FOREIGN KEY constraint
            message = "The value breaks a rule of the database (constraint).";
        else
        {
            message = "Database error.";            // never show internal details to the user
            statusCode = 500;                       // 500 = the server has a problem
        }

        context.Response.StatusCode = statusCode;
        await context.Response.WriteAsJsonAsync(new { error = message });
    }
});

app.MapControllers();

app.Run();
