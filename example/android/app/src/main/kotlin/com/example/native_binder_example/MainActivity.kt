package com.example.native_binder_example

import com.native_binder.NativeBinderBridge
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
                        // Simple pass-through method for performance testing
                        val value = call.arguments as? Int ?: 0
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            }

        // Register demo handlers to showcase native_binder functionality
        NativeBinderBridge.register("echo") { args ->
            // args is the value directly (String or null)
            args
        }

        NativeBinderBridge.register("getCount") { _ -> 42 }

        NativeBinderBridge.register("getDouble") { _ -> 3.14 }

        NativeBinderBridge.register("getBool") { _ -> true }

        NativeBinderBridge.register("getItems") { _ ->
            listOf("a", "b", 1, 2.0)
        }

        NativeBinderBridge.register("getConfig") { _ ->
            mapOf("key" to "value", "n" to 1)
        }

        NativeBinderBridge.register("getNull") { _ -> null }

        NativeBinderBridge.register("add") { args ->
            when (args) {
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

        NativeBinderBridge.register("triggerError") { _ ->
            throw RuntimeException("Demo error")
        }

        // Single primitive argument examples
        NativeBinderBridge.register("square") { args ->
            // args is an Int directly
            if (args !is Int) {
                throw IllegalArgumentException("square expects an Int")
            }
            args * args
        }

        NativeBinderBridge.register("circleArea") { args ->
            // args is a Double directly
            val radius = when (args) {
                is Double -> args
                is Int -> args.toDouble()
                else -> throw IllegalArgumentException("circleArea expects a Number")
            }
            Math.PI * radius * radius
        }

        NativeBinderBridge.register("invertBool") { args ->
            // args is a Boolean directly
            if (args !is Boolean) {
                throw IllegalArgumentException("invertBool expects a Boolean")
            }
            !args
        }

        NativeBinderBridge.register("reverseString") { args ->
            // args is a String directly
            if (args !is String) {
                throw IllegalArgumentException("reverseString expects a String")
            }
            args.reversed()
        }

        NativeBinderBridge.register("processUserInfo") { args ->
            // args is the Map directly
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

        // Native → Dart call demonstration
        NativeBinderBridge.register("testDartCallback") { _ ->
            // Call Dart handlers from Kotlin
            val greeting = NativeBinderBridge.callDart<String>("dartGreet", listOf("Kotlin"))
            val product = NativeBinderBridge.callDart<Number>("dartMultiply", listOf(6, 7))
            val processed = NativeBinderBridge.callDart<Map<*, *>>("dartProcessData",
                mapOf("x" to 1, "y" to 2, "z" to 3))

            "Kotlin called Dart:\n" +
                "  dartGreet: $greeting\n" +
                "  dartMultiply(6,7): $product\n" +
                "  dartProcessData: $processed"
        }

        // Performance test handler
        NativeBinderBridge.register("perfTest") { args ->
            // Simple pass-through for performance testing
            args as? Int ?: 0
        }
    }
}
