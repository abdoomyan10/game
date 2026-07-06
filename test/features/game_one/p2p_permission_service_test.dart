import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/game_one/data/exceptions/p2p_exceptions.dart';
import 'package:game/features/game_one/data/services/p2p_permission_service.dart';
import 'package:game/features/game_one/domain/entities/p2p_permission.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakePermissionService extends P2pPermissionServiceImpl {
  _FakePermissionService(this._handler);

  final Future<bool> Function(Permission permission) _handler;

  @override
  Future<void> ensureGranted() async {
    final denied = <P2pPermission>[];

    if (!await _handler(Permission.locationWhenInUse)) {
      denied.add(P2pPermission.location);
    }

    if (!await _handler(Permission.bluetoothScan)) {
      denied.add(P2pPermission.bluetooth);
    }

    if (denied.isNotEmpty) {
      throw P2pPermissionException(
        message: 'يجب تفعيل Bluetooth والموقع للعب عبر الشبكة المحلية',
        denied: denied,
      );
    }
  }
}

void main() {
  test('ensureGranted throws when location permission denied', () async {
    final service = _FakePermissionService(
      (permission) async => permission != Permission.locationWhenInUse,
    );

    expect(
      () => service.ensureGranted(),
      throwsA(
        isA<P2pPermissionException>().having(
          (error) => error.denied,
          'denied',
          contains(P2pPermission.location),
        ),
      ),
    );
  });

  test('ensureGranted succeeds when required permissions granted', () async {
    final service = _FakePermissionService((_) async => true);

    await expectLater(service.ensureGranted(), completes);
  });
}
