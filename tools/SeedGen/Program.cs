using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using CardanoSharp.Wallet;
using CardanoSharp.Wallet.Enums;
using CardanoSharp.Wallet.Extensions;
using CardanoSharp.Wallet.Extensions.Models;
using CardanoSharp.Wallet.Models.Addresses;
using CardanoSharp.Wallet.Models.Keys;
using CardanoSharp.Wallet.Utilities;

static string PromptHidden(string label)
{
    Console.Write($"{label}: ");
    var sb = new StringBuilder();
    ConsoleKeyInfo k;
    while ((k = Console.ReadKey(true)).Key != ConsoleKey.Enter)
    {
        if (k.Key == ConsoleKey.Backspace && sb.Length > 0) { sb.Length--; continue; }
        if (!char.IsControl(k.KeyChar)) sb.Append(k.KeyChar);
    }
    Console.WriteLine();
    return sb.ToString();
}

static (byte[] cipher, byte[] salt, byte[] nonce) EncryptAesGcm(byte[] plaintext, string passphrase)
{
    var salt = RandomNumberGenerator.GetBytes(16);
    using var kdf = new Rfc2898DeriveBytes(passphrase, salt, 200_000, HashAlgorithmName.SHA512);
    var key = kdf.GetBytes(32);
    var nonce = RandomNumberGenerator.GetBytes(12);
    var cipher = new byte[plaintext.Length];
    var tag = new byte[16];
    using var aesgcm = new AesGcm(key, 16);
    aesgcm.Encrypt(nonce, plaintext, cipher, tag);
    var withTag = new byte[cipher.Length + tag.Length];
    Buffer.BlockCopy(cipher, 0, withTag, 0, cipher.Length);
    Buffer.BlockCopy(tag, 0, withTag, cipher.Length, tag.Length);
    return (withTag, salt, nonce);
}

static void EnsureDirs(string root)
{
    Directory.CreateDirectory(Path.Combine(root, "mainnet"));
    Directory.CreateDirectory(Path.Combine(root, "preprod"));
    Directory.CreateDirectory(Path.Combine(root, "preview"));
}

var outRoot = "Cardano/Dev/Wallet";
string? passFromArg = null;
for (int i = 0; i + 1 < args.Length; i++)
{
    if (args[i] == "--out") outRoot = args[i + 1];
    if (args[i] == "--pass") passFromArg = args[i + 1];
}
EnsureDirs(outRoot);

// 1) Generate mnemonic
var ms = new MnemonicService();
var mnemonic = ms.Generate(24, WordLists.English);

// 2) Derive keys (CIP-1852: m/1852’/1815’/0’)
//    account(0) → payment: /0/0, stake: /2/0
var rootPrv = mnemonic.GetRootKey("");
var payPrv   = rootPrv.Derive("m/1852'/1815'/0'/0/0");
var stakePrv = rootPrv.Derive("m/1852'/1815'/0'/2/0");

var payPub   = payPrv.GetPublicKey(false);
var stakePub = stakePrv.GetPublicKey(false);

// 3) Addresses
var addrSvc = new AddressService();
string mainnetAddr = addrSvc.GetBaseAddress(payPub, stakePub, NetworkType.Mainnet).ToString();
string testAddr    = addrSvc.GetBaseAddress(payPub, stakePub, NetworkType.Testnet).ToString();

// 4) Write safe artifacts
File.WriteAllText(Path.Combine(outRoot, "mainnet", "addr_mainnet.txt"), mainnetAddr + Environment.NewLine);
File.WriteAllText(Path.Combine(outRoot, "preprod", "addr_preprod.txt"), testAddr + Environment.NewLine);
File.WriteAllText(Path.Combine(outRoot, "preview", "addr_preview.txt"), testAddr + Environment.NewLine);
File.WriteAllText(Path.Combine(outRoot, "pay.xpub"),   Convert.ToHexString(payPub.Key));
File.WriteAllText(Path.Combine(outRoot, "stake.xpub"), Convert.ToHexString(stakePub.Key));

// 5) Encrypt mnemonic (AES-256-GCM)
var envPass = Environment.GetEnvironmentVariable("SEEDGEN_PASSPHRASE");
string pass;
if (!string.IsNullOrEmpty(passFromArg))
{
    pass = passFromArg!;
}
else if (!string.IsNullOrEmpty(envPass))
{
    pass = envPass!;
}
else
{
    var p1 = PromptHidden("Enter encryption passphrase (store it safely)");
    var p2 = PromptHidden("Confirm passphrase");
    if (p1 != p2) { Console.Error.WriteLine("Passphrases do not match."); Environment.Exit(2); }
    pass = p1;
}

var (cipher, salt, nonce) = EncryptAesGcm(Encoding.UTF8.GetBytes(mnemonic.Words), pass);
var encObj = new {
    kdf="pbkdf2-sha512", rounds=200_000, cipherAlg="aes-256-gcm",
    salt=Convert.ToHexString(salt), nonce=Convert.ToHexString(nonce), data=Convert.ToHexString(cipher)
};
var encJson = JsonSerializer.Serialize(encObj, new JsonSerializerOptions{ WriteIndented=true });

foreach (var net in new[]{ "mainnet", "preprod", "preview" })
    File.WriteAllText(Path.Combine(outRoot, net, "seed.enc"), encJson);

// 6) Summary (no secrets)
Console.WriteLine("=== SeedGen summary (no secrets) ===");
Console.WriteLine($"Mainnet : {mainnetAddr}");
Console.WriteLine($"Preprod : {testAddr}");
Console.WriteLine($"Preview : {testAddr}");
Console.WriteLine($"pay.xpub   : {Convert.ToHexString(payPub.Key).ToLower()}");
Console.WriteLine($"stake.xpub : {Convert.ToHexString(stakePub.Key).ToLower()}");
Console.WriteLine($"Encrypted seed written under {outRoot}/(mainnet|preprod|preview)/seed.enc");
