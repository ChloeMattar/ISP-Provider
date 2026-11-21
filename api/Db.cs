using System.Data;
using Microsoft.Data.SqlClient;

namespace IspApi;

// All the ADO.NET code lives here. The controller just says which
// procedure to run and with which parameters.
public class Db
{
    private readonly string _connectionString;

    public Db(IConfiguration configuration)
    {
        // Comes from "dotnet user-secrets".
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException(
                "Connection string 'DefaultConnection' is missing. See README.md (dotnet user-secrets).");
    }

    // Runs a stored procedure and returns its rows, each one as a
    // column name -> value dictionary.
    public async Task<List<Dictionary<string, object?>>> RunProcedureAsync(
        string procedureName, params SqlParameter[] parameters)
    {
        var rows = new List<Dictionary<string, object?>>();

        // "using" closes the connection even if something throws
        using (SqlConnection connection = new SqlConnection(_connectionString))
        {
            await connection.OpenAsync();

            using (SqlCommand command = new SqlCommand(procedureName, connection))
            {
                command.CommandType = CommandType.StoredProcedure;

                // Values are sent separately from the SQL, so user input is
                // always treated as data and can't inject SQL.
                command.Parameters.AddRange(parameters);

                using (SqlDataReader reader = await command.ExecuteReaderAsync())
                {
                    while (await reader.ReadAsync())
                    {
                        var row = new Dictionary<string, object?>();

                        for (int i = 0; i < reader.FieldCount; i++)
                        {
                            row[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                        }

                        rows.Add(row);
                    }
                }
            }
        }

        return rows;
    }

    // Shortcut for a typed parameter. A C# null becomes SQL NULL.
    public static SqlParameter Param(string name, SqlDbType type, object? value)
    {
        return new SqlParameter(name, type) { Value = value ?? DBNull.Value };
    }
}
