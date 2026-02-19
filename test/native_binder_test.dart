import 'package:flutter_test/flutter_test.dart';

import 'package:native_binder/native_binder.dart';

void main() {
  group('NativeBinder', () {
    test('call throws NativeBinderException when native library is unavailable',
        () {
      // On VM (test runner) the native library is not loaded, so call should throw.
      expect(
        () => NativeBinder.call<String>('echo', ['hello']),
        throwsA(isA<NativeBinderException>()),
      );
    });

    test('NativeBinderException has message and optional code/details', () {
      const msg = 'test message';
      const code = 'test_code';
      final details = {'key': 'value'};
      final e = NativeBinderException(msg, code: code, details: details);
      expect(e.message, msg);
      expect(e.code, code);
      expect(e.details, details);
      expect(e.toString(), contains('NativeBinderException'));
      expect(e.toString(), contains(msg));
      expect(e.toString(), contains(code));
    });
  });
}
