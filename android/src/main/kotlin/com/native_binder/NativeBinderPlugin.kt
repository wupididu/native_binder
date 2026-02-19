package com.native_binder

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** Flutter plugin that loads the native library and provides handler registration. */
class NativeBinderPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding) {
        System.loadLibrary("native_binder")
    }

    override fun onDetachedFromEngine(binding: io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding) {}
}
