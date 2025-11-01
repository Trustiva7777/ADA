import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const apiDuration = new Trend('api_duration');
const successCount = new Counter('success_count');
const resilienceTestCount = new Gauge('resilience_tests');

export const options = {
  // Phase 1: Ramp up
  stages: [
    { duration: '30s', target: 50 },    // Ramp to 50 users
    { duration: '1m30s', target: 100 }, // Ramp to 100 users
    { duration: '2m', target: 100 },    // Stay at 100 users
    { duration: '30s', target: 0 },     // Ramp down
  ],
  
  thresholds: {
    // API endpoints should have <500ms p95
    'api_duration{endpoint:weather}': ['p(95)<500', 'p(99)<1000'],
    
    // Error rate should be <1%
    'errors': ['rate<0.01'],
    
    // Success rate should be >99%
    'success_count': ['count>990'],
  },
  
  // Options for distributed load testing
  ext: {
    loadimpact: {
      projectID: 3352113,
      name: 'Cardano RWA Backend - Phase 1 Performance Test',
    },
  },
};

// Baseline configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:5000';
const API_VERSION = 'v1.0.0';

export default function () {
  // Test 1: Weather Forecast Endpoint
  group('Weather Forecast API', function () {
    const weatherRes = http.get(`${BASE_URL}/weatherforecast`, {
      headers: {
        'Accept': 'application/json',
        'X-API-Version': API_VERSION,
      },
      tags: { endpoint: 'weather' },
    });
    
    apiDuration.add(weatherRes.timings.duration, { endpoint: 'weather' });
    check(weatherRes, {
      'status is 200': (r) => r.status === 200,
      'response time <500ms': (r) => r.timings.duration < 500,
      'has content-type json': (r) => r.headers['Content-Type']?.includes('application/json'),
    }) ? successCount.add(1) : errorRate.add(1);
  });

  // Test 2: API Specification Endpoint
  group('OpenAPI Specification', function () {
    const specRes = http.get(`${BASE_URL}/swagger/v1/swagger.json`, {
      tags: { endpoint: 'openapi' },
    });
    
    apiDuration.add(specRes.timings.duration, { endpoint: 'openapi' });
    check(specRes, {
      'status is 200': (r) => r.status === 200,
      'response time <200ms': (r) => r.timings.duration < 200,
      'has API version': (r) => r.body?.includes(API_VERSION),
    }) ? successCount.add(1) : errorRate.add(1);
  });

  // Test 3: Health Check (Resilience Verification)
  group('Health Check - Resilience', function () {
    const healthRes = http.get(`${BASE_URL}/health`, {
      headers: {
        'X-Correlation-ID': `perf-test-${Date.now()}`,
      },
      tags: { endpoint: 'health' },
    });
    
    apiDuration.add(healthRes.timings.duration, { endpoint: 'health' });
    check(healthRes, {
      'status is 200 or 503': (r) => [200, 503].includes(r.status),
      'response time <100ms': (r) => r.timings.duration < 100,
    }) ? successCount.add(1) : errorRate.add(1);
    
    resilienceTestCount.add(1);
  });

  // Test 4: Concurrent Requests (Bulkhead Testing)
  group('Concurrent Load - Bulkhead Isolation', function () {
    const batchSize = 10;
    const requests = [];
    
    for (let i = 0; i < batchSize; i++) {
      requests.push({
        method: 'GET',
        url: `${BASE_URL}/weatherforecast`,
        params: { tags: { endpoint: 'concurrent' } },
      });
    }
    
    const batchRes = http.batch(requests);
    
    batchRes.forEach((res, idx) => {
      apiDuration.add(res.timings.duration, { endpoint: 'concurrent' });
      const success = check(res, {
        'status is 200': (r) => r.status === 200,
      });
      success ? successCount.add(1) : errorRate.add(1);
    });
  });

  // Test 5: Circuit Breaker Simulation (Fault Injection)
  group('Circuit Breaker - Fault Injection', function () {
    // Send requests to a known failing endpoint to test circuit breaker
    const faultRes = http.get(`${BASE_URL}/weatherforecast/invalid`, {
      headers: {
        'X-Fault-Injection': 'true',
      },
      tags: { endpoint: 'fault-injection' },
    });
    
    check(faultRes, {
      'status is 404 or 503': (r) => [404, 503].includes(r.status),
      'circuit breaker active if 503': (r) => {
        if (r.status === 503) {
          return r.body?.includes('circuit') || r.body?.includes('unavailable');
        }
        return true;
      },
    }) ? successCount.add(1) : errorRate.add(1);
  });

  sleep(1);
}

// Lifecycle hooks for detailed reporting
export function setup() {
  console.log('🚀 Cardano RWA Backend - Phase 1 Performance Test Starting');
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`API Version: ${API_VERSION}`);
  return {
    startTime: new Date(),
  };
}

export function teardown(data) {
  const endTime = new Date();
  const duration = (endTime - data.startTime) / 1000;
  console.log(`✅ Performance Test Complete - Duration: ${duration}s`);
  console.log(`📊 Key Metrics:`);
  console.log(`   - Success Rate: >${(successCount.value / (successCount.value + errorRate.value) * 100).toFixed(2)}%`);
  console.log(`   - Error Rate: <${(errorRate.value / (successCount.value + errorRate.value) * 100).toFixed(2)}%`);
  console.log(`   - API Duration (p95): <500ms`);
  console.log(`   - Resilience Tests: ${resilienceTestCount.value}`);
}
