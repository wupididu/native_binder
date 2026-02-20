import 'package:flutter/material.dart';
import 'package:native_binder/native_binder.dart';

class NativeBinderExampleScreen extends StatefulWidget {
  const NativeBinderExampleScreen({super.key});

  @override
  State<NativeBinderExampleScreen> createState() =>
      _NativeBinderExampleScreenState();
}

class _NativeBinderExampleScreenState extends State<NativeBinderExampleScreen> {
  final TextEditingController _echoController = TextEditingController();
  String? _echoResult;
  String? _nativeToDartResult;
  int? _countResult;
  double? _doubleResult;
  bool? _boolResult;
  List<dynamic>? _itemsResult;
  Map<dynamic, dynamic>? _configResult;
  bool _nullCalled = false;
  num? _addIntResult;
  num? _addDoubleResult;
  String? _processUserInfoResult;
  int? _squareResult;
  double? _circleAreaResult;
  bool? _invertBoolResult;
  String? _reverseStringResult;
  String? _errorDisplay;

  @override
  void initState() {
    super.initState();
    // Initialize bidirectional binding
    NativeBinder.initialize();

    // Register Dart handlers that native code can call
    NativeBinder.register('dartGreet', (args) {
      final name = (args as List?)?[0] as String? ?? 'Unknown';
      return 'Hello from Dart, $name!';
    });

    NativeBinder.register('dartMultiply', (args) {
      final list = args as List;
      final a = list[0] as num;
      final b = list[1] as num;
      return a * b;
    });

    NativeBinder.register('dartProcessData', (args) {
      final data = args as Map;
      return {
        'processed': true,
        'count': data.length,
        'keys': data.keys.toList(),
      };
    });
  }

  @override
  void dispose() {
    _echoController.dispose();
    NativeBinder.unregister('dartGreet');
    NativeBinder.unregister('dartMultiply');
    NativeBinder.unregister('dartProcessData');
    super.dispose();
  }

  void _callEcho() {
    if (!NativeBinder.isSupported) return;
    try {
      final result = NativeBinder.call<String>(
        'echo',
        _echoController.text.isEmpty ? null : _echoController.text,
      );
      setState(() {
        _echoResult = result;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  void _loadPrimitives() {
    if (!NativeBinder.isSupported) return;
    try {
      final count = NativeBinder.call<int>('getCount');
      final d = NativeBinder.call<double>('getDouble');
      final b = NativeBinder.call<bool>('getBool');
      setState(() {
        _countResult = count;
        _doubleResult = d;
        _boolResult = b;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  void _loadCollections() {
    if (!NativeBinder.isSupported) return;
    try {
      final items = NativeBinder.call<List<dynamic>>('getItems');
      final config = NativeBinder.call<Map<dynamic, dynamic>>('getConfig');
      setState(() {
        _itemsResult = items;
        _configResult = config;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  void _loadNull() {
    if (!NativeBinder.isSupported) return;
    try {
      final result = NativeBinder.call<Object?>('getNull');
      assert(result == null);
      setState(() {
        _nullCalled = true;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  void _callAdd() {
    if (!NativeBinder.isSupported) return;
    try {
      final sumInt = NativeBinder.call<int>('add', [1, 2]);
      final sumDouble = NativeBinder.call<double>('add', [2.5, 3.5]);
      setState(() {
        _addIntResult = sumInt;
        _addDoubleResult = sumDouble;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  void _triggerError() {
    if (!NativeBinder.isSupported) return;
    try {
      NativeBinder.call<void>('triggerError');
      setState(() => _errorDisplay = null);
    } on NativeBinderException catch (e) {
      setState(() {
        _errorDisplay =
            'message: ${e.message}\ncode: ${e.code}\ndetails: ${e.details}';
      });
    }
  }

  void _callUnknownMethod() {
    if (!NativeBinder.isSupported) return;
    try {
      NativeBinder.call<void>('unknownMethod');
      setState(() => _errorDisplay = null);
    } on NativeBinderException catch (e) {
      setState(() {
        _errorDisplay =
            'message: ${e.message}\ncode: ${e.code}\ndetails: ${e.details}';
      });
    }
  }

  void _callPrimitiveArguments() {
    if (!NativeBinder.isSupported) return;
    try {
      final square = NativeBinder.call<int>('square', 7);
      final area = NativeBinder.call<double>('circleArea', 5.0);
      final inverted = NativeBinder.call<bool>('invertBool', true);
      final reversed = NativeBinder.call<String>('reverseString', 'Hello');
      setState(() {
        _squareResult = square;
        _circleAreaResult = area;
        _invertBoolResult = inverted;
        _reverseStringResult = reversed;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  void _callProcessUserInfo() {
    if (!NativeBinder.isSupported) return;
    try {
      final result = NativeBinder.call<String>('processUserInfo', {
        'name': 'Alice',
        'age': 28,
        'city': 'San Francisco',
      });
      setState(() {
        _processUserInfoResult = result;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  void _triggerNativeToDartCall() {
    if (!NativeBinder.isSupported) return;
    try {
      // This calls a native method that will in turn call back to Dart
      final result = NativeBinder.call<String>('testDartCallback');
      setState(() {
        _nativeToDartResult = result;
        _errorDisplay = null;
      });
    } on NativeBinderException catch (e) {
      setState(() => _errorDisplay = '${e.message} (code: ${e.code})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = NativeBinder.isSupported;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Binder Example'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    supported ? Icons.check_circle : Icons.cancel,
                    color: supported ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    supported
                        ? 'Native bindings: supported'
                        : 'Native bindings: not supported (run on Android/iOS)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_errorDisplay != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_errorDisplay!),
              ),
            ),
          const SizedBox(height: 8),
          _Section(
            title: 'Echo (String)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _echoController,
                  decoration: const InputDecoration(
                    labelText: 'Enter text',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: supported ? _callEcho : null,
                  child: const Text('Call echo'),
                ),
                if (_echoResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Result: $_echoResult'),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Primitives (int, double, bool)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: supported ? _loadPrimitives : null,
                  child: const Text('getCount / getDouble / getBool'),
                ),
                if (_countResult != null ||
                    _doubleResult != null ||
                    _boolResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'count: $_countResult, double: $_doubleResult, bool: $_boolResult',
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Collections (List, Map)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: supported ? _loadCollections : null,
                  child: const Text('getItems / getConfig'),
                ),
                if (_itemsResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('items: $_itemsResult'),
                  ),
                if (_configResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('config: $_configResult'),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Map as argument',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: supported ? _callProcessUserInfo : null,
                  child: const Text(
                    'processUserInfo({name: Alice, age: 28, city: SF})',
                  ),
                ),
                if (_processUserInfoResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Result: $_processUserInfoResult'),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Null',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: supported ? _loadNull : null,
                  child: const Text('getNull'),
                ),
                if (_nullCalled)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Result: null'),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Args (add with List)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: supported ? _callAdd : null,
                  child: const Text('add([1, 2]) and add([2.5, 3.5])'),
                ),
                if (_addIntResult != null || _addDoubleResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '1+2 = $_addIntResult, 2.5+3.5 = $_addDoubleResult',
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Primitive types as arguments',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: supported ? _callPrimitiveArguments : null,
                  child: const Text(
                    'square(7), circleArea(5.0), invertBool(true), reverseString("Hello")',
                  ),
                ),
                if (_squareResult != null ||
                    _circleAreaResult != null ||
                    _invertBoolResult != null ||
                    _reverseStringResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'square(7) = $_squareResult\n'
                      'circleArea(5.0) = ${_circleAreaResult?.toStringAsFixed(2)}\n'
                      'invertBool(true) = $_invertBoolResult\n'
                      'reverseString("Hello") = $_reverseStringResult',
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Error handling',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: supported ? _triggerError : null,
                  child: const Text('Trigger error (triggerError)'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: supported ? _callUnknownMethod : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Unknown method'),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Native → Dart calls (reverse direction)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Native code calls back to Dart handlers registered above',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: supported ? _triggerNativeToDartCall : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: const Text('Test Native → Dart'),
                ),
                if (_nativeToDartResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Result: $_nativeToDartResult'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
