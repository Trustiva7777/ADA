# Resilience Patterns Implementation Guide

## Overview

This guide covers implementing enterprise-grade resilience patterns (circuit breakers, retry strategies, bulkheads, timeouts) for the Cardano RWA platform using industry-standard libraries.

## Architecture

```
┌───────────────────────────────────────────────┐
│           Application Service                  │
└────────────────────┬────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌─────────┐  ┌──────────┐  ┌────────┐
   │ Retry   │  │ Circuit  │  │Timeout │
   │ Policy  │  │ Breaker  │  │ Policy │
   └────┬────┘  └────┬─────┘  └───┬────┘
        │            │            │
        └────────────┼────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌─────────┐  ┌──────────┐  ┌────────────┐
   │Blockfrost│ │ Ogmios  │  │ IPFS Node  │
   │   API    │  │  Node   │  │            │
   └─────────┘  └──────────┘  └────────────┘
```

## Part 1: C# Implementation (ASP.NET Core)

### 1.1 Install Dependencies

```bash
cd SampleApp/BackEnd
dotnet add package Polly
dotnet add package Polly.CircuitBreaker
dotnet add package Polly.Retry
dotnet add package Polly.Timeout
dotnet add package Polly.Bulkhead
dotnet add package Polly.Extensions.Http
```

### 1.2 Define Resilience Policies

Create `Infrastructure/ResiliencePolicies.cs`:

```csharp
using Polly;
using Polly.CircuitBreaker;
using Polly.Retry;
using Polly.Timeout;
using Polly.Bulkhead;
using Polly.Extensions.Http;
using System.Net.Http;

namespace SampleApp.BackEnd.Infrastructure
{
    public static class ResiliencePolicies
    {
        // Circuit Breaker: Stop calling failing endpoint for X seconds
        public static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
        {
            return HttpPolicyExtensions
                .HandleTransientHttpError()
                .CircuitBreakerAsync<HttpResponseMessage>(
                    handledEventsAllowedBeforeBreaking: 5,
                    durationOfBreak: TimeSpan.FromSeconds(30),
                    onBreak: (outcome, timespan) =>
                    {
                        Console.WriteLine($"Circuit breaker opened for {timespan.TotalSeconds}s. " +
                            $"Last error: {outcome.Exception?.Message}");
                    },
                    onReset: () =>
                    {
                        Console.WriteLine("Circuit breaker reset. Attempting requests again.");
                    });
        }

        // Retry: Exponential backoff with jitter
        public static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
        {
            return HttpPolicyExtensions
                .HandleTransientHttpError()
                .Or<HttpRequestException>(x => x.InnerException is TimeoutException)
                .WaitAndRetryAsync<HttpResponseMessage>(
                    retryCount: 3,
                    sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(
                        Math.Pow(2, retryAttempt) +
                        Random.Shared.Next(0, 1000) / 1000.0), // exponential backoff with jitter
                    onRetry: (outcome, timespan, retryCount, context) =>
                    {
                        Console.WriteLine($"Retry {retryCount} after {timespan.TotalSeconds}s. " +
                            $"Reason: {outcome.Exception?.Message}");
                    });
        }

        // Timeout: Cancel if request takes > X seconds
        public static IAsyncPolicy<HttpResponseMessage> GetTimeoutPolicy()
        {
            return Policy.TimeoutAsync<HttpResponseMessage>(
                timeout: TimeSpan.FromSeconds(10),
                timeoutStrategy: TimeoutStrategy.Optimistic, // cancellation token
                onTimeoutAsync: (context, timespan, attempt, ex) =>
                {
                    Console.WriteLine($"Request timed out after {timespan.TotalSeconds}s");
                    return Task.CompletedTask;
                });
        }

        // Bulkhead: Limit concurrent requests to 10
        public static IAsyncPolicy<HttpResponseMessage> GetBulkheadPolicy()
        {
            return Policy.BulkheadAsync<HttpResponseMessage>(
                maxParallelization: 10,
                maxQueuingActions: 20,
                onBulkheadRejectedAsync: context =>
                {
                    Console.WriteLine("Bulkhead rejected - too many concurrent requests");
                    return Task.CompletedTask;
                });
        }

        // Combine all policies (in order: timeout → bulkhead → retry → circuit breaker)
        public static IAsyncPolicy<HttpResponseMessage> GetCombinedPolicy()
        {
            return Policy.WrapAsync<HttpResponseMessage>(
                GetTimeoutPolicy(),
                GetBulkheadPolicy(),
                GetRetryPolicy(),
                GetCircuitBreakerPolicy()
            );
        }
    }
}
```

### 1.3 Register Policies in Dependency Injection

Update `Program.cs`:

```csharp
using SampleApp.BackEnd.Infrastructure;
using Polly;

// Add HTTP clients with resilience policies
builder.Services
    .AddHttpClient("Blockfrost")
    .ConfigureHttpClient(client =>
    {
        client.BaseAddress = new Uri("https://cardano-preprod.blockfrost.io/api/v0");
        client.DefaultRequestHeaders.Add("project_id", 
            builder.Configuration["Blockfrost:ApiKey"]);
    })
    .AddPolicyHandler(ResiliencePolicies.GetCombinedPolicy())
    .AddTransientHttpErrorPolicy(p => p.RetryAsync(1)); // Extra resilience

builder.Services
    .AddHttpClient("Ogmios")
    .ConfigureHttpClient(client =>
    {
        client.BaseAddress = new Uri("http://localhost:1337");
        client.Timeout = TimeSpan.FromSeconds(15);
    })
    .AddPolicyHandler(ResiliencePolicies.GetCombinedPolicy());

builder.Services
    .AddHttpClient("IPFS")
    .ConfigureHttpClient(client =>
    {
        client.BaseAddress = new Uri("http://localhost:5001");
    })
    .AddPolicyHandler(ResiliencePolicies.GetCombinedPolicy());
```

### 1.4 Use in Service

```csharp
using System.Net.Http;

public class BlockchainService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<BlockchainService> _logger;

    public BlockchainService(
        IHttpClientFactory httpClientFactory,
        ILogger<BlockchainService> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<string> GetLatestBlockAsync()
    {
        try
        {
            var client = _httpClientFactory.CreateClient("Blockfrost");
            var response = await client.GetAsync("/blocks/latest");

            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsStringAsync();
        }
        catch (HttpRequestException ex) when (ex.InnerException is TimeoutException)
        {
            _logger.LogError("Blockfrost request timed out");
            throw;
        }
        catch (BrokenCircuitException ex)
        {
            _logger.LogError("Blockfrost circuit breaker open. Service unavailable.");
            // Fallback: use cached data or return error to client
            throw;
        }
        catch (BulkheadRejectedException ex)
        {
            _logger.LogError("Too many concurrent requests to Blockfrost");
            // Fallback: queue for later processing
            throw;
        }
    }
}
```

## Part 2: Node.js Implementation

### 2.1 Install Dependencies

```bash
npm install axios
npm install opossum  # Circuit breaker library
npm install retry-axios
npm install p-retry  # Promise retry utility
```

### 2.2 Resilience Configuration

Create `src/resilience/policies.js`:

```javascript
const axios = require('axios');
const CircuitBreaker = require('opossum');
const pRetry = require('p-retry');

// Custom retry with exponential backoff
const retryWithBackoff = (fn, options = {}) => {
  return pRetry(fn, {
    retries: options.retries || 3,
    minTimeout: 1000,
    maxTimeout: 10000,
    factor: 2,
    randomize: true,
    onFailedAttempt: (error) => {
      console.warn(
        `Attempt ${error.attemptNumber} failed (${error.retriesLeft} retries left).`,
        error.message
      );
    },
    ...options
  });
};

// Circuit breaker for external APIs
const createCircuitBreaker = (fn, options = {}) => {
  const breaker = new CircuitBreaker(fn, {
    timeout: options.timeout || 10000,
    errorThresholdPercentage: options.errorThreshold || 50,
    resetTimeout: options.resetTimeout || 30000,
    rollingCountTimeout: options.rollingCountTimeout || 10000,
    rollingCountBuckets: options.rollingCountBuckets || 10,
    name: options.name || 'circuit-breaker',
    fallback: options.fallback || null,
    ...options
  });

  breaker.on('open', () => {
    console.log(`[${options.name}] Circuit breaker OPEN`);
  });

  breaker.on('halfOpen', () => {
    console.log(`[${options.name}] Circuit breaker HALF-OPEN (testing)`);
  });

  breaker.on('close', () => {
    console.log(`[${options.name}] Circuit breaker CLOSED`);
  });

  return breaker;
};

// Blockfrost API with resilience
const blockfrostBreaker = createCircuitBreaker(
  async (method, endpoint, data = null) => {
    const client = axios.create({
      baseURL: 'https://cardano-preprod.blockfrost.io/api/v0',
      headers: {
        'project_id': process.env.BLOCKFROST_API_KEY,
        'timeout': 10000
      }
    });

    const config = { method, url: endpoint };
    if (data) config.data = data;

    return retryWithBackoff(
      () => client(config),
      { retries: 3 }
    );
  },
  {
    name: 'blockfrost',
    timeout: 12000,
    errorThreshold: 50,
    resetTimeout: 30000
  }
);

// Ogmios WebSocket with resilience
const ogmiosBreaker = createCircuitBreaker(
  async (query) => {
    // Ogmios query logic here
    return ogmiosClient.query(query);
  },
  {
    name: 'ogmios',
    timeout: 15000,
    errorThreshold: 40,
    resetTimeout: 45000
  }
);

// IPFS with resilience
const ipfsBreaker = createCircuitBreaker(
  async (method, path, data = null) => {
    const client = axios.create({
      baseURL: 'http://localhost:5001/api/v0',
      timeout: 10000
    });

    const config = {
      method,
      url: path,
      maxRedirects: 5
    };
    if (data) config.data = data;

    return retryWithBackoff(
      () => client(config),
      { retries: 2 }
    );
  },
  {
    name: 'ipfs',
    timeout: 12000,
    errorThreshold: 60,
    resetTimeout: 20000
  }
);

module.exports = {
  retryWithBackoff,
  createCircuitBreaker,
  blockfrostBreaker,
  ogmiosBreaker,
  ipfsBreaker
};
```

### 2.3 Use in Service

```javascript
// src/services/blockchain.service.js
const { blockfrostBreaker, retryWithBackoff } = require('../resilience/policies');

class BlockchainService {
  async getLatestBlock() {
    try {
      const response = await blockfrostBreaker.fire('get', '/blocks/latest');
      return response.data;
    } catch (error) {
      if (error.message === 'breaker is open') {
        console.error('Blockfrost circuit breaker is open - service unavailable');
        // Return cached data or throw error
        throw new Error('Blockfrost service temporarily unavailable');
      }
      throw error;
    }
  }

  async uploadToIPFS(data) {
    return retryWithBackoff(
      async () => {
        const response = await ipfsBreaker.fire('post', '/add', data);
        return response.data;
      },
      { retries: 2 }
    );
  }
}

module.exports = new BlockchainService();
```

## Part 3: Monitoring & Observability

### 3.1 Circuit Breaker Metrics

Add to OpenTelemetry configuration:

```csharp
// C#: Custom metrics for circuit breakers
var circuitBreakerMetrics = _meter.CreateObservableGauge<int>(
    "resilience.circuit_breaker.state",
    () =>
    {
        // 0=closed, 1=open, 2=half-open
        return new[] {
            new Measurement<int>(
                (int)_blockfrostCircuitBreaker.CircuitState,
                new("service", "blockfrost"))
        };
    },
    description: "Circuit breaker state");
```

### 3.2 Grafana Dashboard

Key panels to add:

1. **Circuit Breaker State** - Shows which services are degraded
2. **Retry Count** - How many retries per minute
3. **Request Latency** - Track before/after resilience policies
4. **Error Rate** - Overall error reduction

### 3.3 Alerts

```yaml
- alert: CircuitBreakerOpen
  expr: resilience_circuit_breaker_state == 1  # open
  for: 2m
  annotations:
    summary: "Circuit breaker open for {{ $labels.service }}"

- alert: HighRetryRate
  expr: rate(resilience_retry_total[5m]) > 0.1
  for: 5m
  annotations:
    summary: "High retry rate: {{ $value }} retries/sec"
```

## Part 4: Testing Resilience

### 4.1 Unit Tests (C#)

```csharp
using Xunit;
using Polly;
using Moq;

public class ResiliencePolicyTests
{
    [Fact]
    public async Task CircuitBreaker_Opens_After_Failures()
    {
        // Arrange
        var policy = ResiliencePolicies.GetCircuitBreakerPolicy();
        var handler = new Mock<Func<Task<HttpResponseMessage>>>();

        handler
            .Setup(h => h())
            .ReturnsAsync(new HttpResponseMessage(System.Net.HttpStatusCode.InternalServerError));

        // Act: Make 5+ requests to trigger circuit breaker
        for (int i = 0; i < 6; i++)
        {
            try
            {
                await policy.ExecuteAsync(() => handler.Object());
            }
            catch (BrokenCircuitException)
            {
                // Expected after 5 failures
                Assert.True(i >= 5);
                return;
            }
        }

        // Assert
        Assert.Fail("Circuit breaker should have opened");
    }

    [Fact]
    public async Task Retry_Succeeds_After_Transient_Failures()
    {
        // Arrange
        var policy = ResiliencePolicies.GetRetryPolicy();
        int attemptCount = 0;

        Func<Task<HttpResponseMessage>> handler = async () =>
        {
            attemptCount++;
            if (attemptCount < 3)
                return new HttpResponseMessage(System.Net.HttpStatusCode.ServiceUnavailable);
            return new HttpResponseMessage(System.Net.HttpStatusCode.OK);
        };

        // Act
        var result = await policy.ExecuteAsync(handler);

        // Assert
        Assert.Equal(System.Net.HttpStatusCode.OK, result.StatusCode);
        Assert.Equal(3, attemptCount);
    }
}
```

### 4.2 Integration Tests

```csharp
[Fact]
public async Task Blockfrost_Recovers_From_Outage()
{
    // Arrange: Simulate Blockfrost down
    var httpClient = new HttpClient(
        new FaultyHttpHandler(failureCount: 5, recoveryTime: TimeSpan.FromSeconds(2)));

    // Act: Service should retry and eventually succeed
    var blockchainService = new BlockchainService(httpClient);
    var result = await blockchainService.GetLatestBlockAsync();

    // Assert
    Assert.NotNull(result);
}
```

### 4.3 Chaos Engineering (Optional)

Use Gremlin or Chaos Mesh to inject failures:

```bash
# Kill Blockfrost API for 60 seconds
chaos inject network loss --target blockfrost.io --duration 60s
```

## Part 5: Fallback Strategies

### 5.1 Caching Fallback

```csharp
public class BlockchainService
{
    private readonly IMemoryCache _cache;

    public async Task<Block> GetLatestBlockAsync()
    {
        try
        {
            var block = await _httpClient.GetAsync<Block>("/blocks/latest");
            _cache.Set("latest_block", block, TimeSpan.FromMinutes(5));
            return block;
        }
        catch (BrokenCircuitException)
        {
            // Fallback to cached data
            if (_cache.TryGetValue("latest_block", out Block cachedBlock))
            {
                return cachedBlock;
            }
            throw;
        }
    }
}
```

### 5.2 Degraded Mode

```csharp
public async Task<AssetInfo> GetAssetDetailsAsync(string assetId)
{
    try
    {
        return await _blockchainService.GetAssetDetailsAsync(assetId);
    }
    catch (BrokenCircuitException)
    {
        // Return basic info from database (degraded mode)
        return await _database.GetAssetBasicInfoAsync(assetId);
    }
}
```

## Success Criteria (for Gap #2 closure)

✅ Circuit breakers on all external APIs  
✅ Retry logic with exponential backoff  
✅ Bulkhead isolation preventing cascade failures  
✅ Timeouts on all external calls  
✅ Fallback strategies (caching, degraded mode)  
✅ Metrics on circuit breaker health  
✅ Alerts when circuit breakers open  
✅ Chaos engineering tests passing  
✅ < 1% impact on latency from resilience policies  
✅ Team trained on resilience patterns  
