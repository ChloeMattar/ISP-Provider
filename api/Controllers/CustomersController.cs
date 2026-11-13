using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace IspApi.Controllers;

[ApiController]
[Route("api/customers")]
public class CustomersController : ControllerBase
{
    private readonly Db _db;

    public CustomersController(Db db)
    {
        _db = db;
    }

    // GET /api/customers?search=khoury
    [HttpGet]
    public async Task<IActionResult> Search(string? search)
    {
        // Empty search box = send NULL = the procedure lists everybody
        string? value = string.IsNullOrWhiteSpace(search) ? null : search.Trim();

        var rows = await _db.RunProcedureAsync("dbo.usp_SearchCustomers",
            Db.Param("@Search", SqlDbType.NVarChar, value));

        return Ok(rows);
    }

    // POST /api/customers
    [HttpPost]
    public async Task<IActionResult> Add(CustomerRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_AddCustomer",
            Db.Param("@FullName", SqlDbType.NVarChar, request.FullName),
            Db.Param("@Phone", SqlDbType.VarChar, request.Phone),
            Db.Param("@Email", SqlDbType.VarChar, string.IsNullOrWhiteSpace(request.Email) ? null : request.Email),
            Db.Param("@City", SqlDbType.NVarChar, request.City));

        return Ok(rows[0]);
    }

    // PUT /api/customers/5
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, CustomerRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_UpdateCustomer",
            Db.Param("@CustomerID", SqlDbType.Int, id),
            Db.Param("@FullName", SqlDbType.NVarChar, request.FullName),
            Db.Param("@Phone", SqlDbType.VarChar, request.Phone),
            Db.Param("@Email", SqlDbType.VarChar, string.IsNullOrWhiteSpace(request.Email) ? null : request.Email),
            Db.Param("@City", SqlDbType.NVarChar, request.City),
            Db.Param("@Status", SqlDbType.VarChar, request.Status ?? "Active"));

        return Ok(rows[0]);
    }
}
