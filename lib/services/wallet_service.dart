import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart' show bytesToHex, hexToBytes;
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
    final raw = await tokenBalance(AppConfig.usdc, address);
    return raw == null ? null : raw.toDouble() / 1e6;
  }

  /// Raw ERC-20 / B20 balance (no decimals applied).
  Future<BigInt?> tokenBalance(String token, String address) async {
    try {
      final data = '0x70a08231${_word(address)}';
      final res = await _rpc('eth_call', [
        {'to': token, 'data': data},
        'latest'
      ]) as String?;
      if (res == null || res == '0x') return BigInt.zero;
      return BigInt.parse(res.substring(2), radix: 16);
    } catch (_) {
      return null;
    }
  }

  /// ETH balance in wei.
  Future<BigInt> ethBalance(String address) async {
    final res = await _rpc('eth_getBalance', [address, 'latest']) as String;
    return BigInt.parse(res.substring(2), radix: 16);
  }

  /// Signs and sends a transaction from the device wallet. Returns the hash.
  Future<String> send({required String to, required String data, BigInt? value, int? gas}) async {
    final cred = await _load();
    if (cred == null) throw StateError('Create your wallet first.');
    final client = Web3Client(AppConfig.rpcUrl, http.Client());
    try {
      return await client.sendTransaction(
        cred,
        Transaction(
          to: EthereumAddress.fromHex(to),
          data: hexToBytes(data),
          value: EtherAmount.inWei(value ?? BigInt.zero),
          maxGas: gas,
        ),
        chainId: AppConfig.chainId,
      );
    } finally {
      client.dispose();
    }
  }

  /// ERC-20 approve(spender, amount).
  Future<String> approve(String token, String spender, BigInt amount) =>
      send(to: token, data: '0x095ea7b3${_word(spender)}${amount.toRadixString(16).padLeft(64, '0')}', gas: 90000);

  /// Waits for a transaction to be mined. Returns true if it succeeded.
  Future<bool> waitFor(String hash, {Duration timeout = const Duration(seconds: 90)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final r = await _rpc('eth_getTransactionReceipt', [hash]);
      if (r is Map && r['status'] != null) return r['status'] == '0x1';
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    throw TimeoutException('The network is slow. Check the transaction on Basescan.');
  }

  static String _word(String address) => address.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final r = await http
        .post(Uri.parse(AppConfig.rpcUrl),
            headers: {'content-type': 'application/json'}, body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}))
        .timeout(const Duration(seconds: 20));
    final j = jsonDecode(r.body);
    if (j['error'] != null) throw StateError('${j['error']['message'] ?? 'RPC error'}');
    return j['result'];
  }
}
