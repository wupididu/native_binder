import 'package:flutter_test/flutter_test.dart';

import 'package:native_binder/native_binder.dart';

void main() {
  group('NativeBinder', () {
    test('invokeMethod throws MissingPluginException when native library is unavailable',
        () {
      // On VM (test runner) the native library is not loaded, so invokeMethod should throw.
      final channel = NativeBinder('test_channel');
      expect(
        () => channel.invokeMethod<String>('echo', 'hello'),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('PlatformException has code, message and optional details', () {
      const code = 'test_code';
      const msg = 'test message';
      final details = {'key': 'value'};
      final e = PlatformException(code: code, message: msg, details: details);
      expect(e.code, code);
      expect(e.message, msg);
      expect(e.details, details);
      expect(e.toString(), contains('PlatformException'));
      expect(e.toString(), contains(code));
      expect(e.toString(), contains(msg));
    });

    test('MissingPluginException has optional message', () {
      const msg = 'Plugin not available';
      const e = MissingPluginException(msg);
      expect(e.message, msg);
      expect(e.toString(), contains('MissingPluginException'));
      expect(e.toString(), contains(msg));
    });

    test('MethodCall has method and arguments properties', () {
      const method = 'testMethod';
      final args = {'key': 'value'};
      final call = MethodCall(method, args);
      expect(call.method, method);
      expect(call.arguments, args);
      expect(call.toString(), contains(method));
    });
  });
}
