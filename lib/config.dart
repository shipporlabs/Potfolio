/// Runtime configuration. Pass values with --dart-define, for example:
///   flutter run --dart-define=WORKER_URL=https://potfolio-api.<you>.workers.dev
///
/// Everything works without these: the app falls back to bundled stock lists,
/// an on-device Guardian and local storage ("demo mode").
class AppConfig {
  /// Cloudflare Worker base URL (no trailing slash).
  static const workerUrl = String.fromEnvironment('WORKER_URL');

  /// 'sepolia' (default, for the Stocksmaxxing demo) or 'mainnet'.
  static const network = String.fromEnvironment('BASE_NETWORK', defaultValue: 'sepolia');

  /// Public website, used for share links (https://<site>/p/<id>).
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://potfolio.xyz');

  static bool get hasWorker => workerUrl.isNotEmpty;
  static bool get isMainnet => network == 'mainnet';

  static String get rpcUrl => isMainnet ? 'https://mainnet.base.org' : 'https://sepolia.base.org';
  static String get explorer => isMainnet ? 'https://basescan.org' : 'https://sepolia.basescan.org';
  static String get networkName => isMainnet ? 'Base' : 'Base Sepolia';

  /// Circle USDC on Base / Base Sepolia.
  static String get usdc => isMainnet
      ? '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
      : '0x036CbD53842c5426634e7929541eC2318f3dCF7e';

  static int get chainId => isMainnet ? 8453 : 84532;

  /// Real buying and selling only exists on Base mainnet (tokenized stocks live there).
  static bool get tradingEnabled => isMainnet && hasWorker;

  static const tokenizedStocksApi = 'https://api.coinbase.com/v1/tokenized-stocks';
}
