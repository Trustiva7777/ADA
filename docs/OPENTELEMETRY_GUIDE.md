# OpenTelemetry Implementation Guide

## Overview

This guide covers implementing OpenTelemetry (OTel) for distributed tracing, structured logging, and metrics across the Cardano RWA platform.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Frontend    │  │  Backend     │  │  Tokenizer   │     │
│  │  (Blazor)    │  │  (ASP.NET)   │  │  (Node.js)   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└────────────────────┬──────────────────┬────────────────────┘
                     │                  │
        ┌────────────▼──────────────────▼────────┐
        │    OpenTelemetry SDKs                   │
        │  - Tracer (distributed tracing)        │
        │  - Meter (metrics)                      │
        │  - Logger (structured logging)          │
        └────────────────────┬────────────────────┘
                             │
        ┌────────────────────▼────────────────────┐
        │      OTLP Exporter (gRPC/HTTP)          │
        │   Batches telemetry to collector       │
        └────────────────────┬────────────────────┘
                             │
        ┌────────────────────▼────────────────────┐
        │   OpenTelemetry Collector               │
        │   - Receives traces/metrics/logs        │
        │   - Processes (sampling, filtering)     │
        │   - Exports to backends                 │
        └───┬─────────┬──────────────┬───────────┘
            │         │              │
    ┌───────▼──┐ ┌───▼───────┐ ┌──▼──────────┐
    │  Jaeger   │ │ Prometheus│ │ Loki        │
    │ (Tracing) │ │ (Metrics) │ │ (Logs)      │
    └───────────┘ └───────────┘ └─────────────┘
            │         │              │
            └─────────┼──────────────┘
                      │
            ┌─────────▼──────────┐
            │   Grafana          │
            │  (Dashboards)      │
            └────────────────────┘
```

## Phase 1: Setup & Instrumentation

### 1.1 Backend (.NET/ASP.NET Core)

#### Step 1: Install NuGet Packages

```bash
cd SampleApp/BackEnd
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Exporter.Jaeger
dotnet add package OpenTelemetry.Exporter.Prometheus
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Instrumentation.SqlClient
```

#### Step 2: Update `Program.cs`

```csharp
using OpenTelemetry;
using OpenTelemetry.Exporter;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;

var builder = WebApplicationBuilder.CreateBuilder(args);

// Define resource (service identity)
var resource = ResourceBuilder
    .CreateDefault()
    .AddService("cardano-rwa-backend", serviceVersion: "1.0.0")
    .AddAttributes(new Dictionary<string, object>
    {
        { "environment", builder.Environment.EnvironmentName },
        { "host.name", Environment.MachineName }
    });

// Add Tracing
builder.Services
    .AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing
            .SetResourceBuilder(resource)
            .AddAspNetCoreInstrumentation(options =>
            {
                options.Filter = context => !context.Request.Path.StartsWith("/health");
            })
            .AddHttpClientInstrumentation(options =>
            {
                options.Filter = context => !context.Request.RequestUri.ToString().Contains("prometheus");
            })
            .AddSqlClientInstrumentation(options =>
            {
                options.RecordException = true;
                options.SetDbStatementForStoredProcedure = true;
            })
            .AddJaegerExporter(options =>
            {
                options.AgentHost = builder.Configuration["Jaeger:Host"] ?? "localhost";
                options.AgentPort = int.Parse(builder.Configuration["Jaeger:Port"] ?? "6831");
            });
    })
    .WithMetrics(metrics =>
    {
        metrics
            .SetResourceBuilder(resource)
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation()
            .AddProcessInstrumentation()
            .AddPrometheusExporter(options =>
            {
                options.Port = int.Parse(builder.Configuration["Prometheus:Port"] ?? "9090");
            });
    });

// Add Logging
builder.Logging.ClearProviders();
builder.Logging.AddOpenTelemetry(logging =>
{
    logging
        .SetResourceBuilder(resource)
        .AddConsoleExporter();
    // TODO: Add OTLP exporter for centralized logging
});

// Add application services
builder.Services.AddControllers();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Map Prometheus metrics endpoint
app.MapPrometheusScrapingEndpoint();

// Standard middleware
app.UseSwagger();
app.UseSwaggerUI();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

#### Step 3: Update `appsettings.json`

```json
{
  "OpenTelemetry": {
    "Jaeger": {
      "Host": "localhost",
      "Port": 6831
    },
    "Prometheus": {
      "Port": 9090
    }
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
    }
  }
}
```

### 1.2 Frontend (Node.js Tokenizer)

#### Step 1: Install Dependencies

```bash
cd SampleApp/BackEnd  # Assuming tokenizer code here
npm install @opentelemetry/api
npm install @opentelemetry/sdk-node
npm install @opentelemetry/auto
npm install @opentelemetry/exporter-jaeger
npm install @opentelemetry/exporter-prometheus
npm install @opentelemetry/sdk-trace-node
npm install @opentelemetry/sdk-metrics
npm install @opentelemetry/resources
npm install @opentelemetry/semantic-conventions
```

#### Step 2: Create `tracing.js`

```javascript
// File: SampleApp/BackEnd/tracing.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');
const { registerInstrumentations } = require('@opentelemetry/core-decorators');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const jaegerExporter = new JaegerExporter({
  serviceName: 'cardano-rwa-tokenizer',
  host: process.env.JAEGER_HOST || 'localhost',
  port: parseInt(process.env.JAEGER_PORT || '6831'),
});

const prometheusExporter = new PrometheusExporter(
  {
    port: parseInt(process.env.PROMETHEUS_PORT || '9091'),
  },
  () => {
    console.log('Prometheus server running on port 9091');
  }
);

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'cardano-rwa-tokenizer',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
  }),
  traceExporter: jaegerExporter,
  metricExporter: prometheusExporter,
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
console.log('OpenTelemetry initialized');

process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => {
      console.log('OpenTelemetry shutdown complete');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Error during shutdown', error);
      process.exit(1);
    });
});

module.exports = sdk;
```

#### Step 3: Update Entry Point (e.g., `index.js`)

```javascript
// MUST be first import
require('./tracing.js');

// ... rest of application code
```

### 1.3 OpenTelemetry Collector Configuration

Create `docker-compose.otel.yml`:

```yaml
version: '3.8'

services:
  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: otel-collector
    command: ["--config=/etc/otel-collector-config.yml"]
    volumes:
      - ./config/otel-collector-config.yml:/etc/otel-collector-config.yml
    ports:
      - "4317:4317"   # OTLP gRPC receiver
      - "4318:4318"   # OTLP HTTP receiver
      - "9411:9411"   # Zipkin receiver
      - "14250:14250" # Jaeger gRPC receiver
    environment:
      - GOGC=80
    depends_on:
      - jaeger
      - prometheus

  # Jaeger for Tracing
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    ports:
      - "6831:6831/udp" # Jaeger agent
      - "16686:16686"   # Jaeger UI
    environment:
      - COLLECTOR_ZIPKIN_HTTP_PORT=9411

  # Prometheus for Metrics
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  # Loki for Logs (optional)
  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./config/loki-config.yml:/etc/loki/local-config.yml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yml

  # Grafana for Dashboards
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana-provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
      - loki

volumes:
  prometheus_data:
  loki_data:
  grafana_data:
```

Create `config/otel-collector-config.yml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
  prometheus:
    endpoint: "0.0.0.0:8888"
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [jaeger, logging]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus, logging]
```

## Phase 2: Instrumentation Best Practices

### 2.1 Structured Logging

**C# Example:**

```csharp
using System.Diagnostics;

public class TokenizationService
{
    private readonly ILogger<TokenizationService> _logger;
    private readonly ActivitySource _activitySource;

    public TokenizationService(ILogger<TokenizationService> logger)
    {
        _logger = logger;
        _activitySource = new ActivitySource("TokenizationService");
    }

    public async Task<string> MintTokenAsync(RealWorldAsset asset)
    {
        using var activity = _activitySource.StartActivity("MintToken");
        activity?.SetTag("asset.id", asset.Id);
        activity?.SetTag("asset.type", asset.Type);

        try
        {
            _logger.LogInformation(
                "Starting mint process for asset {AssetId} of type {AssetType}",
                asset.Id, asset.Type);

            // Actual minting logic...
            var txId = await MintOnCardanoAsync(asset);

            _logger.LogInformation(
                "Successfully minted token {TokenId} for asset {AssetId}",
                txId, asset.Id);

            return txId;
        }
        catch (Exception ex)
        {
            activity?.SetTag("error", true);
            activity?.SetTag("error.type", ex.GetType().Name);
            
            _logger.LogError(ex,
                "Failed to mint token for asset {AssetId}: {ErrorMessage}",
                asset.Id, ex.Message);

            throw;
        }
    }
}
```

### 2.2 Custom Metrics

**C# Example:**

```csharp
public class ComplianceService
{
    private readonly Meter _meter;
    private readonly Counter<int> _screensCounter;
    private readonly Histogram<double> _screenDurationMs;

    public ComplianceService()
    {
        _meter = new Meter("ComplianceService", "1.0.0");
        _screensCounter = _meter.CreateCounter<int>(
            "compliance.sanctions_screens.total",
            description: "Total number of sanctions screening checks");
        
        _screenDurationMs = _meter.CreateHistogram<double>(
            "compliance.sanctions_screens.duration_ms",
            description: "Duration of sanctions screening in milliseconds");
    }

    public async Task<bool> ScreenAgainstSanctionsAsync(string entityName)
    {
        var startTime = Environment.TickCount64;

        try
        {
            var result = await PerformScreeningAsync(entityName);
            _screensCounter.Add(1, new("result", result ? "pass" : "fail"));
            return result;
        }
        finally
        {
            var duration = Environment.TickCount64 - startTime;
            _screenDurationMs.Record(duration);
        }
    }
}
```

### 2.3 Span Context Propagation

**Between .NET and Node.js services:**

```csharp
// C# - Propagate trace ID to Node.js service
using var client = new HttpClient();
var propagator = new W3CTraceContextPropagator();
var activityContext = Activity.Current?.Context ?? default;
var contextToPropagate = new ActivityContext(
    activityContext.TraceId,
    activityContext.SpanId,
    activityContext.TraceFlags);

using var request = new HttpRequestMessage(
    HttpMethod.Post,
    "http://localhost:3001/tokenize");

propagator.Inject(contextToPropagate, request, InjectTraceContext);

static void InjectTraceContext(HttpRequestMessage req, string key, string value)
{
    req.Headers.Add(key, value);
}

var response = await client.SendAsync(request);
```

## Phase 3: Dashboards & Alerting

### 3.1 SLO/SLI Definition

```yaml
# config/slo-definitions.yml
slos:
  - name: "API Availability"
    objective: 0.999  # 99.9%
    window: 30d
    indicators:
      - metric: up{job="backend"}
        threshold: 1
    alert_threshold: 0.98  # Alert if drops below 98%

  - name: "Mint TX Latency"
    objective: 0.95  # 95% of requests < 2s
    window: 30d
    indicators:
      - metric: histogram_quantile(0.95, mint_duration_seconds_bucket)
        threshold: 2
    alert_threshold: 3  # Alert if p95 > 3s

  - name: "Compliance Check Success"
    objective: 0.99  # 99% of checks pass
    window: 30d
    indicators:
      - metric: rate(compliance_screens_total{result="pass"}[5m])
        threshold: 0.99
    alert_threshold: 0.95
```

### 3.2 Grafana Dashboard

Grafana dashboards are defined in `/config/grafana-provisioning/dashboards/cardano-rwa-dashboard.json`

**Key panels:**
- Request rate (by endpoint)
- Latency percentiles (p50, p95, p99)
- Error rates
- Mint TX success rate
- Circuit breaker state
- Database connection pool
- Memory/CPU utilization

## Phase 4: Alerting Rules

Create `config/prometheus-rules.yml`:

```yaml
groups:
  - name: cardano_rwa_alerts
    interval: 15s
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "High error rate (> 5%)"
          description: "{{ $value }}% of requests are errors"

      - alert: SlowMintTx
        expr: histogram_quantile(0.95, rate(mint_duration_seconds_bucket[5m])) > 3
        for: 10m
        annotations:
          summary: "Mint transactions slow (p95 > 3s)"
          description: "p95 latency: {{ $value }}s"

      - alert: ComplianceFailed
        expr: rate(compliance_screens_total{result="fail"}[5m]) > 0.01
        for: 5m
        annotations:
          summary: "High compliance failure rate (> 1%)"
          description: "{{ $value }}% of screens failing"

      - alert: JaegerDown
        expr: up{job="jaeger"} == 0
        for: 1m
        annotations:
          summary: "Jaeger exporter is down"

      - alert: DatabaseConnectionPoolExhausted
        expr: db_connections_active / db_connections_max > 0.9
        for: 5m
        annotations:
          summary: "Database connection pool > 90% utilization"
          description: "{{ $value }}% full"
```

## Phase 5: Deployment to Production

### 5.1 Add to Docker Compose

```bash
docker-compose -f docker-compose.yml -f docker-compose.otel.yml up -d
```

### 5.2 Verify Telemetry

```bash
# Check Jaeger UI
curl http://localhost:16686

# Check Prometheus
curl http://localhost:9090/api/v1/query?query=up

# Check Grafana
curl http://localhost:3000
```

## Maintenance & Operations

### Weekly Tasks
- Review alert firing patterns
- Check sampled traces for errors
- Monitor collector performance (memory/CPU)

### Monthly Tasks
- Rotate Jaeger data retention
- Tune sampling rates if needed
- Review SLO compliance

### Quarterly Tasks
- Update OTel SDK versions
- Review and optimize dashboard
- Audit tracing overhead

---

## Success Criteria (for Gap #1 closure)

✅ Distributed tracing in place (Jaeger)  
✅ Structured logging configured  
✅ Prometheus metrics exported  
✅ SLO/SLI definitions created  
✅ Critical alerts firing correctly  
✅ Grafana dashboards visible  
✅ < 5% performance overhead  
✅ Team trained on telemetry interpretation  

