/// Represents a method call received from native code.
///
/// Contains the method name and optional arguments passed by the caller.
class MethodCall {
  /// Creates a [MethodCall] with the specified method name and arguments.
  const MethodCall(this.method, [this.arguments]);

  /// The name of the method to be invoked.
  final String method;

  /// The arguments for the method.
  ///
  /// Can be any codec-supported type: null, bool, int, double, String, List, Map.
  final dynamic arguments;

  @override
  String toString() => 'MethodCall($method, $arguments)';
}
