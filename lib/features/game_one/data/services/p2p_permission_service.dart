import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/p2p_permission.dart';
import '../exceptions/p2p_exceptions.dart';

abstract class P2pPermissionService {
  Future<void> ensureGranted();
}

@LazySingleton(as: P2pPermissionService)
class P2pPermissionServiceImpl implements P2pPermissionService {
  static const _deniedMessage =
      'يجب تفعيل Bluetooth والموقع للعب عبر الشبكة المحلية';

  @override
  Future<void> ensureGranted() async {
    final denied = <P2pPermission>[];

    final locationGranted = await _request(Permission.locationWhenInUse);
    if (!locationGranted) {
      denied.add(P2pPermission.location);
    }

    final bluetoothGranted = await _requestBluetoothPermissions();
    if (!bluetoothGranted) {
      denied.add(P2pPermission.bluetooth);
    }

    final nearbyWifiGranted = await _requestNearbyWifi();
    if (!nearbyWifiGranted) {
      denied.add(P2pPermission.nearbyWifi);
    }

    if (denied.isNotEmpty) {
      throw P2pPermissionException(message: _deniedMessage, denied: denied);
    }
  }

  Future<bool> _requestBluetoothPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ];

    var anyApplicable = false;
    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) {
        anyApplicable = true;
        continue;
      }

      final result = await permission.request();
      if (result.isGranted || result.isLimited) {
        anyApplicable = true;
      }
    }

    if (anyApplicable) {
      final allGranted = await Future.wait(
        permissions.map((permission) => permission.isGranted),
      );
      if (allGranted.every((granted) => granted)) {
        return true;
      }
    }

    return _request(Permission.bluetooth);
  }

  Future<bool> _requestNearbyWifi() async {
    final status = await Permission.nearbyWifiDevices.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status == PermissionStatus.denied) {
      final result = await Permission.nearbyWifiDevices.request();
      return result.isGranted || result.isLimited;
    }

    // Permission not applicable on this Android version.
    return true;
  }

  Future<bool> _request(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }

    final result = await permission.request();
    return result.isGranted || result.isLimited;
  }
}
