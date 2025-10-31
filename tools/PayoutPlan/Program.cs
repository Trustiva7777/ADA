using System.Text;
using System.Text.Json;

static int Usage()
{
    Console.Error.WriteLine("Usage:");
    Console.Error.WriteLine("  dotnet run --project tools/PayoutPlan -- csv --file <payouts.csv> [--out <plan.json>] [--fx <usd_to_ada>] [--ada-ledger <out.csv>]");
    return 2;
}

if (args.Length == 0) return Usage();

var mode = args[0];
var dict = ParseArgs(args.Skip(1).ToArray());

switch (mode)
{
    case "csv":
        if (!dict.TryGetValue("--file", out var file)) return Usage();
        dict.TryGetValue("--out", out var outPath);
        dict.TryGetValue("--fx", out var fxStr);
        dict.TryGetValue("--ada-ledger", out var ledgerOut);
        decimal? fx = null;
        if (!string.IsNullOrWhiteSpace(fxStr) && decimal.TryParse(fxStr, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var fxVal)) fx = fxVal;
        await RunPlan(new FileInfo(file), outPath == null ? null : new FileInfo(outPath), fx, ledgerOut == null ? null : new FileInfo(ledgerOut));
        return 0;
    default:
        return Usage();
}

static Dictionary<string, string> ParseArgs(string[] a)
{
    var d = new Dictionary<string, string>();
    for (int i = 0; i < a.Length; i++)
    {
        var k = a[i];
        if (!k.StartsWith("--")) continue;
        if (i + 1 < a.Length && !a[i + 1].StartsWith("--")) { d[k] = a[i + 1]; i++; }
        else d[k] = "true";
    }
    return d;
}

static async Task RunPlan(FileInfo csvFile, FileInfo? outFile, decimal? fx = null, FileInfo? adaLedgerOut = null)
{
    var text = await File.ReadAllTextAsync(csvFile.FullName);
    var rows = ParseCsv(text);
    if (rows.Count == 0) { Console.WriteLine("No rows"); return; }

    // Map headers
    var header = rows[0];
    var data = rows.Skip(1).Where(r => r.Count > 0 && r.Any(c => !string.IsNullOrWhiteSpace(c))).ToList();

    int idxAddr = IndexOf(header, new[] { "wallet_address", "address", "addr" });
    int idxUnits = IndexOf(header, new[] { "tokens_held", "units" });
    int idxShare = IndexOf(header, new[] { "pro_rata_share", "share" });
    int idxUsd = IndexOf(header, new[] { "payout_amount_usd", "usd", "amount_usd" });

    if (idxAddr < 0 || idxUsd < 0)
        throw new InvalidOperationException("CSV must include wallet_address/address and payout_amount_usd/usd");

    decimal total = 0m;
    var ledgerRows = new List<(string addr, decimal ada, long lovelace)>();
    var plan = new List<object>();
    foreach (var r in data)
    {
        var addr = Get(r, idxAddr);
        var units = idxUnits >= 0 ? Get(r, idxUnits) : string.Empty;
        var share = idxShare >= 0 ? Get(r, idxShare) : string.Empty;
        var usdStr = Get(r, idxUsd);
        if (!decimal.TryParse(usdStr, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var usd)) usd = 0m;
        total += usd;
        Console.WriteLine($"{addr}, USD {usd:F2}, units={units}, share={share}");
        plan.Add(new { wallet_address = addr, tokens_held = units, pro_rata_share = share, payout_amount_usd = usd });

        if (fx.HasValue && fx.Value > 0m)
        {
            var ada = usd * fx.Value;
            var lovelace = (long)Math.Round(ada * 1_000_000m, MidpointRounding.AwayFromZero);
            if (lovelace > 0) ledgerRows.Add((addr, ada, lovelace));
        }
    }
    Console.WriteLine($"TOTAL USD: {total:F2}");
    Console.WriteLine("Export this plan to your USDC/USD payment processor.");

    if (outFile != null)
    {
        outFile.Directory?.Create();
        var json = JsonSerializer.Serialize(new { total_usd = total, rows = plan }, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(outFile.FullName, json);
        Console.WriteLine($"Wrote plan: {outFile.FullName}");
    }

    if (adaLedgerOut != null && ledgerRows.Count > 0)
    {
        adaLedgerOut.Directory?.Create();
        var sb = new StringBuilder();
        sb.AppendLine("wallet_address,ada,lovelace");
        foreach (var row in ledgerRows)
        {
            sb.Append(row.addr);
            sb.Append(',');
            sb.Append(row.ada.ToString("F6", System.Globalization.CultureInfo.InvariantCulture));
            sb.Append(',');
            sb.Append(row.lovelace.ToString(System.Globalization.CultureInfo.InvariantCulture));
            sb.AppendLine();
        }
        await File.WriteAllTextAsync(adaLedgerOut.FullName, sb.ToString());
        Console.WriteLine($"Wrote ADA ledger: {adaLedgerOut.FullName}");
    }
}

static int IndexOf(List<string> header, string[] candidates)
{
    for (int i = 0; i < header.Count; i++)
    {
        var h = header[i].Trim().ToLowerInvariant();
        if (candidates.Any(c => c == h)) return i;
    }
    return -1;
}

static string Get(List<string> row, int idx) => idx >= 0 && idx < row.Count ? row[idx].Trim() : string.Empty;

static List<List<string>> ParseCsv(string text)
{
    // Basic CSV parser with quotes; LF/CRLF normalized
    var s = text.Replace("\r\n", "\n").Replace("\r", "\n");
    var rows = new List<List<string>>();
    var cur = new List<string>();
    var sb = new StringBuilder();
    bool inQuotes = false;

    for (int i = 0; i < s.Length; i++)
    {
        var ch = s[i];
        if (inQuotes)
        {
            if (ch == '"')
            {
                if (i + 1 < s.Length && s[i + 1] == '"') { sb.Append('"'); i++; }
                else { inQuotes = false; }
            }
            else sb.Append(ch);
        }
        else
        {
            if (ch == '"') inQuotes = true;
            else if (ch == ',') { cur.Add(sb.ToString()); sb.Clear(); }
            else if (ch == '\n') { cur.Add(sb.ToString()); sb.Clear(); rows.Add(cur); cur = new List<string>(); }
            else sb.Append(ch);
        }
    }
    cur.Add(sb.ToString());
    rows.Add(cur);

    // Trim trailing empty last line
    if (rows.Count > 0 && rows[^1].Count == 1 && string.IsNullOrWhiteSpace(rows[^1][0])) rows.RemoveAt(rows.Count - 1);

    // Trim whitespace around fields
    foreach (var r in rows)
        for (int i = 0; i < r.Count; i++) r[i] = r[i].Trim();

    return rows;
}
