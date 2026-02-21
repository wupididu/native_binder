package com.example.native_binder_example

import com.native_binder.NativeBinder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PERF_CHANNEL = "native_binder_perf"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup MethodChannel for performance comparison
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "perfTest" -> {
                        val value = call.arguments as? Int ?: 0
                        result.success(value)
                    }
                    "perfEchoString" -> result.success(call.arguments)
                    "perfEchoList" -> result.success(call.arguments)
                    "perfEchoMap" -> result.success(call.arguments)
                    else -> result.notImplemented()
                }
            }

        // Create NativeBinder channel instance
        val channel = NativeBinder.createChannel("example_channel")

        // Set single handler for all methods from Dart
        channel.setMethodCallHandler { call ->
            when (call.method) {
                "echo" -> call.arguments // echo back the argument

                "getCount" -> 42

                "getDouble" -> 3.14

                "getBool" -> true

                "getItems" -> listOf("a", "b", 1, 2.0)

                "getConfig" -> mapOf("key" to "value", "n" to 1)

                "getNull" -> null

                "add" -> {
                    when (val args = call.arguments) {
                        is List<*> -> {
                            if (args.size >= 2) {
                                val a = args[0]
                                val b = args[1]
                                when {
                                    a is Int && b is Int -> a + b
                                    a is Number && b is Number -> a.toDouble() + b.toDouble()
                                    else -> throw IllegalArgumentException("add expects two numbers")
                                }
                            } else throw IllegalArgumentException("add expects two numbers")
                        }
                        else -> throw IllegalArgumentException("add expects a List of two numbers")
                    }
                }

                "triggerError" -> throw RuntimeException("Demo error")

                "square" -> {
                    val args = call.arguments
                    if (args !is Int) {
                        throw IllegalArgumentException("square expects an Int")
                    }
                    args * args
                }

                "circleArea" -> {
                    val radius = when (val args = call.arguments) {
                        is Double -> args
                        is Int -> args.toDouble()
                        else -> throw IllegalArgumentException("circleArea expects a Number")
                    }
                    Math.PI * radius * radius
                }

                "invertBool" -> {
                    val args = call.arguments
                    if (args !is Boolean) {
                        throw IllegalArgumentException("invertBool expects a Boolean")
                    }
                    !args
                }

                "reverseString" -> {
                    val args = call.arguments
                    if (args !is String) {
                        throw IllegalArgumentException("reverseString expects a String")
                    }
                    args.reversed()
                }

                "processUserInfo" -> {
                    val args = call.arguments
                    if (args !is Map<*, *>) {
                        throw IllegalArgumentException("processUserInfo expects a Map")
                    }
                    val name = args["name"] as? String ?: "Unknown"
                    val age = args["age"] as? Int ?: 0
                    val city = args["city"] as? String
                    val result = StringBuilder("User: $name, Age: $age")
                    if (city != null) {
                        result.append(", City: $city")
                    }
                    result.toString()
                }

                "testDartCallback" -> {
                    // Call Dart handlers from Kotlin
                    val greeting = channel.invokeMethod<String>("dartGreet", listOf("Kotlin"))
                    val product = channel.invokeMethod<Number>("dartMultiply", listOf(6, 7))
                    val processed = channel.invokeMethod<Map<*, *>>("dartProcessData",
                        mapOf("x" to 1, "y" to 2, "z" to 3))

                    "Kotlin called Dart:\n" +
                        "  dartGreet: $greeting\n" +
                        "  dartMultiply(6,7): $product\n" +
                        "  dartProcessData: $processed"
                }

                "perfTest" -> call.arguments as? Int ?: 0

                "perfEchoString", "perfEchoList", "perfEchoMap" -> call.arguments

                else -> throw NotImplementedError("Method ${call.method} not implemented")
            }
        }
    }
}
