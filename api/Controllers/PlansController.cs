using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace IspApi.Controllers;

[ApiController]
[Route("api/plans")]
public class PlansController : ControllerBase
{
    private readonly Db _db;

    public PlansController(Db db)
    {
        _db = db;
    }

    // GET /api/plans
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetPlans");
        return Ok(rows);
    }

    // POST /api/plans
    [HttpPost]
    public async Task<IActionResult> Add(PlanRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_AddPlan",
            Db.Param("@PlanName", SqlDbType.NVarChar, request.PlanName),
            Db.Param("@SpeedMbps", SqlDbType.Int, request.SpeedMbps),
            Db.Param("@QuotaGB", SqlDbType.Int, request.QuotaGB),
            Db.Param("@MonthlyPrice", SqlDbType.Decimal, request.MonthlyPrice),
            Db.Param("@OveragePricePerGB", SqlDbType.Decimal, request.OveragePricePerGB));

        return Ok(rows[0]);
    }

    // PUT /api/plans/3
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, PlanRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_UpdatePlan",
            Db.Param("@PlanID", SqlDbType.Int, id),
            Db.Param("@PlanName", SqlDbType.NVarChar, request.PlanName),
            Db.Param("@SpeedMbps", SqlDbType.Int, request.SpeedMbps),
            Db.Param("@QuotaGB", SqlDbType.Int, request.QuotaGB),
            Db.Param("@MonthlyPrice", SqlDbType.Decimal, request.MonthlyPrice),
            Db.Param("@OveragePricePerGB", SqlDbType.Decimal, request.OveragePricePerGB),
            Db.Param("@IsActive", SqlDbType.Bit, request.IsActive));

        return Ok(rows[0]);
    }
}
