using System.Data;
using Microsoft.Data.SqlClient;

namespace IspApi;

// All the ADO.NET code of the application is in this class.
// The controllers only say WHICH procedure to run and with WHICH parameters.
public class Db
{
    private readonly string _connectionString;

    public Db(IConfiguration configuration)
    {
        // The connection string is NOT in the code and NOT in appsettings.json.
        // It comes from "dotnet user-secrets" (or an environment variable).
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException(
                "Connection string 'DefaultConnection' is missing. See README.md (dotnet user-secrets).");
    }

    // Runs one stored procedure and returns its rows.
    // Each row is a dictionary: column name -> value.
    public async Task<List<Dictionary<string, object?>>> RunProcedureAsync(
        string procedureName, params SqlParameter[] parameters)
    {
        var rows = new List<Dictionary<string, object?>>();

        // 1. SqlConnection = "Connect to Server". 'using' closes it even if an error happens.
        using (SqlConnection connection = new SqlConnection(_connectionString))
        {
            await connection.OpenAsync();

            // 2. SqlCommand = what we ask the server to run.
            //    CommandType.StoredProcedure: the text is a procedure NAME, not SQL text.
            using (SqlCommand command = new SqlCommand(procedureName, connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                // The values travel as parameters, separately from the SQL:
                // they are always treated as data, never as code (no SQL injection).
                command.Parameters.AddRange(parameters);

                // 3. SqlDataReader = the results grid, read one row at a time.
                using (SqlDataReader reader = await command.ExecuteReaderAsync())
                {
                    while (await reader.ReadAsync())
                    {
                        var row = new Dictionary<string, object?>();

                        for (int i = 0; i < reader.FieldCount; i++)
                        {
                            // A SQL NULL becomes a C# null
                            row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                        }

                        rows.Add(row);
                    }
                }
            }
        }

        return rows;
    }

    // Builds one typed parameter, for example Param("@Phone", SqlDbType.VarChar, "70123456").
    // A C# null is sent as a SQL NULL (DBNull.Value).
    public static SqlParameter Param(string name, SqlDbType type, object? value)
    {
        return new SqlParameter(name, type) { Value = value ?? DBNull.Value };
    }
}
