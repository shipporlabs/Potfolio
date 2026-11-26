import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart' show bytesToHex;
import 'package:web3dart/web3dart.dart';

import '../config.dart';

/// A self-custody Base wallet created on the user's device.
/// The private key never leaves the device; only the address is stored in the cloud.
class WalletService {
  static const _key = 'potfolio_wallet_pk_v1';
  final FlutterSecureStorage _store = const FlutterSecureStorage();
  EthPrivateKey? _cred;

  Future<String?> address() async {
    final c = await _load();
    return c?.address.hexEip55;
  }

  Future<String> create() async {
    final existing = await _load();
    if (existing != null) return existing.address.hexEip55;
    final cred = EthPrivateKey.createRandom(Random.secure());
    await _store.write(key: _key, value: bytesToHex(cred.privateKey, include0x: true));
    _cred = cred;
    return cred.address.hexEip55;
  }

  /// Shown only after an explicit warning, for backup.
  Future<String?> exportPrivateKey() async => _store.read(key: _key);

  Future<void> forget() async {
    await _store.delete(key: _key);
    _cred = null;
  }

  Future<EthPrivateKey?> _load() async {
    if (_cred != null) return _cred;
    final hex = await _store.read(key: _key);
    if (hex == null || hex.isEmpty) return null;
    _cred = EthPrivateKey.fromHex(hex);
    return _cred;
  }

  /// USDC balance on Base via a plain JSON-RPC eth_call (balanceOf).
  Future<double?> usdcBalance(String address) async {
    try {
      final data = '0x70a08231${address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0')}';
      final r = await http
          .post(Uri.parse(AppConfig.rpcUrl),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'eth_call', 'params': [{'to': AppConfig.usdc, 'data': data}, 'latest']}))
          .timeout(const Duration(seconds: 15));
      final res = jsonDecode(r.body)['result'] as String?;
      if (res == null || res == '0x') return 0;
      return BigInt.parse(res.substring(2), radix: 16).toDouble() / 1e6;
    } catch (_) {
      return null;
    }
  }
}
