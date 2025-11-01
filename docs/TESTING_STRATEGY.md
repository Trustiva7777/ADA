# Comprehensive Testing Strategy

## Overview

This document defines a multi-layered testing strategy covering unit tests, integration tests, mutation testing, property-based testing, and load testing for the Cardano RWA platform.

## Testing Pyramid

```
                    ▲
                   ╱ ╲
                  ╱   ╲   E2E Tests (10%)
                 ╱     ╲  - Critical user flows
                ╱───────╲ - Slow, expensive
               ╱         ╲
              ╱───────────╲
             ╱             ╲ Integration Tests (30%)
            ╱               ╲ - API contracts
           ╱                 ╱ - Database
          ╱                 ╱  - External services
         ╱                 ╱
        ╱_________________╱
       ╱                 ╱  Unit Tests (60%)
      ╱                 ╱   - Business logic
     ╱                 ╱    - Fast feedback
    ╱_________________╱     - 80%+ coverage
```

## Part 1: Unit Testing

### 1.1 C# Unit Tests (xUnit)

#### Setup

```bash
cd SampleApp/BackEnd
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package Moq
dotnet add package FluentAssertions
dotnet add package AutoFixture
```

#### Example: Compliance Check

Create `Tests/ComplianceServiceTests.cs`:

```csharp
using Xunit;
using Moq;
using FluentAssertions;
using AutoFixture;
using SampleApp.BackEnd.Services;

public class ComplianceServiceTests : IDisposable
{
    private readonly IFixture _fixture;
    private readonly Mock<ISanctionsRepository> _sanctionsRepoMock;
    private readonly Mock<ILogger<ComplianceService>> _loggerMock;
    private readonly ComplianceService _sut; // System Under Test

    public ComplianceServiceTests()
    {
        _fixture = new Fixture();
        _sanctionsRepoMock = new Mock<ISanctionsRepository>();
        _loggerMock = new Mock<ILogger<ComplianceService>>();
        
        _sut = new ComplianceService(
            _sanctionsRepoMock.Object,
            _loggerMock.Object);
    }

    [Fact]
    public async Task ScreenEntity_WhenOnSanctionsList_ReturnsFail()
    {
        // Arrange
        var entityName = _fixture.Create<string>();
        _sanctionsRepoMock
            .Setup(x => x.IsOnSanctionsListAsync(entityName))
            .ReturnsAsync(true);

        // Act
        var result = await _sut.ScreenEntityAsync(entityName);

        // Assert
        result.IsCompliant.Should().BeFalse();
        result.Reason.Should().Be("On sanctions list");
        _sanctionsRepoMock.Verify(
            x => x.IsOnSanctionsListAsync(entityName),
            Times.Once);
    }

    [Fact]
    public async Task ScreenEntity_WhenNotOnList_ReturnsPass()
    {
        // Arrange
        var entityName = _fixture.Create<string>();
        _sanctionsRepoMock
            .Setup(x => x.IsOnSanctionsListAsync(entityName))
            .ReturnsAsync(false);

        // Act
        var result = await _sut.ScreenEntityAsync(entityName);

        // Assert
        result.IsCompliant.Should().BeTrue();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task ScreenEntity_WithInvalidInput_ThrowsArgumentException(string input)
    {
        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(
            () => _sut.ScreenEntityAsync(input));
    }

    public void Dispose()
    {
        _sanctionsRepoMock?.Reset();
    }
}
```

### 1.2 TypeScript Unit Tests (Jest)

#### Setup

```bash
npm install --save-dev jest @types/jest ts-jest
npm install --save-dev jest-mock-extended
```

Create `jest.config.js`:

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/__tests__/**/*.test.ts', '**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/index.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
};
```

#### Example: Asset Tokenizer

Create `tests/tokenizer.test.ts`:

```typescript
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { AssetTokenizer } from '../src/services/asset-tokenizer';
import { MockedObjectDeep, mock } from 'jest-mock-extended';
import { BlockfrostAPI } from '../src/clients/blockfrost';

describe('AssetTokenizer', () => {
  let tokenizer: AssetTokenizer;
  let blockfrostMock: MockedObjectDeep<BlockfrostAPI>;

  beforeEach(() => {
    blockfrostMock = mock<BlockfrostAPI>();
    tokenizer = new AssetTokenizer(blockfrostMock);
  });

  it('should mint asset with valid metadata', async () => {
    // Arrange
    const asset = {
      name: 'Property A',
      value: 1000000,
      address: 'addr_test...',
    };

    blockfrostMock.submitTx.mockResolvedValue('tx_hash_123');

    // Act
    const result = await tokenizer.mint(asset);

    // Assert
    expect(result).toEqual('tx_hash_123');
    expect(blockfrostMock.submitTx).toHaveBeenCalledTimes(1);
  });

  it('should fail with invalid asset value', async () => {
    // Arrange
    const invalidAsset = {
      name: 'Property B',
      value: -1000,  // Invalid: negative
      address: 'addr_test...',
    };

    // Act & Assert
    await expect(tokenizer.mint(invalidAsset))
      .rejects
      .toThrow('Asset value must be positive');
  });

  it('should handle Blockfrost API errors gracefully', async () => {
    // Arrange
    blockfrostMock.submitTx.mockRejectedValue(
      new Error('Blockfrost API error'));

    // Act & Assert
    await expect(tokenizer.mint({ name: 'Asset', value: 100, address: 'addr...' }))
      .rejects
      .toThrow();
  });
});
```

## Part 2: Integration Testing

### 2.1 API Contract Tests

Create `Tests/Api/WeatherForecastControllerTests.cs`:

```csharp
using System.Net;
using System.Net.Http.Json;
using Xunit;
using FluentAssertions;
using SampleApp.BackEnd;

public class WeatherForecastControllerTests : IAsyncLifetime
{
    private readonly HttpClient _httpClient;
    private readonly WebApplicationFactory<Program> _factory;

    public WeatherForecastControllerTests()
    {
        _factory = new WebApplicationFactory<Program>();
        _httpClient = _factory.CreateClient();
    }

    [Fact]
    public async Task GetWeatherForecast_ReturnsOkWithData()
    {
        // Act
        var response = await _httpClient.GetAsync("/api/v1/weatherforecast");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Content.Headers.ContentType?.MediaType.Should().Be("application/json");

        var forecasts = await response.Content.ReadAsAsync<List<WeatherForecast>>();
        forecasts.Should().NotBeEmpty();
        forecasts.Should().AllSatisfy(f =>
        {
            f.Date.Should().NotBeNull();
            f.TemperatureC.Should().BeGreaterThan(-50).And.BeLessThan(50);
            f.Summary.Should().NotBeNullOrEmpty();
        });
    }

    [Fact]
    public async Task InvalidEndpoint_Returns404()
    {
        // Act
        var response = await _httpClient.GetAsync("/api/v1/nonexistent");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        _httpClient?.Dispose();
        await _factory.DisposeAsync();
    }
}
```

### 2.2 Database Integration Tests

Create `Tests/Persistence/ComplianceRepositoryTests.cs`:

```csharp
using Xunit;
using FluentAssertions;
using Testcontainers.PostgreSql;
using SampleApp.BackEnd.Persistence;

public class ComplianceRepositoryTests : IAsyncLifetime
{
    private PostgreSqlContainer _container;
    private ComplianceRepository _repository;

    [Fact]
    public async Task SaveComplianceRecord_PersistsToDatabase()
    {
        // Arrange
        var record = new ComplianceRecord
        {
            EntityName = "Test Corp",
            ScreenType = "SANCTIONS",
            Result = "PASS",
            Timestamp = DateTime.UtcNow
        };

        // Act
        await _repository.SaveAsync(record);
        var retrieved = await _repository.GetByEntityAsync("Test Corp");

        // Assert
        retrieved.Should().NotBeNull();
        retrieved.EntityName.Should().Be("Test Corp");
        retrieved.Result.Should().Be("PASS");
    }

    public async Task InitializeAsync()
    {
        _container = new PostgreSqlBuilder()
            .WithImage("postgres:15")
            .Build();

        await _container.StartAsync();

        var connectionString = _container.GetConnectionString();
        _repository = new ComplianceRepository(connectionString);
        await _repository.InitializeAsync();
    }

    public async Task DisposeAsync()
    {
        if (_container != null)
        {
            await _container.StopAsync();
            await _container.DisposeAsync();
        }
    }
}
```

## Part 3: Mutation Testing

Mutation testing verifies that your tests actually catch bugs.

### 3.1 Setup

```bash
dotnet add package Stryker.Core
dotnet add package Stryker.Cli
```

### 3.2 Configuration

Create `stryker-config.json`:

```json
{
  "stryker-config": {
    "test-runner": "dotnet",
    "project-file": "SampleApp/BackEnd/BackEnd.csproj",
    "reporters": ["html", "json"],
    "thresholds": {
      "high": 80,
      "medium": 60,
      "low": 40
    },
    "mutators": [
      "BinaryOperator",
      "Boolean",
      "Assignment",
      "String"
    ]
  }
}
```

### 3.3 Run Mutation Tests

```bash
dotnet stryker
```

**Output:** HTML report showing which mutations survived (your tests missed bugs!)

## Part 4: Property-Based Testing

Property-based testing generates random inputs to verify invariants.

### 4.1 Setup (C#)

```bash
dotnet add package FsCheck.Xunit
```

### 4.2 Example: Asset Validation

```csharp
using FsCheck;
using FsCheck.Xunit;
using Xunit;

public class AssetValidationPropertyTests
{
    [Property]
    public bool Asset_WithValidValue_IsAccepted(decimal value, string name)
    {
        // Property: All positive values should be accepted
        Prop.Implies(value > 0 && !string.IsNullOrEmpty(name), () =>
        {
            var asset = new Asset { Value = value, Name = name };
            return asset.IsValid();
        }).QuickCheckThrowOnFailure();

        return true;
    }

    [Property(Arbitrary = new[] { typeof(AssetGenerators) })]
    public void Asset_Serialization_IsInvertible(Asset asset)
    {
        // Property: Serialize → Deserialize should yield same asset
        var json = JsonSerializer.Serialize(asset);
        var deserialized = JsonSerializer.Deserialize<Asset>(json);

        Assert.Equal(asset.Id, deserialized.Id);
        Assert.Equal(asset.Name, deserialized.Name);
        Assert.Equal(asset.Value, deserialized.Value);
    }
}

// Custom generators for test data
public static class AssetGenerators
{
    public static Arbitrary<Asset> Assets() =>
        Arb.From(
            from id in Arb.Default.String().Filter(x => x != null)
            from name in Arb.Default.String().Filter(x => x != null && x.Length > 0)
            from value in Arb.Default.Decimal()
                .Filter(x => x > 0 && x < 100000000)
            select new Asset { Id = id, Name = name, Value = value });
}
```

### 4.3 Setup (TypeScript)

```bash
npm install --save-dev jest-fast-check fc
```

```typescript
import fc from 'fast-check';
import { describe, it } from '@jest/globals';

describe('Asset Validation (Property-Based)', () => {
  it('should accept all positive values', () => {
    fc.assert(
      fc.property(fc.integer({ min: 1, max: 1000000000 }), (value) => {
        const asset = new Asset(value, 'Test');
        return asset.isValid();
      })
    );
  });

  it('should reject negative values', () => {
    fc.assert(
      fc.property(fc.integer({ max: -1 }), (value) => {
        expect(() => new Asset(value, 'Test'))
          .toThrow();
      })
    );
  });
});
```

## Part 5: Load & Performance Testing

### 5.1 Setup (k6)

Install k6: https://k6.io/docs/getting-started/installation/

Create `tests/load/mint-load-test.js`:

```javascript
import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const mintDuration = new Trend('mint_duration');
const successfulMints = new Counter('successful_mints');

export const options = {
  // Ramp up: 0→100 users over 5 min, stay 10 min, ramp down
  stages: [
    { duration: '5m', target: 100 },
    { duration: '10m', target: 100 },
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    'errors': ['rate<0.05'],  // Error rate < 5%
    'mint_duration': ['p95<2000'],  // p95 latency < 2s
    'http_req_failed': ['rate<0.1'],  // HTTP failure rate < 10%
  },
};

export default function () {
  group('Mint Asset', () => {
    const payload = JSON.stringify({
      assetId: `asset-${__VU}-${__ITER}`,
      name: 'Test Asset',
      value: 1000000,
      nodeUrl: 'http://localhost:1337'
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${__ENV.TOKEN}`
      },
    };

    const response = http.post(
      'http://localhost:5000/api/v1/assets/mint',
      payload,
      params
    );

    const isSuccess = check(response, {
      'status is 200': (r) => r.status === 200,
      'transaction ID in response': (r) => r.json('transactionId') !== null,
      'response time < 2s': (r) => r.timings.duration < 2000,
    });

    errorRate.add(!isSuccess);
    if (isSuccess) {
      successfulMints.add(1);
      mintDuration.add(response.timings.duration);
    }

    sleep(1);
  });
}
```

### 5.2 Run Load Test

```bash
k6 run tests/load/mint-load-test.js --vus 100 --duration 20m
```

### 5.3 Analyze Results

```
Output:
    data_received..................: 5.2 MB 4.3 kB/s
    data_sent.......................: 3.1 MB 2.6 kB/s
    successful_mints................: 120000
    errors...........................: 2400
    mint_duration...................: avg=1.2s p95=1.8s p99=2.1s
    http_req_failed.................: 2% ✓
```

## Part 6: E2E Testing (Critical Flows)

### 6.1 Setup (Playwright)

```bash
npm install --save-dev @playwright/test
npx playwright install
```

### 6.2 Example: Mint → Verify Flow

Create `tests/e2e/mint-workflow.spec.ts`:

```typescript
import { test, expect } from '@playwright/test';

test.describe('Asset Mint Workflow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('http://localhost:3000');
    // Login
    await page.fill('input[name="email"]', 'admin@test.com');
    await page.fill('input[name="password"]', 'password');
    await page.click('button:has-text("Login")');
    await page.waitForNavigation();
  });

  test('should mint asset and verify on blockchain', async ({ page }) => {
    // Step 1: Navigate to mint page
    await page.click('a:has-text("Mint Asset")');
    await expect(page).toHaveURL(/.*mint/);

    // Step 2: Fill form
    await page.fill('input[name="assetName"]', 'Test Property');
    await page.fill('input[name="assetValue"]', '1000000');
    await page.fill('textarea[name="assetDescription"]', 'Commercial property');

    // Step 3: Submit
    await page.click('button:has-text("Mint")');

    // Step 4: Verify success message
    const successMsg = page.locator('.success-message');
    await expect(successMsg).toContainText('Asset minted successfully');

    // Step 5: Extract transaction ID
    const txId = await page.locator('.tx-id').textContent();
    expect(txId).toMatch(/^tx_/);

    // Step 6: Verify on blockchain (wait for confirmation)
    await page.waitForTimeout(10000);  // Wait 10s for blockchain confirmation

    const blockchainPage = page.context().newPage();
    await blockchainPage.goto(`https://preprod.cardanoscan.io/transaction/${txId}`);
    
    const status = await blockchainPage
      .locator('text=Confirmed')
      .isVisible();
    
    expect(status).toBeTruthy();
    await blockchainPage.close();
  });
});
```

### 6.3 Run E2E Tests

```bash
npx playwright test tests/e2e/mint-workflow.spec.ts --headed
```

## Part 7: CI/CD Integration

### 7.1 GitHub Actions Workflow

Create `.github/workflows/test.yml`:

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '9.0.x'

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      # C# Tests
      - name: Restore C# dependencies
        run: dotnet restore SampleApp/BackEnd

      - name: Run C# unit tests
        run: dotnet test SampleApp/BackEnd/Tests --logger trx --collect:"XPlat Code Coverage"

      - name: Run mutation tests
        run: dotnet stryker

      - name: Upload coverage
        uses: codecov/codecov-action@v3

      # TypeScript Tests
      - name: Install Node dependencies
        run: npm ci

      - name: Run TypeScript tests
        run: npm run test -- --coverage

      # Load tests
      - name: Run load tests
        run: |
          docker-compose up -d
          npm run test:load
        env:
          K6_VUS: 50
          K6_DURATION: 5m

      - name: Publish test results
        uses: EnricoMi/publish-unit-test-result-action@v2
        if: always()
```

## Part 8: Test Coverage Goals

| Layer | Tool | Target | Status |
|-------|------|--------|--------|
| Unit Tests | xUnit / Jest | 80%+ | 🟢 |
| Integration Tests | xUnit + Testcontainers | 60%+ | 🟢 |
| Mutation Tests | Stryker | > 75% survival score | 🟡 |
| Property-Based | FsCheck / fc | Key properties | 🟢 |
| E2E | Playwright | 5+ critical flows | 🟡 |
| Load | k6 | < 5% error rate | 🟡 |

## Success Criteria (for Gap #3 closure)

✅ Unit test coverage > 80%  
✅ Integration tests for all APIs  
✅ Mutation test score > 75%  
✅ Property-based tests on validation logic  
✅ E2E tests for critical flows (mint, verify, audit)  
✅ Load test baselines established  
✅ All tests in CI/CD pipeline  
✅ Test failures block production deployment  
✅ Coverage reports generated automatically  
✅ Team trained on all testing approaches  
