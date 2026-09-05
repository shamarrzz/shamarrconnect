import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/place_names.dart';
import 'package:flutter_hbb/models/fleet_model.dart';

void main() {
  group('looksLikeFactoryName', () {
    test('hostnames and phone models are factory', () {
      expect(looksLikeFactoryName('samsung-SM-A037U'), isTrue);
      expect(looksLikeFactoryName('desktop-os6e272'), isTrue);
      expect(looksLikeFactoryName('DESKTOP-LK73UKM'), isTrue);
      expect(looksLikeFactoryName('kali', hostname: 'kali'), isTrue);
      expect(looksLikeFactoryName(''), isTrue);
    });

    test('place names are not factory', () {
      expect(looksLikeFactoryName('Shop POS'), isFalse);
      expect(looksLikeFactoryName('Office'), isFalse);
      expect(looksLikeFactoryName('kgreen'), isFalse);
    });
  });

  group('dedupeFleetDevices', () {
    FleetDevice d({
      required String id,
      String uuid = '',
      required String name,
      String os = 'android',
      required bool online,
      int daysAgo = 0,
    }) {
      return FleetDevice(
        deviceId: id,
        deviceUuid: uuid,
        deviceName: name,
        deviceOs: os,
        lastSeen: DateTime.now().subtract(Duration(days: daysAgo)),
        online: online,
      );
    }

    test('collapses two stale samsung-SM-A037U cards to the newer one', () {
      final out = dedupeFleetDevices([
        d(id: 'old', name: 'samsung-SM-A037U', online: false, daysAgo: 17),
        d(id: 'new', name: 'samsung-SM-A037U', online: false, daysAgo: 16),
      ]);
      expect(out, hasLength(1));
      expect(out.single.deviceId, 'new');
    });

    test('keeps two live phones of the same model', () {
      final out = dedupeFleetDevices([
        d(id: 'a', uuid: 'ua', name: 'samsung-SM-A037U', online: true),
        d(id: 'b', uuid: 'ub', name: 'samsung-SM-A037U', online: true),
      ]);
      expect(out, hasLength(2));
    });

    test('same uuid different ids is one card', () {
      final out = dedupeFleetDevices([
        d(id: 'a', uuid: 'same', name: 'Office', os: 'windows', online: true),
        d(
          id: 'b',
          uuid: 'same',
          name: 'Office',
          os: 'windows',
          online: false,
          daysAgo: 1,
        ),
      ]);
      expect(out, hasLength(1));
      expect(out.single.deviceId, 'a');
    });

    test('compact ids with spaces match', () {
      expect(sameDeviceId('1 893 760 099', '1893760099'), isTrue);
      expect(compactDeviceId('1 893 760 099'), '1893760099');
    });
  });
}
