using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace IspApi.Controllers;

[ApiController]
[Route("api/usage")]
public class UsageController : ControllerBase
{
    private readonly Db _db;

    public UsageController(Db db)
    {
        _db = db;
    }

    // GET /api/usage/summary/509         month by month totals of subscription 509
    [HttpGet("summary/{subscriptionId}")]
    public async Task<IActionResult> Summary(int subscriptionId)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetUsageSummary",
            Db.Param("@SubscriptionID", SqlDbType.Int, subscriptionId));

        return Ok(rows);
    }

    // GET /api/usage/daily/509?from=2026-03-01&to=2026-03-31
    [HttpGet("daily/{subscriptionId}")]
    public async Task<IActionResult> Daily(int subscriptionId, DateTime from, DateTime to)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetDailyUsage",
            Db.Param("@SubscriptionID", SqlDbType.Int, subscriptionId),
            Db.Param("@FromDate", SqlDbType.Date, from),
            Db.Param("@ToDate", SqlDbType.Date, to));

        return Ok(rows);
    }

    // GET /api/usage/top?year=2026&month=3&top=10
    [HttpGet("top")]
    public async Task<IActionResult> Top(int year, int month, int top = 10)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetTopConsumers",
            Db.Param("@Year", SqlDbType.Int, year),
            Db.Param("@Month", SqlDbType.Int, month),
            Db.Param("@Top", SqlDbType.Int, top));

        return Ok(rows);
    }

    // POST /api/usage                    store one day of usage
    [HttpPost]
    public async Task<IActionResult> Add(UsageRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_AddUsage",
            Db.Param("@SubscriptionID", SqlDbType.Int, request.SubscriptionID),
            Db.Param("@UsageDate", SqlDbType.Date, request.UsageDate),
            Db.Param("@DownloadMB", SqlDbType.Int, request.DownloadMB),
            Db.Param("@UploadMB", SqlDbType.Int, request.UploadMB));

        return Ok(rows[0]);
    }
}
