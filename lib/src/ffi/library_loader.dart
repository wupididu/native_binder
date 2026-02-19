import 'dart:ffi';
import 'dart:io';

DynamicLibrary? _lib;

DynamicLibrary? get nativeBinderLibrary {
  if (_lib != null) return _lib;
  try {
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libnative_binder.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      return null;
    }
    return _lib;
  } catch (_) {
    return null;
  }
}
