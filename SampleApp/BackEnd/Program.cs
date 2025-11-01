using Microsoft.AspNetCore.OpenApi;
using Polly;
using Polly.CircuitBreaker;
using Scalar.AspNetCore;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// ═══════════════════════════════════════════════════════════════════════════
// PHASE 1: ENTERPRISE OBSERVABILITY & LOGGING
// ═══════════════════════════════════════════════════════════════════════════

// Setup Serilog Structured Logging
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Service", "CardanoRWA.BackEnd")
    .Enrich.WithProperty("Environment", builder.Environment.EnvironmentName)
    .WriteTo.Console(outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

builder.Host.UseSerilog();

// Add services to the container.
builder.Services.AddOpenApi(options =>
{
    // current workaround for port forwarding in codespaces
    // https://github.com/dotnet/aspnetcore/issues/57332
    options.AddDocumentTransformer((document, context, ct) =>
    {
        document.Servers = [];
        // Add API versioning info
        document.Info.Version = "v1.0.0";
        document.Info.Title = "Cardano RWA Platform API";
        document.Info.Description = "Enterprise-grade API for Real-World Asset tokenization on Cardano";
        document.Info.Contact = new() { Name = "Trustiva", Url = new("https://trustiva.io") };
        return Task.CompletedTask;
    });
});

// ═══════════════════════════════════════════════════════════════════════════
// PHASE 1: RESILIENCE PATTERNS (Polly)
// ═══════════════════════════════════════════════════════════════════════════

// Retry Policy: exponential backoff with jitter
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .Or<OperationCanceledException>()
    .OrResult<HttpResponseMessage>(r => !r.IsSuccessStatusCode && (int)r.StatusCode >= 500)
    .WaitAndRetryAsync(
        retryCount: 3,
        sleepDurationProvider: attempt => TimeSpan.FromMilliseconds(
            Math.Pow(2, attempt) * 100 + Random.Shared.Next(0, 100)
        ),
        onRetry: (outcome, duration, retryCount, context) =>
        {
            Log.Warning("Retry attempt {RetryCount} after {@Duration}", retryCount, duration);
        });

// Circuit Breaker Policy: 5 failures → open, 30s reset
var circuitBreakerPolicy = Policy
    .Handle<HttpRequestException>()
    .Or<OperationCanceledException>()
    .OrResult<HttpResponseMessage>(r => !r.IsSuccessStatusCode && (int)r.StatusCode >= 500)
    .CircuitBreakerAsync<HttpResponseMessage>(5, TimeSpan.FromSeconds(30),
        onBreak: (outcome, duration) =>
        {
            Log.Warning("Circuit breaker opened for {@Duration}", duration);
        },
        onReset: () =>
        {
            Log.Information("Circuit breaker reset");
        });

// Timeout Policy: 15 seconds
var timeoutPolicy = Policy.TimeoutAsync<HttpResponseMessage>(TimeSpan.FromSeconds(15));

// Combined Policy Wrap
var httpClientPolicy = Policy.WrapAsync(retryPolicy, circuitBreakerPolicy, timeoutPolicy);

builder.Services.AddHttpClient("ResilientClient")
    .ConfigureHttpClient(client =>
    {
        client.Timeout = TimeSpan.FromSeconds(20);
    })
    .AddPolicyHandler(httpClientPolicy);

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

app.MapGet("/weatherforecast", () =>
{
    var forecast = Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast");

app.Run();

// Make Program class accessible for testing
public partial class Program { }

internal record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
