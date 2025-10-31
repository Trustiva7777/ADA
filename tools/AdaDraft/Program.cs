// Removed legacy Program.cs (not used). See App.cs for the actual implementation.
*/
/*using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Tools.AdaDraft;

internal class Program
{
    private record LedgerRow(string address, decimal amountAda, string? memo);
    private record TxOutput(string address, long lovelace, string? memo);
    private record TxBatchPlan(
      int batchIndex,
      string policyId,
      string network,
      string createdAt,
      string sourceAccountTag,
    namespace Tools.AdaDraft;

    // Intentionally empty. The actual entry point for AdaDraft is in App.cs
    internal static class ProgramStub { }
      int outputs,
