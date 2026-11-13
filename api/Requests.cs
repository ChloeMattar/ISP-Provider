namespace IspApi;

// The JSON bodies the React app sends. One small class per form.
// The names are the same as the SQL parameters to keep things easy to follow.

public record CustomerRequest(string FullName, string Phone, string? Email, string City, string? Status);

public record PlanRequest(string PlanName, int SpeedMbps, int QuotaGB,
                          decimal MonthlyPrice, decimal OveragePricePerGB, bool IsActive);

public record ActivateRequest(int CustomerID, int PlanID);

public record ChangePlanRequest(int NewPlanID);

public record StatusRequest(string NewStatus);

public record GenerateInvoicesRequest(int Year, int Month);

public record PaymentRequest(decimal Amount, string Method);

public record UsageRequest(int SubscriptionID, DateTime UsageDate, int DownloadMB, int UploadMB);
