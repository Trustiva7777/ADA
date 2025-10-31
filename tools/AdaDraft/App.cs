using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
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
      string? attestationFile,
      string? manifestFile,
      string? allowlistFile,
      long totalLovelace,
      int outputs,
      string feeNote,
      string inputsTemplatePath,
      string unsignedPlanPath,
      string submitScriptPath
    );

    public static int Main(string[] args)
    {
        try
        {
            string ledgerPath = "reports/ada_ledger.csv";
            string outDir = "out/tx_batches";
            int maxOutputs = 80; // safe default per batch
            string policyId = Environment.GetEnvironmentVariable("POLICY_ID") ?? "UNKNOWN_POLICY";
            string network = Environment.GetEnvironmentVariable("NETWORK") ?? "Preprod";
            string sourceAccountTag = Environment.GetEnvironmentVariable("SOURCE_ACCOUNT_TAG") ?? "Treasury-1";
            string? attestationFile = $"docs/token/attestation.{network}.json";
            string? manifestFile = "docs/sha256-manifest.json";
            string? allowlistFile = File.Exists("docs/allowlist.sha256") ? "docs/allowlist.sha256" : null;

            for (int i=0;i<args.Length;i++)
            {
                if (args[i]=="--ledger" && i+1<args.Length) ledgerPath=args[i+1];
                if (args[i]=="--out" && i+1<args.Length) outDir=args[i+1];
                if (args[i]=="--max-outputs" && i+1<args.Length) maxOutputs=int.Parse(args[i+1]);
                if (args[i]=="--policy" && i+1<args.Length) policyId=args[i+1];
                if (args[i]=="--network" && i+1<args.Length) network=args[i+1];
                if (args[i]=="--source" && i+1<args.Length) sourceAccountTag=args[i+1];
                if (args[i]=="--attestation" && i+1<args.Length) attestationFile=args[i+1];
                if (args[i]=="--manifest" && i+1<args.Length) manifestFile=args[i+1];
                if (args[i]=="--allowlist" && i+1<args.Length) allowlistFile=args[i+1];
            }

            Directory.CreateDirectory(outDir);
            if (!File.Exists(ledgerPath)) throw new Exception($"Ledger not found: {ledgerPath}");

            var rows = ReadLedger(ledgerPath).ToList();
            if (rows.Count==0) throw new Exception("Ledger is empty");

            var outputs = rows.Select(r => new TxOutput(r.address, AdaToLovelace(r.amountAda), r.memo)).ToList();
            var total = outputs.Sum(o => o.lovelace);

            // Batch outputs
            int batchIdx = 0;
            int cursor = 0;
            var now = DateTime.UtcNow.ToString("O");
            var options = new JsonSerializerOptions { WriteIndented = true, DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull };

            while (cursor < outputs.Count)
            {
                batchIdx++;
                var slice = outputs.Skip(cursor).Take(maxOutputs).ToList();
                cursor += slice.Count;

                var unsignedPlanPath = Path.Combine(outDir, $"tx_batch_{batchIdx:D3}.json").Replace("\\","/");
                var inputsTemplatePath = Path.Combine(outDir, $"tx_batch_{batchIdx:D3}.inputs.template.json").Replace("\\","/");
                var submitScriptPath = Path.Combine(outDir, $"submit_batch_{batchIdx:D3}.curl.sh").Replace("\\","/");

                var plan = new
                {
                    meta = new {
                        batchIndex = batchIdx,
                        policyId,
                        network,
                        createdAt = now,
                        sourceAccountTag,
                        attestationFile,
                        manifestFile,
                        allowlistFile,
                        totalLovelaceInBatch = slice.Sum(s=>s.lovelace),
                        outputs = slice.Count,
                        feeNote = "Estimate ~0.18 ADA base + ~0.02 ADA per output; adjust per protocol version."
                    },
                    // Fill these UTxOs manually or via your treasury indexer before signing:
                    inputs = new [] { new { txHash = "<FILL-IN>", index = 0, lovelace = 0L } },
                    outputs = slice.Select(o => new {
                        address = o.address,
                        lovelace = o.lovelace,
                        memo = o.memo
                    }),
                    change = new {
                        address = "<TREASURY_RETURN_ADDRESS>",
                        minLovelace = 1_500_000
                    },
                    // Optional metadata you may want to include when you build/sign:
                    auxiliary = new {
                        label_674 = new { attestation = attestationFile, policy = policyId },
                        memo = "Distribution batch"
                    }
                };

                // write plan
                File.WriteAllText(unsignedPlanPath, JsonSerializer.Serialize(plan, options));

                // inputs template convenience file
                var inputsTemplate = new {
                    inputs = new [] { new { txHash="<FILL-IN>", index=0, lovelace=0L } },
                    changeAddress = "<TREASURY_RETURN_ADDRESS>"
                };
                File.WriteAllText(inputsTemplatePath, JsonSerializer.Serialize(inputsTemplate, options));

                // curl skeleton for later submission of signed CBOR
                var curlLines = new[]
                {
                    "#!/usr/bin/env bash",
                    "set -euo pipefail",
                    $"# 1) Build & sign this batch into CBOR at {outDir}/tx_batch_{batchIdx:D3}.signed.cbor",
                    "# 2) Submit via your Submit-API endpoint",
                    "SUBMIT_API=\"${SUBMIT_API:-http://localhost:8090}\"",
                    $"CBOR=\"{outDir}/tx_batch_{batchIdx:D3}.signed.cbor\"",
                    "[ -f \"$CBOR\" ] || (echo \"Missing $CBOR\" >&2; exit 2)",
                    "curl -sS -X POST \"$SUBMIT_API/api/tx/submit\" \\",
                    "  -H 'Content-Type: application/cbor' \\",
                    "  --data-binary \"@${CBOR}\"",
                    $"echo \"\\nSubmitted batch {batchIdx:D3}\""
                };
                var curl = string.Join("\n", curlLines) + "\n";
                File.WriteAllText(submitScriptPath, curl);
                try { System.Diagnostics.Process.Start("bash", $"-lc \"chmod +x {submitScriptPath}\""); } catch {}
                Console.WriteLine($"Drafted {unsignedPlanPath}  (outputs: {slice.Count})");
            }

            // Batch summary
            var summary = new TxBatchPlan(
                batchIndex: (int)Math.Ceiling(outputs.Count / (double)maxOutputs),
                policyId: policyId,
                network: network,
                createdAt: now,
                sourceAccountTag: sourceAccountTag,
                attestationFile: attestationFile,
                manifestFile: manifestFile,
                allowlistFile: allowlistFile,
                totalLovelace: total,
                outputs: outputs.Count,
                feeNote: "Rough: base + per-output; finalize w/ builder.",
                inputsTemplatePath: $"{outDir}/tx_batch_001.inputs.template.json",
                unsignedPlanPath: $"{outDir}/tx_batch_001.json",
                submitScriptPath: $"{outDir}/submit_batch_001.curl.sh"
            );
            File.WriteAllText(Path.Combine(outDir, "SUMMARY.json"), JsonSerializer.Serialize(summary, options));
            Console.WriteLine($"Total recipients: {outputs.Count}, total ADA: {total/1_000_000m:F6}");
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 1;
        }
    }

    private static long AdaToLovelace(decimal ada) =>
      (long)Math.Round(ada * 1_000_000m, MidpointRounding.AwayFromZero);

    private static IEnumerable<LedgerRow> ReadLedger(string path)
    {
        // CSV headers: address,amountAda[,memo]
        var lines = File.ReadAllLines(path);
        foreach (var (line, idx) in lines.Select((l,i) => (l,i)))
        {
            if (idx==0 && line.ToLowerInvariant().Contains("address")) continue;
            if (string.IsNullOrWhiteSpace(line)) continue;
            var parts = SplitCsv(line);
            if (parts.Length < 2) throw new Exception($"Bad CSV line {idx+1}: {line}");
            var addr = parts[0].Trim();
            // Relaxed sanity: warn but do not fail hard; accept typical bech32-like strings
            if (addr.Length < 10 || !Regex.IsMatch(addr, "^[a-z0-9_]+$"))
                Console.Error.WriteLine($"Suspicious address on line {idx+1}: {addr}");
            if (!decimal.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var ada))
                throw new Exception($"Bad amount on line {idx+1}: {parts[1]}");
            var memo = parts.Length >=3 ? (string.IsNullOrWhiteSpace(parts[2])? null : parts[2]) : null;
            yield return new LedgerRow(addr, ada, memo);
        }
    }

    private static string[] SplitCsv(string line)
    {
        // basic CSV splitter supporting quoted commas
        var list = new List<string>();
        bool inQ=false; var cur="";
        for (int i=0;i<line.Length;i++)
        {
            var c=line[i];
            if (c=='\"'){ inQ = !inQ; continue; }
            if (c==',' && !inQ){ list.Add(cur); cur=""; continue; }
            cur+=c;
        }
        list.Add(cur);
        return list.ToArray();
    }
}