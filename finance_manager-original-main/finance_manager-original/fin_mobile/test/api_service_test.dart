import 'package:flutter_test/flutter_test.dart';
import 'package:fin_mobile/services/api_service.dart';

void main() {
  group('resolveBackendUrl', () {
    test('prefers BACKEND_URL', () {
      expect(
        resolveBackendUrl({'BACKEND_URL': 'http://127.0.0.1:5000/'}),
        'http://127.0.0.1:5000',
      );
    });

    test('falls back to API_BASE_URL', () {
      expect(
        resolveBackendUrl({'API_BASE_URL': 'http://192.168.0.10:5000/'}),
        'http://192.168.0.10:5000',
      );
    });

    test('uses emulator default when unset', () {
      expect(resolveBackendUrl({}), 'http://10.0.2.2:5000');
    });
  });
}
