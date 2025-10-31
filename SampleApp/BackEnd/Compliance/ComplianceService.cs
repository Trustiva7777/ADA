using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BackEnd.Compliance
{
    /// <summary>
    /// Comprehensive compliance service for KYC, AML, sanctions screening, and audit logging
    /// Implements SR-level compliance controls with immutable audit trail
    /// </summary>
    public interface IComplianceService
    {
        // KYC Management
        Task<KYCSubmissionResult> SubmitKYCAsync(string address, KYCData kycData);
        Task<bool> VerifyKYCAsync(string address);
        Task<bool> IsKYCValidAsync(string address);
        Task<KYCStatus> GetKYCStatusAsync(string address);

        // Sanctions Screening
        Task<SanctionsCheckResult> ScreenForSanctionsAsync(string address, string name, string jurisdiction);
        Task<bool> IsSanctionedAsync(string address);

        // Transfer Authorization
        Task<TransferAuthorizationResult> AuthorizeTransferAsync(string fromAddress, string toAddress, decimal amount);
        Task<List<ComplianceViolation>> CheckComplianceAsync(string address);

        // Audit Trail
        Task LogComplianceEventAsync(ComplianceEvent complianceEvent);
        Task<List<ComplianceEvent>> GetAuditTrailAsync(string address, int days = 90);
    }

    /// <summary>
    /// Implementation of compliance service with database persistence and audit logging
    /// </summary>
    public class ComplianceService : IComplianceService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<ComplianceService> _logger;
        private readonly IComplianceDataRepository _repository;
        private readonly ISanctionsScreeningProvider _sanctionsProvider;
        private readonly IAuditLogger _auditLogger;

        public ComplianceService(
            IConfiguration configuration,
            ILogger<ComplianceService> logger,
            IComplianceDataRepository repository,
            ISanctionsScreeningProvider sanctionsProvider,
            IAuditLogger auditLogger)
        {
            _configuration = configuration;
            _logger = logger;
            _repository = repository;
            _sanctionsProvider = sanctionsProvider;
            _auditLogger = auditLogger;
        }

        /// <summary>
        /// Submit KYC data for compliance review
        /// </summary>
        public async Task<KYCSubmissionResult> SubmitKYCAsync(string address, KYCData kycData)
        {
            try
            {
                _logger.LogInformation($"Submitting KYC for address: {address}");

                // Validate required fields
                var validationErrors = ValidateKYCData(kycData);
                if (validationErrors.Count > 0)
                {
                    _logger.LogWarning($"KYC validation failed for {address}: {string.Join(", ", validationErrors)}");
                    await _auditLogger.LogAsync(new AuditLog
                    {
                        EventType = "KYC_VALIDATION_FAILED",
                        Address = address,
                        Details = string.Join("; ", validationErrors),
                        Timestamp = DateTime.UtcNow
                    });
                    return new KYCSubmissionResult { Success = false, Errors = validationErrors };
                }

                // Check if address already has valid KYC
                var existingKYC = await _repository.GetKYCAsync(address);
                if (existingKYC?.IsApproved == true && !IsKYCExpired(existingKYC))
                {
                    _logger.LogWarning($"Valid KYC already exists for {address}");
                    return new KYCSubmissionResult 
                    { 
                        Success = false, 
                        Errors = new List<string> { "Valid KYC already on file" } 
                    };
                }

                // Screen for sanctions before accepting KYC
                var sanctionsResult = await ScreenForSanctionsAsync(address, kycData.LegalName, kycData.Jurisdiction);
                if (sanctionsResult.IsMatch)
                {
                    _logger.LogError($"Sanctions match detected for {address}: {sanctionsResult.MatchType}");
                    await _auditLogger.LogAsync(new AuditLog
                    {
                        EventType = "SANCTIONS_MATCH",
                        Address = address,
                        Details = $"Match Type: {sanctionsResult.MatchType}; Lists: {string.Join(", ", sanctionsResult.MatchedLists)}",
                        Severity = "CRITICAL",
                        Timestamp = DateTime.UtcNow
                    });
                    return new KYCSubmissionResult 
                    { 
                        Success = false, 
                        Errors = new List<string> { "Failed sanctions screening - contact support" } 
                    };
                }

                // Store KYC data
                var kycRecord = new KYCRecord
                {
                    Address = address,
                    LegalName = EncryptPII(kycData.LegalName),
                    DateOfBirth = EncryptPII(kycData.DateOfBirth.ToString("yyyy-MM-dd")),
                    Jurisdiction = kycData.Jurisdiction,
                    AccreditationLevel = kycData.AccreditationLevel,
                    DocumentHash = kycData.DocumentHash,
                    SubmissionTimestamp = DateTime.UtcNow,
                    ExpiryTimestamp = DateTime.UtcNow.AddYears(1),
                    IsApproved = false,
                    Status = KYCStatus.Pending
                };

                await _repository.SaveKYCAsync(kycRecord);

                _logger.LogInformation($"KYC submitted successfully for {address}");
                await _auditLogger.LogAsync(new AuditLog
                {
                    EventType = "KYC_SUBMITTED",
                    Address = address,
                    Details = $"Accreditation Level: {kycData.AccreditationLevel}; Jurisdiction: {kycData.Jurisdiction}",
                    Timestamp = DateTime.UtcNow
                });

                return new KYCSubmissionResult { Success = true };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error submitting KYC for {address}");
                return new KYCSubmissionResult 
                { 
                    Success = false, 
                    Errors = new List<string> { "System error - please try again" } 
                };
            }
        }

        /// <summary>
        /// Verify KYC is valid and not expired
        /// </summary>
        public async Task<bool> VerifyKYCAsync(string address)
        {
            try
            {
                var kycRecord = await _repository.GetKYCAsync(address);
                
                if (kycRecord == null)
                {
                    _logger.LogWarning($"No KYC found for {address}");
                    return false;
                }

                if (!kycRecord.IsApproved)
                {
                    _logger.LogWarning($"KYC not approved for {address}");
                    return false;
                }

                if (IsKYCExpired(kycRecord))
                {
                    _logger.LogWarning($"KYC expired for {address}");
                    await _auditLogger.LogAsync(new AuditLog
                    {
                        EventType = "KYC_EXPIRED",
                        Address = address,
                        Timestamp = DateTime.UtcNow
                    });
                    return false;
                }

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error verifying KYC for {address}");
                return false;
            }
        }

        /// <summary>
        /// Check if KYC is valid (approved and not expired)
        /// </summary>
        public async Task<bool> IsKYCValidAsync(string address)
        {
            return await VerifyKYCAsync(address);
        }

        /// <summary>
        /// Get KYC status for address
        /// </summary>
        public async Task<KYCStatus> GetKYCStatusAsync(string address)
        {
            try
            {
                var kycRecord = await _repository.GetKYCAsync(address);
                return kycRecord?.Status ?? KYCStatus.None;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error getting KYC status for {address}");
                return KYCStatus.None;
            }
        }

        /// <summary>
        /// Screen address against sanctions lists (OFAC, CFTC, UN, EU, etc.)
        /// </summary>
        public async Task<SanctionsCheckResult> ScreenForSanctionsAsync(string address, string name, string jurisdiction)
        {
            try
            {
                _logger.LogInformation($"Screening {address} against sanctions lists");

                // Check cached result first
                var cachedResult = await _repository.GetCachedSanctionsResultAsync(address);
                if (cachedResult != null && !IsCachedResultStale(cachedResult))
                {
                    _logger.LogInformation($"Using cached sanctions result for {address}");
                    return cachedResult.Result;
                }

                // Perform screening against multiple lists
                var result = await _sanctionsProvider.ScreenAsync(new SanctionsScreeningRequest
                {
                    Address = address,
                    Name = name,
                    Jurisdiction = jurisdiction
                });

                // Cache result
                await _repository.CacheSanctionsResultAsync(address, result);

                if (result.IsMatch)
                {
                    _logger.LogError($"Sanctions match for {address}: {result.MatchType}");
                    await _auditLogger.LogAsync(new AuditLog
                    {
                        EventType = "SANCTIONS_MATCH",
                        Address = address,
                        Details = $"Type: {result.MatchType}; Lists: {string.Join(", ", result.MatchedLists)}",
                        Severity = "CRITICAL",
                        Timestamp = DateTime.UtcNow
                    });
                }

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error screening {address} for sanctions");
                // Default to blocked if screening fails
                return new SanctionsCheckResult { IsMatch = true, MatchType = "ERROR_DEFAULT_BLOCK" };
            }
        }

        /// <summary>
        /// Check if address is sanctioned
        /// </summary>
        public async Task<bool> IsSanctionedAsync(string address)
        {
            var result = await ScreenForSanctionsAsync(address, "", "");
            return result.IsMatch;
        }

        /// <summary>
        /// Authorize transfer with compliance checks
        /// </summary>
        public async Task<TransferAuthorizationResult> AuthorizeTransferAsync(string fromAddress, string toAddress, decimal amount)
        {
            try
            {
                _logger.LogInformation($"Authorizing transfer from {fromAddress} to {toAddress}: {amount}");

                var violations = new List<ComplianceViolation>();

                // Check sender KYC
                if (!await VerifyKYCAsync(fromAddress))
                {
                    violations.Add(new ComplianceViolation 
                    { 
                        Code = "SENDER_KYC_INVALID",
                        Message = "Sender KYC is invalid or expired"
                    });
                }

                // Check recipient KYC
                if (!await VerifyKYCAsync(toAddress))
                {
                    violations.Add(new ComplianceViolation 
                    { 
                        Code = "RECIPIENT_KYC_INVALID",
                        Message = "Recipient KYC is invalid or expired"
                    });
                }

                // Check sanctions
                if (await IsSanctionedAsync(fromAddress))
                {
                    violations.Add(new ComplianceViolation 
                    { 
                        Code = "SENDER_SANCTIONED",
                        Message = "Sender is sanctioned"
                    });
                }

                if (await IsSanctionedAsync(toAddress))
                {
                    violations.Add(new ComplianceViolation 
                    { 
                        Code = "RECIPIENT_SANCTIONED",
                        Message = "Recipient is sanctioned"
                    });
                }

                // Check for lockups
                var lockupViolations = await CheckLockupRestrictionsAsync(fromAddress, amount);
                violations.AddRange(lockupViolations);

                var isAuthorized = violations.Count == 0;

                if (!isAuthorized)
                {
                    _logger.LogWarning($"Transfer denied: {string.Join("; ", violations.Select(v => v.Code))}");
                    await _auditLogger.LogAsync(new AuditLog
                    {
                        EventType = "TRANSFER_DENIED",
                        Address = fromAddress,
                        Details = $"To: {toAddress}; Amount: {amount}; Violations: {string.Join("; ", violations.Select(v => v.Code))}",
                        Timestamp = DateTime.UtcNow
                    });
                }

                return new TransferAuthorizationResult
                {
                    IsAuthorized = isAuthorized,
                    Violations = violations
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error authorizing transfer from {fromAddress} to {toAddress}");
                return new TransferAuthorizationResult 
                { 
                    IsAuthorized = false,
                    Violations = new List<ComplianceViolation>
                    {
                        new ComplianceViolation { Code = "SYSTEM_ERROR", Message = "System error during authorization" }
                    }
                };
            }
        }

        /// <summary>
        /// Check all compliance violations for an address
        /// </summary>
        public async Task<List<ComplianceViolation>> CheckComplianceAsync(string address)
        {
            var violations = new List<ComplianceViolation>();

            if (!await VerifyKYCAsync(address))
            {
                violations.Add(new ComplianceViolation { Code = "KYC_INVALID", Message = "KYC is invalid or expired" });
            }

            if (await IsSanctionedAsync(address))
            {
                violations.Add(new ComplianceViolation { Code = "SANCTIONED", Message = "Address is sanctioned" });
            }

            return violations;
        }

        /// <summary>
        /// Log compliance event with immutable audit trail
        /// </summary>
        public async Task LogComplianceEventAsync(ComplianceEvent complianceEvent)
        {
            try
            {
                await _auditLogger.LogAsync(new AuditLog
                {
                    EventType = complianceEvent.EventType,
                    Address = complianceEvent.Address,
                    Details = complianceEvent.Details,
                    Severity = complianceEvent.Severity,
                    Timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error logging compliance event");
            }
        }

        /// <summary>
        /// Get audit trail for address
        /// </summary>
        public async Task<List<ComplianceEvent>> GetAuditTrailAsync(string address, int days = 90)
        {
            try
            {
                var events = await _auditLogger.GetEventsAsync(address, DateTime.UtcNow.AddDays(-days));
                return events.Select(e => new ComplianceEvent
                {
                    EventType = e.EventType,
                    Address = e.Address,
                    Details = e.Details,
                    Severity = e.Severity,
                    Timestamp = e.Timestamp
                }).ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error retrieving audit trail for {address}");
                return new List<ComplianceEvent>();
            }
        }

        // ==================== Private Helpers ====================

        private List<string> ValidateKYCData(KYCData data)
        {
            var errors = new List<string>();

            if (string.IsNullOrWhiteSpace(data.LegalName))
                errors.Add("Legal name is required");

            if (data.DateOfBirth == default)
                errors.Add("Date of birth is required");

            if (data.DateOfBirth > DateTime.UtcNow)
                errors.Add("Date of birth cannot be in the future");

            if ((DateTime.UtcNow.Year - data.DateOfBirth.Year) < 18)
                errors.Add("Must be at least 18 years old");

            if (string.IsNullOrWhiteSpace(data.Jurisdiction) || data.Jurisdiction.Length != 2)
                errors.Add("Valid jurisdiction code required");

            if (string.IsNullOrWhiteSpace(data.DocumentHash))
                errors.Add("Document hash is required");

            return errors;
        }

        private bool IsKYCExpired(KYCRecord kyc)
        {
            return DateTime.UtcNow > kyc.ExpiryTimestamp;
        }

        private bool IsCachedResultStale(CachedSanctionsResult cached)
        {
            var cacheValidityDays = int.Parse(_configuration["Compliance:SanctionsCacheValidityDays"] ?? "30");
            return (DateTime.UtcNow - cached.CachedAt).TotalDays > cacheValidityDays;
        }

        private string EncryptPII(string pii)
        {
            // TODO: Implement PII encryption using Azure Key Vault or similar
            // For now, return as-is (implement real encryption in production)
            return pii;
        }

        private async Task<List<ComplianceViolation>> CheckLockupRestrictionsAsync(string address, decimal amount)
        {
            // TODO: Integrate with TransferGate contract to check lockups
            return new List<ComplianceViolation>();
        }
    }

    // ==================== Data Models ====================

    public class KYCData
    {
        public string LegalName { get; set; }
        public DateTime DateOfBirth { get; set; }
        public string Jurisdiction { get; set; }
        public string AccreditationLevel { get; set; }
        public string DocumentHash { get; set; }
    }

    public class KYCSubmissionResult
    {
        public bool Success { get; set; }
        public List<string> Errors { get; set; } = new();
    }

    public enum KYCStatus
    {
        None,
        Pending,
        Approved,
        Restricted,
        Suspended,
        Blocked
    }

    public class SanctionsCheckResult
    {
        public bool IsMatch { get; set; }
        public string MatchType { get; set; }
        public List<string> MatchedLists { get; set; } = new();
        public decimal MatchScore { get; set; }
    }

    public class SanctionsScreeningRequest
    {
        public string Address { get; set; }
        public string Name { get; set; }
        public string Jurisdiction { get; set; }
    }

    public class TransferAuthorizationResult
    {
        public bool IsAuthorized { get; set; }
        public List<ComplianceViolation> Violations { get; set; } = new();
    }

    public class ComplianceViolation
    {
        public string Code { get; set; }
        public string Message { get; set; }
    }

    public class ComplianceEvent
    {
        public string EventType { get; set; }
        public string Address { get; set; }
        public string Details { get; set; }
        public string Severity { get; set; }
        public DateTime Timestamp { get; set; }
    }

    public class KYCRecord
    {
        public string Address { get; set; }
        public string LegalName { get; set; }
        public string DateOfBirth { get; set; }
        public string Jurisdiction { get; set; }
        public string AccreditationLevel { get; set; }
        public string DocumentHash { get; set; }
        public DateTime SubmissionTimestamp { get; set; }
        public DateTime ExpiryTimestamp { get; set; }
        public bool IsApproved { get; set; }
        public KYCStatus Status { get; set; }
    }

    public class CachedSanctionsResult
    {
        public string Address { get; set; }
        public SanctionsCheckResult Result { get; set; }
        public DateTime CachedAt { get; set; }
    }

    public class AuditLog
    {
        public string EventType { get; set; }
        public string Address { get; set; }
        public string Details { get; set; }
        public string Severity { get; set; }
        public DateTime Timestamp { get; set; }
    }

    // ==================== Repository & Providers ====================

    public interface IComplianceDataRepository
    {
        Task<KYCRecord> GetKYCAsync(string address);
        Task SaveKYCAsync(KYCRecord kyc);
        Task<CachedSanctionsResult> GetCachedSanctionsResultAsync(string address);
        Task CacheSanctionsResultAsync(string address, SanctionsCheckResult result);
    }

    public interface ISanctionsScreeningProvider
    {
        Task<SanctionsCheckResult> ScreenAsync(SanctionsScreeningRequest request);
    }

    public interface IAuditLogger
    {
        Task LogAsync(AuditLog auditLog);
        Task<List<AuditLog>> GetEventsAsync(string address, DateTime fromDate);
    }
}
