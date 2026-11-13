using System.Data;
using Microsoft.AspNetCore.Mvc;

namespace IspApi.Controllers;

[ApiController]
[Route("api/subscriptions")]
public class SubscriptionsController : ControllerBase
{
    private readonly Db _db;

    public SubscriptionsController(Db db)
    {
        _db = db;
    }

    // GET /api/subscriptions?customerId=12&status=Active   (both filters optional)
    [HttpGet]
    public async Task<IActionResult> GetAll(int? customerId, string? status)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_GetSubscriptions",
            Db.Param("@CustomerID", SqlDbType.Int, customerId),
            Db.Param("@Status", SqlDbType.VarChar, string.IsNullOrWhiteSpace(status) ? null : status));

        return Ok(rows);
    }

    // POST /api/subscriptions            start a new subscription
    [HttpPost]
    public async Task<IActionResult> Activate(ActivateRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_ActivateSubscription",
            Db.Param("@CustomerID", SqlDbType.Int, request.CustomerID),
            Db.Param("@PlanID", SqlDbType.Int, request.PlanID));

        return Ok(rows[0]);
    }

    // PUT /api/subscriptions/7/plan      move to another plan
    [HttpPut("{id}/plan")]
    public async Task<IActionResult> ChangePlan(int id, ChangePlanRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_ChangePlan",
            Db.Param("@SubscriptionID", SqlDbType.Int, id),
            Db.Param("@NewPlanID", SqlDbType.Int, request.NewPlanID));

        return Ok(rows[0]);
    }

    // PUT /api/subscriptions/7/status    suspend, resume or cancel
    [HttpPut("{id}/status")]
    public async Task<IActionResult> SetStatus(int id, StatusRequest request)
    {
        var rows = await _db.RunProcedureAsync("dbo.usp_SetSubscriptionStatus",
            Db.Param("@SubscriptionID", SqlDbType.Int, id),
            Db.Param("@NewStatus", SqlDbType.VarChar, request.NewStatus));

        return Ok(rows[0]);
    }
}
