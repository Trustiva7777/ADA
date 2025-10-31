using System.Text.Json;

static int Usage()
{
    Console.Error.WriteLine("Usage:");
    Console.Error.WriteLine("  dotnet run --project tools/LockSlotPlan -- plan [--days <n>] [--from <ISO8601>] [--current-slot <n>] [--slot-rate <slots_per_second>] [--out <file>]");
    return 2;
}

if (args.Length == 0) return Usage();

var cmd = args[0];
var dict = ParseArgs(args.Skip(1).ToArray());

switch (cmd)
{
    case "plan":
        int days = GetInt(dict, "--days", 45);
        var fromStr = Get(dict, "--from");
        var now = DateTimeOffset.UtcNow;
        if (!string.IsNullOrWhiteSpace(fromStr))
        {
            if (!DateTimeOffset.TryParse(fromStr, out now))
            {
                Console.Error.WriteLine("Invalid --from; expected ISO8601, e.g. 2025-10-30T12:00:00Z");
                return 2;
            }
        }
        var target = now.AddDays(days);
        long? currentSlot = GetLongNullable(dict, "--current-slot");
        double slotRate = GetDouble(dict, "--slot-rate", 1.0);
        long? beforeSlot = null;
        if (currentSlot.HasValue)
        {
            var seconds = (target - now).TotalSeconds;
            var delta = seconds * slotRate;
            beforeSlot = currentSlot + (long)Math.Round(delta, MidpointRounding.AwayFromZero);
        }
        var outPath = Get(dict, "--out");
        var payload = new
        {
            now = now.ToString("o"),
            days,
            target = target.ToString("o"),
            slotRate,
            currentSlot = currentSlot,
            approxBeforeSlot = beforeSlot
        };
        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
        if (!string.IsNullOrWhiteSpace(outPath))
        {
            var f = new FileInfo(outPath);
            f.Directory?.Create();
            File.WriteAllText(f.FullName, json);
            Console.WriteLine($"Wrote: {f.FullName}");
            // If we computed an approx before-slot, also write a plain-text helper file.
            if (beforeSlot.HasValue)
            {
                var outDir = f.Directory?.FullName ?? Directory.GetCurrentDirectory();
                var helperPath = Path.Combine(outDir, "lock_plan.beforeSlot");
                File.WriteAllText(helperPath, beforeSlot.Value.ToString() + Environment.NewLine);
                Console.WriteLine($"Wrote {helperPath}");
            }
        }
        else
        {
            Console.WriteLine(json);
        }
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

static string? Get(Dictionary<string, string> d, string k) => d.TryGetValue(k, out var v) ? v : null;
static int GetInt(Dictionary<string, string> d, string k, int def)
{
    if (d.TryGetValue(k, out var v) && int.TryParse(v, out var n)) return n;
    return def;
}
static double GetDouble(Dictionary<string, string> d, string k, double def)
{
    if (d.TryGetValue(k, out var v) && double.TryParse(v, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var n)) return n;
    return def;
}
static long? GetLongNullable(Dictionary<string, string> d, string k)
{
    if (d.TryGetValue(k, out var v) && long.TryParse(v, out var n)) return n;
    return null;
}
