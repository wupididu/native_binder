import 'benchmark_result.dart';

/// Helper functions for generating test payloads
class PayloadGenerators {
  static String generateString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buf = StringBuffer();
    for (int i = 0; i < length; i++) {
      buf.write(chars[i % chars.length]);
    }
    return buf.toString();
  }

  static List<int> generateIntList(int count) => List.generate(count, (i) => i * 7 + 3);

  static Map<String, dynamic> generateMap(int entries) => {
        for (int i = 0; i < entries; i++) 'key_$i': i * 3.14,
      };

  static Map<String, dynamic> generateNestedMap(int breadth, int depth) {
    if (depth <= 0) {
      return {'value': 42, 'label': 'leaf'};
    }
    return {
      for (int i = 0; i < breadth; i++)
        'node_$i': generateNestedMap(breadth, depth - 1),
      'data': List.generate(breadth, (i) => i),
    };
  }

  static List<dynamic> generateMixedList(int count) {
    return List.generate(count, (i) {
      switch (i % 5) {
        case 0:
          return 'item_$i';
        case 1:
          return i;
        case 2:
          return i * 1.5;
        case 3:
          return i.isEven;
        default:
          return null;
      }
    });
  }
}

/// Pre-defined benchmark scenarios
class BenchmarkScenarios {
  /// Basic data type scenarios (Dart→Native)
  static final List<BenchmarkScenario> basicScenarios = [
    BenchmarkScenario(
      name: 'Int pass-through',
      description: 'Single integer round-trip',
      nativeMethod: 'perfTest',
      channelMethod: 'perfTest',
      payloadBuilder: () => 42,
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'String 1 KB',
      description: '~1 KB string echo',
      nativeMethod: 'perfEchoString',
      channelMethod: 'perfEchoString',
      payloadBuilder: () => PayloadGenerators.generateString(1024),
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'String 10 KB',
      description: '~10 KB string echo',
      nativeMethod: 'perfEchoString',
      channelMethod: 'perfEchoString',
      payloadBuilder: () => PayloadGenerators.generateString(10 * 1024),
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'String 100 KB',
      description: '~100 KB string echo',
      nativeMethod: 'perfEchoString',
      channelMethod: 'perfEchoString',
      payloadBuilder: () => PayloadGenerators.generateString(100 * 1024),
      direction: BenchmarkDirection.dartToNative,
    ),
  ];

  /// Collection-based scenarios (Dart→Native)
  static final List<BenchmarkScenario> collectionScenarios = [
    BenchmarkScenario(
      name: 'List 100 ints',
      description: '100-element int list round-trip',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => PayloadGenerators.generateIntList(100),
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'List 1K ints',
      description: '1,000-element int list round-trip',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => PayloadGenerators.generateIntList(1000),
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'List 10K ints',
      description: '10,000-element int list round-trip',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => PayloadGenerators.generateIntList(10000),
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'Map 100 entries',
      description: '100 key-value pairs round-trip',
      nativeMethod: 'perfEchoMap',
      channelMethod: 'perfEchoMap',
      payloadBuilder: () => PayloadGenerators.generateMap(100),
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'Map 1K entries',
      description: '1,000 key-value pairs round-trip',
      nativeMethod: 'perfEchoMap',
      channelMethod: 'perfEchoMap',
      payloadBuilder: () => PayloadGenerators.generateMap(1000),
      direction: BenchmarkDirection.dartToNative,
    ),
  ];

  /// Complex structure scenarios (Dart→Native)
  static final List<BenchmarkScenario> complexScenarios = [
    BenchmarkScenario(
      name: 'Nested structure',
      description: 'Nested maps+lists (breadth=3, depth=4)',
      nativeMethod: 'perfEchoMap',
      channelMethod: 'perfEchoMap',
      payloadBuilder: () => PayloadGenerators.generateNestedMap(3, 4),
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'Mixed list',
      description: '500 items: strings, ints, doubles, bools, nulls',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => PayloadGenerators.generateMixedList(500),
      direction: BenchmarkDirection.dartToNative,
    ),
  ];

  /// Error handling scenarios
  static final List<BenchmarkScenario> errorScenarios = [
    BenchmarkScenario(
      name: 'Error: Missing Plugin',
      description: 'Invoke non-existent method',
      nativeMethod: 'nonExistentMethod',
      channelMethod: 'nonExistentMethod',
      payloadBuilder: () => null,
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'Error: Platform Exception',
      description: 'Trigger native error with code',
      nativeMethod: 'perfThrowError',
      channelMethod: 'perfThrowError',
      payloadBuilder: () => 'Test error',
      direction: BenchmarkDirection.dartToNative,
    ),
  ];

  /// Native→Dart scenarios (requires native-side implementation)
  static final List<BenchmarkScenario> nativeToDartScenarios = [
    BenchmarkScenario(
      name: 'Native→Dart: Int',
      description: 'Native calls Dart with integer',
      nativeMethod: 'perfCallDart',
      channelMethod: 'perfCallDart',
      payloadBuilder: () => {'method': 'dartEcho', 'value': 42},
      direction: BenchmarkDirection.nativeToDart,
    ),
    BenchmarkScenario(
      name: 'Native→Dart: String 1KB',
      description: 'Native calls Dart with 1KB string',
      nativeMethod: 'perfCallDart',
      channelMethod: 'perfCallDart',
      payloadBuilder: () => {
        'method': 'dartEcho',
        'value': PayloadGenerators.generateString(1024),
      },
      direction: BenchmarkDirection.nativeToDart,
    ),
  ];

  /// Concurrent execution scenarios
  static final List<BenchmarkScenario> concurrentScenarios = [
    BenchmarkScenario(
      name: 'Concurrent 2x',
      description: '2 simultaneous calls',
      nativeMethod: 'perfTest',
      channelMethod: 'perfTest',
      payloadBuilder: () => 42,
      direction: BenchmarkDirection.dartToNative,
    ),
    BenchmarkScenario(
      name: 'Concurrent 5x',
      description: '5 simultaneous calls',
      nativeMethod: 'perfTest',
      channelMethod: 'perfTest',
      payloadBuilder: () => 42,
      direction: BenchmarkDirection.dartToNative,
    ),
  ];

  /// All standard scenarios (original set)
  static List<BenchmarkScenario> get allScenarios => [
        ...basicScenarios,
        ...collectionScenarios,
        ...complexScenarios,
      ];

  /// Extended scenarios including new test types
  static List<BenchmarkScenario> get extendedScenarios => [
        ...allScenarios,
        ...errorScenarios,
        ...nativeToDartScenarios,
        // Note: concurrent scenarios need special handling in runner
      ];
}
