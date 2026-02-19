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
  int? _countResult;
  double? _doubleResult;
  bool? _boolResult;
  List<dynamic>? _itemsResult;
  Map<dynamic, dynamic>? _configResult;
  bool _nullCalled = false;
  num? _addIntResult;
  num? _addDoubleResult;
  String? _errorDisplay;

  @override
  void dispose() {
    _echoController.dispose();
    super.dispose();
  }

  void _callEcho() {
    if (!NativeBinder.isSupported) return;
    try {
      final result = NativeBinder.call<String>(
        'echo',
        [_echoController.text.isEmpty ? null : _echoController.text],
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
