# DevOps Maturity & Feature Flags Implementation

## Part 1: Blue-Green Deployments

### 1.1 Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Load Balancer / Router                 │
│                    (100% → Blue or Green)                 │
└───────────┬──────────────────────────────────────┬────────┘
            │                                      │
            ▼                                      ▼
    ┌──────────────┐                     ┌──────────────┐
    │  Blue (v1)   │                     │ Green (v2)   │
    │  Running     │                     │  Standby     │
    │              │                     │              │
    │  - 3 replicas│                     │  - 0 replicas│
    │  - 100% users│                     │  - Testing   │
    └──────────────┘                     └──────────────┘
            │
            └─── Health Checks ───┘
            └─── Metrics ──────┘
            └─── Logs ─────────┘

Deployment Flow:
1. Deploy v2 to Green (0% traffic)
2. Run smoke tests on Green
3. Monitor Green metrics
4. Switch 10% traffic to Green
5. If healthy, switch remaining traffic
6. Keep Blue running for 1 hour (instant rollback)
7. Decommission Blue
```

### 1.2 Helm Chart for Blue-Green

Create `k8s/helm/cardano-rwa-bg/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cardano-rwa-{{ .Values.environment }}-{{ .Values.slot }}  # blue or green
  labels:
    app: cardano-rwa
    slot: {{ .Values.slot }}
    version: {{ .Chart.AppVersion }}
spec:
  replicas: {{ .Values.replicas }}
  selector:
    matchLabels:
      app: cardano-rwa
      slot: {{ .Values.slot }}
  template:
    metadata:
      labels:
        app: cardano-rwa
        slot: {{ .Values.slot }}
        version: {{ .Chart.AppVersion }}
    spec:
      containers:
      - name: backend
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5000
          name: http
        livenessProbe:
          httpGet:
            path: /health/live
            port: 5000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            cpu: {{ .Values.resources.requests.cpu }}
            memory: {{ .Values.resources.requests.memory }}
          limits:
            cpu: {{ .Values.resources.limits.cpu }}
            memory: {{ .Values.resources.limits.memory }}
```

### 1.3 Blue-Green Switch Script

Create `scripts/blue-green-deploy.sh`:

```bash
#!/bin/bash
set -e

ENVIRONMENT=${1:-prod}
NEW_VERSION=${2:-latest}
NAMESPACE="cardano-rwa"

echo "🔵🟢 Starting blue-green deployment for $ENVIRONMENT"

# 1. Determine current slot
CURRENT_SLOT=$(kubectl get service cardano-rwa-prod \
  -n $NAMESPACE \
  -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo "blue")

if [ "$CURRENT_SLOT" == "blue" ]; then
  NEW_SLOT="green"
else
  NEW_SLOT="blue"
fi

echo "Current: $CURRENT_SLOT → Deploying to: $NEW_SLOT"

# 2. Deploy to new slot
echo "Deploying $NEW_VERSION to $NEW_SLOT..."
helm upgrade --install cardano-rwa-$NEW_SLOT \
  ./k8s/helm/cardano-rwa-bg \
  --namespace $NAMESPACE \
  --set slot=$NEW_SLOT \
  --set image.tag=$NEW_VERSION \
  --set environment=$ENVIRONMENT \
  --wait \
  --timeout 5m

# 3. Wait for health checks
echo "Waiting for $NEW_SLOT to be healthy..."
kubectl rollout status deployment/cardano-rwa-$ENVIRONMENT-$NEW_SLOT \
  -n $NAMESPACE \
  --timeout=5m

# 4. Run smoke tests
echo "Running smoke tests against $NEW_SLOT..."
POD=$(kubectl get pod -n $NAMESPACE \
  -l app=cardano-rwa,slot=$NEW_SLOT \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec $POD -n $NAMESPACE -- \
  curl -f http://localhost:5000/health/live || exit 1

# 5. Canary: 10% traffic to new slot
echo "🟡 Canary: Routing 10% traffic to $NEW_SLOT..."
kubectl patch service cardano-rwa-$ENVIRONMENT \
  -n $NAMESPACE \
  -p '{"spec":{"trafficPolicy":{"canary":{"weight":10}}}}'

sleep 30

# 6. Monitor metrics
echo "Monitoring error rate for 1 minute..."
ERROR_RATE=$(prometheus_query 'rate(errors[1m])' slot=$NEW_SLOT)

if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
  echo "❌ Error rate too high ($ERROR_RATE). Rolling back..."
  kubectl delete deployment cardano-rwa-$ENVIRONMENT-$NEW_SLOT -n $NAMESPACE
  exit 1
fi

echo "✅ Error rate acceptable"

# 7. Switch 100% traffic
echo "🟢 Switching 100% traffic to $NEW_SLOT..."
kubectl patch service cardano-rwa-$ENVIRONMENT \
  -n $NAMESPACE \
  -p '{"spec":{"selector":{"slot":"'$NEW_SLOT'"}}}'

# 8. Monitor for 5 minutes
echo "Monitoring for 5 minutes..."
for i in {1..30}; do
  ERROR_RATE=$(prometheus_query 'rate(errors[1m])' slot=$NEW_SLOT)
  
  if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
    echo "❌ Error rate spike detected. Rolling back..."
    kubectl patch service cardano-rwa-$ENVIRONMENT \
      -n $NAMESPACE \
      -p '{"spec":{"selector":{"slot":"'$CURRENT_SLOT'"}}}'
    exit 1
  fi
  
  echo "✅ Check $i/30 - Error rate: $ERROR_RATE"
  sleep 10
done

# 9. Keep old slot for 1 hour (instant rollback)
echo "✨ Deployment successful! Keeping $CURRENT_SLOT for 1 hour rollback window..."
sleep 3600

# 10. Decommission old slot
echo "Decommissioning $CURRENT_SLOT..."
kubectl delete deployment cardano-rwa-$ENVIRONMENT-$CURRENT_SLOT -n $NAMESPACE

echo "✨ Blue-green deployment complete!"
```

## Part 2: Feature Flags

### 2.1 Feature Flag Service

Create `Infrastructure/FeatureFlagService.cs`:

```csharp
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.FeatureManagement;

public class FeatureFlagService
{
    private readonly IFeatureManager _featureManager;
    private readonly ILogger<FeatureFlagService> _logger;

    public FeatureFlagService(
        IFeatureManager featureManager,
        ILogger<FeatureFlagService> logger)
    {
        _featureManager = featureManager;
        _logger = logger;
    }

    public async Task<bool> IsEnabledAsync(string featureName)
    {
        try
        {
            var enabled = await _featureManager.IsEnabledAsync(featureName);
            _logger.LogInformation($"Feature {featureName}: {(enabled ? "ON" : "OFF")}");
            return enabled;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error checking feature {featureName}");
            return false;  // Fail safe - features off
        }
    }

    public async Task<T?> GetAsync<T>(string featureName)
    {
        var enabled = await IsEnabledAsync(featureName);
        return enabled ? default : default;
    }
}

// Enum for feature names
public enum FeatureFlag
{
    BatchMinting,           // New batch minting API
    EnhancedCompliance,     // New ML-based compliance checks
    DirectBlockchainAPI,    // Direct Cardano node access (bypass Blockfrost)
    IPFSEvidence,          // Store evidence in IPFS
    AsyncProcessing,       // Queue-based processing
    NewDashboard,          // React-based dashboard
    WebhookNotifications,  // Real-time webhooks
    AIMonitoring,          // AI-powered anomaly detection
}
```

### 2.2 Feature Configuration

Create `appsettings.json`:

```json
{
  "FeatureManagement": {
    "BatchMinting": {
      "EnabledFor": [
        {
          "Name": "TimeWindow",
          "Parameters": {
            "Start": "18:00",
            "End": "22:00"
          }
        },
        {
          "Name": "PercentageRollout",
          "Parameters": {
            "Value": "25"
          }
        }
      ]
    },
    "EnhancedCompliance": {
      "Enabled": true,
      "EnabledFor": [
        {
          "Name": "AccountId",
          "Parameters": {
            "AccountIds": "admin@company.com,compliance@company.com"
          }
        }
      ]
    },
    "NewDashboard": {
      "Enabled": false,
      "EnabledFor": [
        {
          "Name": "BetaUsers",
          "Parameters": {
            "Users": "beta@test.com"
          }
        }
      ]
    }
  }
}
```

### 2.3 Usage in Controllers

```csharp
[ApiController]
[Route("api/[controller]")]
public class AssetsController : ControllerBase
{
    private readonly IFeatureManager _featureManager;

    public AssetsController(IFeatureManager featureManager)
    {
        _featureManager = featureManager;
    }

    [HttpPost("mint")]
    public async Task<IActionResult> Mint(MintRequest request)
    {
        if (await _featureManager.IsEnabledAsync(nameof(FeatureFlag.BatchMinting)))
        {
            return await MintBatch(request);
        }

        return await MintSingle(request);
    }

    private async Task<IActionResult> MintBatch(MintRequest request)
    {
        // New batch implementation
        var result = await _batchMintingService.MintAsync(request);
        return Ok(result);
    }

    private async Task<IActionResult> MintSingle(MintRequest request)
    {
        // Legacy single mint
        var result = await _mintService.MintAsync(request);
        return Ok(result);
    }
}
```

### 2.4 Feature Flag Metrics

Create OpenTelemetry instrumentation:

```csharp
public class FeatureFlagMetrics
{
    private readonly Meter _meter;
    private readonly Counter<int> _featureUsageCounter;

    public FeatureFlagMetrics()
    {
        _meter = new Meter("FeatureFlags", "1.0.0");
        _featureUsageCounter = _meter.CreateCounter<int>(
            "feature_flag.usage",
            description: "Feature flag usage count");
    }

    public void RecordUsage(string featureName, bool enabled)
    {
        _featureUsageCounter.Add(1, new(
            "feature", featureName,
            "enabled", enabled.ToString()));
    }
}
```

## Part 3: CI/CD Pipeline Maturity

### 3.1 Complete GitOps Pipeline

Create `.github/workflows/gitops-deploy.yml`:

```yaml
name: GitOps Deploy

on:
  push:
    branches: [main]
    paths:
      - 'SampleApp/**'
      - 'k8s/**'
      - '.github/workflows/gitops-deploy.yml'

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.build.outputs.image }}
    steps:
      - uses: actions/checkout@v3

      - name: Build and push Docker image
        id: build
        run: |
          docker build -t ghcr.io/cardano-rwa/backend:${{ github.sha }} .
          docker push ghcr.io/cardano-rwa/backend:${{ github.sha }}
          echo "image=ghcr.io/cardano-rwa/backend:${{ github.sha }}" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          ref: 'gitops'  # Separate branch for k8s manifests

      - name: Update image in GitOps repo
        run: |
          sed -i "s|image:.*|image: ${{ needs.build.outputs.image }}|g" k8s/overlays/prod/kustomization.yaml
          
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add k8s/overlays/prod/kustomization.yaml
          git commit -m "chore: update image to ${{ github.sha }}"
          git push

  # ArgoCD watches GitOps branch and auto-deploys
```

### 3.2 Rollback Strategy

```bash
#!/bin/bash
# scripts/rollback.sh

REVISION=${1:-HEAD~1}

echo "Rolling back to $REVISION"

# Revert to previous commit in GitOps repo
git revert -n $REVISION
git commit -m "rollback: revert to $REVISION"
git push origin gitops

# ArgoCD detects change and rolls back automatically
echo "✅ Rollback initiated. ArgoCD will deploy previous version."
```

## Part 4: GDPR & SOC2 Compliance

### 4.1 Data Classification

Create `docs/DATA_CLASSIFICATION.md`:

```markdown
# Data Classification & Handling

## Sensitivity Levels

### Public
- General information about assets
- Public audit logs
- Service status

### Internal
- Platform statistics
- Internal documentation
- Team information

### Confidential
- Asset valuations
- KYC records
- Financial transactions

### Restricted
- Master encryption keys
- Admin credentials
- Personally identifiable information (PII)

## Retention Policy

| Data Type | Retention | Deletion Method |
|-----------|-----------|-----------------|
| PII | Until opt-out | Secure wipe |
| Compliance Records | 7 years | Archived → Deleted |
| Audit Logs | 2 years | Immutable archive |
| Transactional | 7 years | Encrypted archive |
| Cookies | As per user preference | Automatic |
```

### 4.2 GDPR Compliance Implementation

Create `Services/GDPRService.cs`:

```csharp
public class GDPRService
{
    private readonly IRepository<User> _userRepo;
    private readonly IRepository<AuditLog> _auditLogRepo;
    private readonly ILogger<GDPRService> _logger;

    public async Task ExportUserDataAsync(string userId)
    {
        // GDPR Right to Data Portability
        var user = await _userRepo.GetAsync(userId);
        var auditLogs = await _auditLogRepo.FindAsync(u => u.UserId == userId);
        
        var export = new
        {
            user,
            auditLogs,
            exportDate = DateTime.UtcNow
        };

        // Generate JSON export
        var json = JsonSerializer.Serialize(export, new JsonSerializerOptions 
        { 
            WriteIndented = true 
        });

        _logger.LogInformation($"GDPR export requested for user {userId}");
        
        return json;
    }

    public async Task DeleteUserDataAsync(string userId)
    {
        // GDPR Right to be Forgotten
        _logger.LogInformation($"GDPR deletion requested for user {userId}");

        // Keep compliance records (legally required)
        var complianceRecords = await _auditLogRepo.FindAsync(
            u => u.UserId == userId && u.Category == "compliance");

        // Anonymize all other records
        var otherRecords = await _auditLogRepo.FindAsync(
            u => u.UserId == userId && u.Category != "compliance");

        foreach (var record in otherRecords)
        {
            record.UserId = "[DELETED]";
            record.Email = null;
            record.PhoneNumber = null;
            await _auditLogRepo.UpdateAsync(record);
        }

        // Mark user as deleted (soft delete)
        var user = await _userRepo.GetAsync(userId);
        user.IsDeleted = true;
        user.DeletedAt = DateTime.UtcNow;
        await _userRepo.UpdateAsync(user);

        _logger.LogInformation($"User {userId} marked for deletion - data anonymized");
    }

    public async Task<bool> ConsentToProcessingAsync(string userId, string consentType)
    {
        // GDPR Consent Management
        var consent = new GDPRConsent
        {
            UserId = userId,
            Type = consentType,
            GrantedAt = DateTime.UtcNow,
            Status = "GRANTED"
        };

        await _consentRepo.AddAsync(consent);
        _logger.LogInformation($"Consent {consentType} granted for user {userId}");
        
        return true;
    }
}
```

### 4.3 SOC2 Audit Trail

```csharp
public class AuditTrail
{
    public string Id { get; set; }
    public string UserId { get; set; }
    public string Action { get; set; }  // CREATE, UPDATE, DELETE, LOGIN, EXPORT
    public string Resource { get; set; } // Asset, User, Config
    public string ResourceId { get; set; }
    public string Changes { get; set; }  // JSON diff
    public string IpAddress { get; set; }
    public string UserAgent { get; set; }
    public DateTime Timestamp { get; set; }
    public string Status { get; set; }  // SUCCESS, FAILURE
    public string Reason { get; set; }  // Why it failed
}

// Make audit logs immutable
public class AuditLogRepository
{
    public async Task AddAsync(AuditTrail trail)
    {
        // Append-only: Can only INSERT, never UPDATE/DELETE
        await _db.AuditTrails.AddAsync(trail);
        await _db.SaveChangesAsync();
        
        // Copy to immutable archive (cloud storage)
        await _archiveService.ArchiveAsync(trail);
    }
}
```

### 4.4 Compliance Dashboard

Create Grafana dashboard for monitoring:

```json
{
  "panels": [
    {
      "title": "GDPR Deletion Requests",
      "targets": [{
        "expr": "increase(gdpr_deletion_requests_total[24h])"
      }]
    },
    {
      "title": "Failed Access Attempts",
      "targets": [{
        "expr": "rate(auth_failures_total[5m])"
      }]
    },
    {
      "title": "Data Exports",
      "targets": [{
        "expr": "increase(gdpr_data_exports_total[24h])"
      }]
    },
    {
      "title": "Audit Log Integrity",
      "targets": [{
        "expr": "increase(audit_log_integrity_checks_total{status='passed'}[24h])"
      }]
    }
  ]
}
```

## Success Criteria (for Gap #8 & #10 closure)

✅ Blue-green deployments automated  
✅ Instant rollback capability tested  
✅ Feature flags operational for all major features  
✅ Canary deployments with metrics validation  
✅ GitOps pipeline with ArgoCD  
✅ GDPR data export/deletion implemented  
✅ SOC2 audit trail immutable and comprehensive  
✅ Compliance dashboard visible  
✅ Data retention policies enforced  
✅ PII encryption at rest and in transit  
✅ GDPR consent management working  
✅ Monthly compliance audit completed  
✅ Zero unplanned outages from deployments  
✅ < 30 second deployment time  
