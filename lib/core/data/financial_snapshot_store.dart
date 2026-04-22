import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class FinancialSnapshotStore {
  Future<String?> read();

  Future<void> write(String snapshot);
}

class SecureStorageSnapshotStore implements FinancialSnapshotStore {
  const SecureStorageSnapshotStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    this.storageKey = 'financial_snapshot',
  }) : _storage = storage;

  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<String?> read() {
    return _storage.read(key: storageKey);
  }

  @override
  Future<void> write(String snapshot) {
    return _storage.write(key: storageKey, value: snapshot);
  }
}
