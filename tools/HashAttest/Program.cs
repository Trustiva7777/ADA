using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
static int Usage()
{
    Console.Error.WriteLine("Usage:");
    Console.Error.WriteLine("  dotnet run --project tools/HashAttest -- manifest --dir <dir> --out <file> [--ignore <names>]");
    Console.Error.WriteLine("  dotnet run --project tools/HashAttest -- hash --file <file> --out <file>");
    Console.Error.WriteLine("  dotnet run --project tools/HashAttest -- attest --policy <policyId> --network <Preprod|Mainnet> --manifest <file> --out <file> [--policy-json <file>] [--before-slot <n>] [--allowlist-sha <sha256>] [--allowlist-file <csv|json>] [--compliance-url <url>]");
    Console.Error.WriteLine("  dotnet run --project tools/HashAttest -- allowhash --file <csv|json> --out <file>");
    return 2;
}

if (args.Length == 0) return Usage();

var mode = args[0];
var argDict = ParseArgs(args.Skip(1).ToArray());

switch (mode)
{
    case "manifest":
        {
            if (!argDict.TryGetValue("--dir", out var dirStr) || !argDict.TryGetValue("--out", out var outStr))
                return Usage();
            var ignore = argDict.TryGetValue("--ignore", out var ig) ? ig : ".git,node_modules,dist,bin,obj";
            await RunManifest(new DirectoryInfo(dirStr), new FileInfo(outStr), ignore);
            return 0;
        }
    case "attest":
        {
            if (!argDict.TryGetValue("--policy", out var policy) || !argDict.TryGetValue("--network", out var network) || !argDict.TryGetValue("--manifest", out var manifest) || !argDict.TryGetValue("--out", out var outFile))
                return Usage();
            argDict.TryGetValue("--allowlist-sha", out var allowSha);
            argDict.TryGetValue("--compliance-url", out var compUrl);
            argDict.TryGetValue("--policy-json", out var policyJson);
            argDict.TryGetValue("--before-slot", out var beforeSlot);
            argDict.TryGetValue("--allowlist-file", out var allowFile);
            await RunAttest(policy, network, new FileInfo(manifest), new FileInfo(outFile), allowSha, compUrl, policyJson, beforeSlot, allowFile);
            return 0;
        }
    case "hash":
        {
            if (!argDict.TryGetValue("--file", out var file) || !argDict.TryGetValue("--out", out var outFile)) return Usage();
            await RunHash(new FileInfo(file), new FileInfo(outFile));
            return 0;
        }
    case "allowhash":
        {
            if (!argDict.TryGetValue("--file", out var file) || !argDict.TryGetValue("--out", out var outFile)) return Usage();
            await RunAllowlistHash(new FileInfo(file), new FileInfo(outFile));
            return 0;
        }
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
        if (i + 1 < a.Length && !a[i + 1].StartsWith("--"))
        {
            d[k] = a[i + 1];
            i++;
        }
        else
        {
            d[k] = "true";
        }
    }
    return d;
}

static async Task RunManifest(DirectoryInfo dir, FileInfo of, string ignoreCsv)
{
    var ignoreSet = new HashSet<string>(ignoreCsv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    var files = new List<FileInfo>();
    void Walk(DirectoryInfo d)
    {
        foreach (var sub in d.EnumerateDirectories())
        {
            if (ignoreSet.Contains(sub.Name)) continue;
            Walk(sub);
        }
        foreach (var f in d.EnumerateFiles()) files.Add(f);
    }
    Walk(dir);

    long totalBytes = 0;
    var entries = new List<ManifestEntry>();
    foreach (var f in files)
    {
        using var sha = SHA256.Create();
        await using var stream = f.OpenRead();
        var hash = await sha.ComputeHashAsync(stream);
        var hex = Convert.ToHexString(hash).ToLowerInvariant();
        totalBytes += f.Length;
        var rel = Path.GetRelativePath(dir.FullName, f.FullName);
        entries.Add(new ManifestEntry { Path = rel, Size = f.Length, Sha256 = hex });
    }
    entries.Sort((a, b) => string.CompareOrdinal(a.Path, b.Path));
    var manifest = new ManifestFile
    {
        GeneratedAt = DateTimeOffset.UtcNow.ToString("o"),
        RootDir = dir.Name,
        Ignore = ignoreSet.ToArray(),
        Entries = entries,
        Totals = new Totals { Files = entries.Count, Bytes = totalBytes }
    };

    of.Directory?.Create();
    var json = JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true });
    await File.WriteAllTextAsync(of.FullName, json);
    Console.WriteLine($"Wrote manifest: {of.FullName}");
    Console.WriteLine($"Files: {manifest.Totals.Files}, Bytes: {manifest.Totals.Bytes}");
}

static async Task RunAttest(string policy, string network, FileInfo manifestFile, FileInfo outFile, string? allowSha, string? complianceUrl, string? policyJsonPath, string? beforeSlot, string? allowlistFile)
{
    var raw = await File.ReadAllTextAsync(manifestFile.FullName);
    var manifest = JsonSerializer.Deserialize<ManifestFile>(raw) ?? throw new InvalidOperationException("Bad manifest JSON");
    string manifestSha;
    using (var sha = SHA256.Create())
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(raw);
        var hash = sha.ComputeHash(bytes);
        manifestSha = Convert.ToHexString(hash).ToLowerInvariant();
    }

    string? policySha = null;
    string? policyJsonRel = null;
    if (!string.IsNullOrWhiteSpace(policyJsonPath))
    {
        var p = new FileInfo(policyJsonPath);
        var rawPolicy = await File.ReadAllBytesAsync(p.FullName);
        using var s = SHA256.Create();
        policySha = Convert.ToHexString(s.ComputeHash(rawPolicy)).ToLowerInvariant();
        policyJsonRel = Path.GetRelativePath(Directory.GetCurrentDirectory(), p.FullName);
    }

    // If an allowlist file is provided, compute its canonical sha; if also allowSha provided, prefer explicit allowSha
    if (!string.IsNullOrWhiteSpace(allowlistFile) && string.IsNullOrWhiteSpace(allowSha))
    {
        try
        {
            var (canon, rawAllow) = await ComputeAllowlistHashes(new FileInfo(allowlistFile));
            allowSha = canon ?? rawAllow; // prefer canonical if available
        }
        catch
        {
            // ignore and leave allowSha as null
        }
    }

    var attestation = new
    {
        series = "QH-R1",
        network,
        policyId = policy,
        timestamp = DateTimeOffset.UtcNow.ToString("o"),
        policyJson = policySha == null ? null : new { path = policyJsonRel, sha256 = policySha },
        lockInfo = string.IsNullOrWhiteSpace(beforeSlot) ? null : new { beforeSlot = long.Parse(beforeSlot) },
        proofs = new
        {
            manifest = new
            {
                path = Path.GetRelativePath(Directory.GetCurrentDirectory(), manifestFile.FullName),
                sha256 = manifestSha,
                totals = manifest.Totals,
                generatedAt = manifest.GeneratedAt,
            },
            allowlistSnapshotSha256 = string.IsNullOrWhiteSpace(allowSha) ? null : allowSha,
        },
        compliance = new
        {
            url = string.IsNullOrWhiteSpace(complianceUrl) ? Environment.GetEnvironmentVariable("COMPLIANCE_URL") : complianceUrl
        },
        build = new { tool = "HashAttest 1.0 (.NET)" }
    };

    outFile.Directory?.Create();
    var json = JsonSerializer.Serialize(attestation, new JsonSerializerOptions { WriteIndented = true });
    await File.WriteAllTextAsync(outFile.FullName, json);
    Console.WriteLine($"Wrote attestation: {outFile.FullName}");
}

static async Task RunHash(FileInfo file, FileInfo outFile)
{
    using var sha = SHA256.Create();
    await using var stream = file.OpenRead();
    var hash = await sha.ComputeHashAsync(stream);
    var hex = Convert.ToHexString(hash).ToLowerInvariant();
    var payload = new { file = file.Name, path = file.FullName, sha256 = hex, size = file.Length };
    outFile.Directory?.Create();
    var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
    await File.WriteAllTextAsync(outFile.FullName, json);
    Console.WriteLine($"Wrote: {outFile.FullName}");
}

static async Task RunAllowlistHash(FileInfo file, FileInfo outFile)
{
    // Raw hash
    var rawBytes = await File.ReadAllBytesAsync(file.FullName);
    string rawSha;
    using (var sha = SHA256.Create()) rawSha = Convert.ToHexString(sha.ComputeHash(rawBytes)).ToLowerInvariant();

    // Canonical hash strategy based on extension
    string? canonicalAlgo = null;
    string? canonicalSha = null;
    string? notes = null;
    var ext = file.Extension.ToLowerInvariant();

    if (ext == ".csv")
    {
        // CSV canonicalization: keep first non-empty line as header; sort remaining non-empty lines lexicographically
        var text = await File.ReadAllTextAsync(file.FullName);
        var lines = text.Replace("\r\n", "\n").Replace("\r", "\n").Split('\n');
        var nonEmpty = lines.Where(l => !string.IsNullOrWhiteSpace(l)).ToList();
        if (nonEmpty.Count > 0)
        {
            var header = nonEmpty[0].Trim();
            var rows = nonEmpty.Skip(1).Select(l => l.Trim()).Where(l => l.Length > 0).ToList();
            rows.Sort(StringComparer.Ordinal);
            var canonical = string.Join('\n', new[] { header }.Concat(rows)) + "\n";
            using var sha = SHA256.Create();
            canonicalSha = Convert.ToHexString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
            canonicalAlgo = "csv-sort";
            notes = "Header preserved; rows trimmed and lexicographically sorted; LF newlines";
        }
    }
    else if (ext == ".json")
    {
        // JSON canonicalization: sort object properties recursively; arrays keep order
        try
        {
            var json = await File.ReadAllTextAsync(file.FullName);
            using var doc = JsonDocument.Parse(json);
            var canonical = CanonicalizeJson(doc.RootElement);
            using var sha = SHA256.Create();
            canonicalSha = Convert.ToHexString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
            canonicalAlgo = "json-sort";
            notes = "Object properties sorted recursively; arrays kept as-is; UTF-8 minified";
        }
        catch
        {
            // fallback: no canonical
        }
    }

    var payload = new
    {
        file = file.Name,
        path = file.FullName,
        size = file.Length,
        rawSha256 = rawSha,
        canonical = canonicalSha == null ? null : new { algorithm = canonicalAlgo, sha256 = canonicalSha, notes }
    };
    outFile.Directory?.Create();
    var outJson = JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
    await File.WriteAllTextAsync(outFile.FullName, outJson);
    Console.WriteLine($"Wrote: {outFile.FullName}");
}

static async Task<(string? canonicalSha, string rawSha)> ComputeAllowlistHashes(FileInfo file)
{
    var rawBytes = await File.ReadAllBytesAsync(file.FullName);
    string rawSha;
    using (var sha = SHA256.Create()) rawSha = Convert.ToHexString(sha.ComputeHash(rawBytes)).ToLowerInvariant();

    string? canonicalSha = null;
    var ext = file.Extension.ToLowerInvariant();
    if (ext == ".csv")
    {
        var text = await File.ReadAllTextAsync(file.FullName);
        var lines = text.Replace("\r\n", "\n").Replace("\r", "\n").Split('\n');
        var nonEmpty = lines.Where(l => !string.IsNullOrWhiteSpace(l)).ToList();
        if (nonEmpty.Count > 0)
        {
            var header = nonEmpty[0].Trim();
            var rows = nonEmpty.Skip(1).Select(l => l.Trim()).Where(l => l.Length > 0).ToList();
            rows.Sort(StringComparer.Ordinal);
            var canonical = string.Join('\n', new[] { header }.Concat(rows)) + "\n";
            using var sha = SHA256.Create();
            canonicalSha = Convert.ToHexString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
        }
    }
    else if (ext == ".json")
    {
        try
        {
            var json = await File.ReadAllTextAsync(file.FullName);
            using var doc = JsonDocument.Parse(json);
            var canonical = CanonicalizeJson(doc.RootElement);
            using var sha = SHA256.Create();
            canonicalSha = Convert.ToHexString(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
        }
        catch { }
    }
    return (canonicalSha, rawSha);
}

static string CanonicalizeJson(JsonElement el)
{
    switch (el.ValueKind)
    {
        case JsonValueKind.Object:
            var props = el.EnumerateObject().OrderBy(p => p.Name, StringComparer.Ordinal).ToList();
            var parts = new List<string>(props.Count);
            foreach (var p in props)
            {
                parts.Add("\"" + EscapeJson(p.Name) + "\":" + CanonicalizeJson(p.Value));
            }
            return "{" + string.Join(',', parts) + "}";
        case JsonValueKind.Array:
            var arr = el.EnumerateArray().Select(CanonicalizeJson);
            return "[" + string.Join(',', arr) + "]";
        case JsonValueKind.String:
            return "\"" + EscapeJson(el.GetString() ?? string.Empty) + "\"";
        case JsonValueKind.Number:
            return el.GetRawText();
        case JsonValueKind.True:
        case JsonValueKind.False:
        case JsonValueKind.Null:
            return el.GetRawText();
        default:
            return el.GetRawText();
    }
}

static string EscapeJson(string s)
{
    return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r").Replace("\t", "\\t");
}

record ManifestEntry
{
    [JsonPropertyName("path")] public string Path { get; init; } = string.Empty;
    [JsonPropertyName("size")] public long Size { get; init; }
    [JsonPropertyName("sha256")] public string Sha256 { get; init; } = string.Empty;
}

record Totals { [JsonPropertyName("files")] public int Files { get; init; } [JsonPropertyName("bytes")] public long Bytes { get; init; } }

record ManifestFile
{
    [JsonPropertyName("generatedAt")] public string GeneratedAt { get; init; } = string.Empty;
    [JsonPropertyName("rootDir")] public string RootDir { get; init; } = string.Empty;
    [JsonPropertyName("ignore")] public string[] Ignore { get; init; } = Array.Empty<string>();
    [JsonPropertyName("entries")] public List<ManifestEntry> Entries { get; init; } = new();
    [JsonPropertyName("totals")] public Totals Totals { get; init; } = new();
}
