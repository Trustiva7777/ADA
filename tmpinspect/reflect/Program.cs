using System.Reflection;

var asmPath = "/root/.nuget/packages/cardanosharp.wallet/4.0.0/lib/netstandard2.1/CardanoSharp.Wallet.dll";
var asm = Assembly.LoadFile(asmPath);
Console.WriteLine("Types containing Service/Mnemonic/Address/Wallet:");
var tWalletService = asm.GetType("CardanoSharp.Wallet.WalletService");
var tAddressService = asm.GetType("CardanoSharp.Wallet.AddressService");
var tMnemonicService = asm.GetType("CardanoSharp.Wallet.MnemonicService");
var tWalletPath = asm.GetType("CardanoSharp.Wallet.Models.WalletPath");
var tMnemonicExt = asm.GetType("CardanoSharp.Wallet.Extensions.Models.MnemonicExtensions");
var tPrivateKeyExt = asm.GetType("CardanoSharp.Wallet.Extensions.Models.PrivateKeyExtensions");
var tPublicKeyExt = asm.GetType("CardanoSharp.Wallet.Extensions.Models.PublicKeyExtensions");

foreach (var t in new[]{tWalletService, tAddressService, tMnemonicService, tWalletPath, tMnemonicExt, tPrivateKeyExt, tPublicKeyExt})
{
    if (t == null) continue;
    Console.WriteLine($"\n{t.FullName}");
    foreach (var m in t.GetMethods(BindingFlags.Public|BindingFlags.Instance|BindingFlags.Static|BindingFlags.DeclaredOnly))
    {
        Console.WriteLine("  - "+m.Name+"("+string.Join(", ", m.GetParameters().Select(p => p.ParameterType.Name+" "+p.Name))+ ") : "+ m.ReturnType.Name);
    }
}