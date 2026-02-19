package com.example.native_binder_example

import com.native_binder.NativeBinderBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register demo handlers to showcase native_binder functionality
        NativeBinderBridge.register("echo") { args ->
            when (args) {
                is List<*> -> if (args.isNotEmpty()) args[0] else null
                else -> args
            }
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
    }
}
