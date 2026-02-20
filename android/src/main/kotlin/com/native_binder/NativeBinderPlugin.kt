package com.native_binder

import io.flutter.embedding.engine.plugins.FlutterPlugin

class NativeBinderPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No MethodChannel - we use FFI only. Plugin provides infrastructure.
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // No cleanup needed
    }
}
