using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace IspApi.Controllers;

[ApiController]
[Route("api/invoices")]
public class InvoicesController : ControllerBase
{
    private readonly Db _db;

    public InvoicesController(Db db)
    {
        _db = db;
    }

    // GET /api/invoices?onlyUnpaid=true&customerId=12
    [HttpGet]
    public async Task<IActionResult> GetAll(bool onlyUnpaid = true, int? customerId = null)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetInvoices",
            Db.Param("@OnlyUnpaid", SqlDbType.Bit, onlyUnpaid),
            Db.Param("@CustomerID", SqlDbType.Int, customerId));

        return Ok(rows);
    }

    // POST /api/invoices/generate        bill one month for every subscription
    [HttpPost("generate")]
    public async Task<IActionResult> Generate(GenerateInvoicesRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GenerateMonthlyInvoices",
            Db.Param("@Year", SqlDbType.Int, request.Year),
            Db.Param("@Month", SqlDbType.Int, request.Month));

        return Ok(rows[0]);
    }

    // GET /api/invoices/15/payments
    [HttpGet("{id}/payments")]
    public async Task<IActionResult> GetPayments(int id)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetPayments",
            Db.Param("@InvoiceID", SqlDbType.Int, id));

        return Ok(rows);
    }

    // POST /api/invoices/15/payments     record a payment on invoice 15
    [HttpPost("{id}/payments")]
    public async Task<IActionResult> RecordPayment(int id, PaymentRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_RecordPayment",
            Db.Param("@InvoiceID", SqlDbType.Int, id),
            Db.Param("@Amount", SqlDbType.Decimal, request.Amount),
            Db.Param("@Method", SqlDbType.VarChar, request.Method));

        return Ok(rows[0]);
    }
}
