using System.Text;
using System.Text.Json;
using System.Security.Cryptography;

using PeterO.Cbor;
using Blake2Core;

internal static class Program
{
    private static async Task<int> Main(string[] args)
    {
        if (args.Length == 0 || args[0] is "-h" or "--help")
        {
            PrintHelp();
            return 0;
        }

        var cmd = args[0];
        var rest = args.Skip(1).ToArray();

        switch (cmd)
        {
            case "policy-script":
                await HandlePolicyScript(rest);
                break;
            case "policy-id":
                await HandlePolicyId(rest);
                break;
            case "mint-plan":
                await HandleMintPlan(rest);
                break;
            case "lock-plan":
                await HandleLockPlan();
                break;
            default:
                Console.Error.WriteLine($"Unknown command: {cmd}\n");
                PrintHelp();
                return 1;
        }

        return 0;
    }

    private static void PrintHelp()
    {
        Console.WriteLine("MintTool — plan native token mint (unsigned, offline-signable)\n");
        Console.WriteLine("Commands:");
        Console.WriteLine("  policy-script --key-hash <hex> [--before-slot <n>] --out <path>");
        Console.WriteLine("  policy-id --from <script.json>");
        Console.WriteLine("  mint-plan --policy-id <hex> --asset-name <ascii> --amount <n> --doc-cid <ipfs://CID> --attestation <path> [--decimals <n>] [--network Mainnet|Preprod|Preview] [--inputs-template <path>] --change-address <addr> [--out-dir <dir>]");
        Console.WriteLine("  lock-plan");
        Console.WriteLine();
    }

    private static async Task HandlePolicyScript(string[] args)
    {
        var keyHash = GetOption(args, "--key-hash");
        if (string.IsNullOrWhiteSpace(keyHash)) throw new ArgumentException("Missing --key-hash");
        var outPath = GetOption(args, "--out");
        if (string.IsNullOrWhiteSpace(outPath)) throw new ArgumentException("Missing --out");
        long? before = TryGetLong(args, "--before-slot");

        NativeScript script = before.HasValue
            ? new NativeScript(
                all: new object[] { new { type = "sig", keyHash }, new { type = "before", slot = before.Value } },
                type: "all")
            : new NativeScript(type: "sig", keyHash: keyHash);

        await Io.WriteJsonAsync(outPath, script);
        Console.WriteLine("Next: compute policyId on your signer box:");
        Console.WriteLine($"  cardano-cli transaction policyid --script-file {outPath} > {Path.GetDirectoryName(outPath)}/policy.id");
    }

    private static async Task HandleMintPlan(string[] args)
    {
        var policyId = GetOption(args, "--policy-id") ?? throw new ArgumentException("--policy-id required");
        var assetName = GetOption(args, "--asset-name") ?? throw new ArgumentException("--asset-name required");
        var amount = long.Parse(GetOption(args, "--amount") ?? throw new ArgumentException("--amount required"));
        var decimals = (int)(TryGetLong(args, "--decimals") ?? 0);
        var docCid = GetOption(args, "--doc-cid") ?? throw new ArgumentException("--doc-cid required");
        var attestation = GetOption(args, "--attestation") ?? throw new ArgumentException("--attestation required");
        var network = GetOption(args, "--network") ?? "Preprod";
        var inputsTemplate = GetOption(args, "--inputs-template") ?? "chains/cardano/out/mint/inputs.template.json";
        var changeAddr = GetOption(args, "--change-address") ?? throw new ArgumentException("--change-address required");
        var outDir = GetOption(args, "--out-dir") ?? "chains/cardano/out/mint";

        Directory.CreateDirectory(outDir);
        string assetHex = BitConverter.ToString(Encoding.UTF8.GetBytes(assetName)).Replace("-", "").ToLowerInvariant();
        var meta = new MintPlanMeta(policyId, assetHex, amount, decimals.ToString(), docCid, attestation, network);

        var unsignedPlanPath = Path.Combine(outDir, "mint_unsigned.plan.json");
        var signerReadmePath = Path.Combine(outDir, "README_SIGNER.txt");

        var txObj = new
        {
            network,
            mint = new[] { new { policyId, assetNameHex = assetHex, quantity = amount } },
            metadata = new
            {
                label_674 = new { attestation, doc = docCid, decimals, name = assetName }
            },
            inputs = new[] { new { txHash = "<FILL>", index = 0, lovelace = 0L } },
            change = new { address = changeAddr, minLovelace = 1_500_000L }
        };

        await Io.WriteJsonAsync(inputsTemplate, new[] { new { txHash = "<FILL>", index = 0, lovelace = 0L } });
        await Io.WriteJsonAsync(unsignedPlanPath, txObj);
        await Io.WriteJsonAsync(Path.Combine(outDir, "mint_plan.meta.json"), meta);

        var netFlag = network.Equals("Mainnet", StringComparison.OrdinalIgnoreCase) ? "--mainnet" : "--testnet-magic 1";
        var sb = new StringBuilder();
        sb.AppendLine("# Signer steps (offline, air-gapped)");
        sb.AppendLine("# 1) Have on signer:");
        sb.AppendLine("#    - policy.script.json  (and the matching policy.skey)");
        sb.AppendLine($"#    - {Path.GetFileName(inputsTemplate)}  (fill UTxOs)");
        sb.AppendLine($"#    - {Path.GetFileName(unsignedPlanPath)} (this file)");
        sb.AppendLine("# 2) Build body (example using cardano-cli; adjust paths):");
        sb.AppendLine("cardano-cli transaction build-raw \\");
        sb.AppendLine("  --alonzo-era \\");
        sb.AppendLine("  --fee 0 \\");
        sb.AppendLine("  --tx-in <TXHASH>#<IX> \\");
        sb.AppendLine($"  --tx-out {changeAddr}+<CHANGE_LOVELACE> \\");
        sb.AppendLine($"  --mint=\"{amount} {policyId}.{assetHex}\" \\");
        sb.AppendLine("  --minting-script-file policy.script.json \\");
        sb.AppendLine("  --metadata-json-file metadata.json \\");
        sb.AppendLine("  --out-file mint.body");
        sb.AppendLine();
        sb.AppendLine("# 3) Create metadata.json for label 674:");
        sb.AppendLine("cat > metadata.json <<EOF");
        sb.AppendLine("{");
        sb.AppendLine("  \"674\": {");
        sb.AppendLine($"    \"attestation\": \"{attestation}\",");
        sb.AppendLine($"    \"doc\": \"{docCid}\",");
        sb.AppendLine($"    \"decimals\": {decimals},");
        sb.AppendLine($"    \"name\": \"{assetName}\"");
        sb.AppendLine("  }");
        sb.AppendLine("}");
        sb.AppendLine("EOF");
        sb.AppendLine();
        sb.AppendLine("# 4) Calculate fee & adjust outputs (recommended to use build instead of build-raw in practice)");
        sb.AppendLine($"#    Or rebuild with `transaction build` using {netFlag} and --change-address");
        sb.AppendLine();
        sb.AppendLine("# 5) Sign:");
        sb.AppendLine("cardano-cli transaction sign \\");
        sb.AppendLine($"  {netFlag} \\");
        sb.AppendLine("  --tx-body-file mint.body \\");
        sb.AppendLine("  --signing-key-file policy.skey \\");
        sb.AppendLine("  --out-file mint.signed");
        sb.AppendLine();
        sb.AppendLine("# 6) Submit (on relay host):");
        sb.AppendLine("curl -sS -X POST \"$SUBMIT_API/api/tx/submit\" -H 'Content-Type: application/cbor' --data-binary @mint.signed");

        Io.EnsureDir(signerReadmePath);
        await File.WriteAllTextAsync(signerReadmePath, sb.ToString());
        Console.WriteLine($"Unsigned plan: {unsignedPlanPath}");
        Console.WriteLine($"Inputs template: {inputsTemplate}");
        Console.WriteLine($"Signer README: {signerReadmePath}");
    }

    private static async Task HandleLockPlan()
    {
        var path = "chains/cardano/out/mint/LOCK_POLICY_README.txt";
        Io.EnsureDir(path);
        await File.WriteAllTextAsync(path, "If your policy.script.json uses a 'before' timelock, it becomes unusable for minting after that slot.\nBest practice: finish mint(s) before the deadline, then archive keys. There is no separate on-chain 'lock' tx for native scripts.");
        Console.WriteLine($"Wrote: {path}");
    }

    private static async Task HandlePolicyId(string[] args)
    {
        var scriptPath = GetOption(args, "--from");
        if (string.IsNullOrWhiteSpace(scriptPath)) throw new ArgumentException("--from required");

        var json = await File.ReadAllTextAsync(scriptPath);
        var scriptObj = JsonSerializer.Deserialize<object>(json);
        var cbor = CBORObject.FromObject(scriptObj).EncodeToBytes();
        var config = new Blake2Core.Blake2BConfig { OutputSizeInBytes = 28 };
        var hash = Blake2Core.Blake2B.ComputeHash(cbor, config);
        var policyId = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
        Console.WriteLine($"PolicyId: {policyId}");
    }

    private static string? GetOption(string[] args, string name)
    {
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (args[i] == name)
            {
                return args[i + 1];
            }
        }
        return null;
    }

    private static long? TryGetLong(string[] args, string name)
    {
        var v = GetOption(args, name);
        if (string.IsNullOrWhiteSpace(v)) return null;
        if (long.TryParse(v, out var n)) return n;
        throw new ArgumentException($"Invalid number for {name}: {v}");
    }
}

internal static class Io
{
    public static void EnsureDir(string path)
    {
        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(dir)) Directory.CreateDirectory(dir!);
    }

    public static async Task WriteJsonAsync<T>(string path, T obj)
    {
        EnsureDir(path);
        var json = JsonSerializer.Serialize(obj, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(path, json);
        Console.WriteLine($"Wrote: {path}");
    }
}

internal record NativeScript(object[]? all = null, object[]? any = null, object? atLeast = null, object? before = null, string? keyHash = null, string? type = null);

internal record MintPlanMeta(string policyId, string assetNameHex, long amount, string decimals, string docCid, string attestationPath, string network);

internal record MintPlan(
    MintPlanMeta meta,
    string inputsTemplatePath,
    string changeAddress,
    string unsignedPlanPath,
    string signerReadmePath,
    object tx);
