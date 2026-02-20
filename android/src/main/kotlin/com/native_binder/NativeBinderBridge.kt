package com.native_binder

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Entry point for JNI: receives encoded (method, args), dispatches to registered handlers,
 * returns encoded response (success or error envelope).
 */
object NativeBinderBridge {

    private val handlers = mutableMapOf<String, (Any?) -> Any?>()

    init {
        System.loadLibrary("native_binder")
    }

    /**
     * Native method that calls into Dart via registered callback.
     * Returns encoded response or null if Dart callback is not registered.
     */
    @JvmStatic
    private external fun callDartNative(input: ByteArray): ByteArray?

    /**
     * Register a handler for [method]. The handler receives decoded args (List, Map, primitives)
     * and should return a value of the same types, or throw to return an error.
     */
    @JvmStatic
    fun register(method: String, handler: (Any?) -> Any?) {
        handlers[method] = handler
    }

    @JvmStatic
    fun unregister(method: String) {
        handlers.remove(method)
    }

    /**
     * Calls a Dart handler from Kotlin. Returns the decoded result or throws if the call fails.
     *
     * Example:
     * ```kotlin
     * val result = NativeBinderBridge.callDart<String>("greet", listOf("World"))
     * ```
     */
    @JvmStatic
    @Suppress("UNCHECKED_CAST")
    fun <T> callDart(method: String, args: Any? = null): T? {
        // Encode the call (method + args)
        val stream = ByteArrayOutputStream()
        StandardMessageCodec.writeValueToStream(stream, method)
        StandardMessageCodec.writeValueToStream(stream, args)
        val input = stream.toByteArray()

        // Call native, which forwards to Dart
        val response = callDartNative(input)
            ?: throw RuntimeException("Dart callback not registered or call failed")

        // Decode the response envelope
        val buffer = ByteBuffer.wrap(response).order(ByteOrder.LITTLE_ENDIAN)
        if (response.isEmpty()) throw RuntimeException("Empty response from Dart")

        val kind = buffer.get().toInt()
        return when (kind) {
            0 -> StandardMessageCodec.readValueFromBuffer(buffer) as T?  // Success
            1 -> {
                val code = StandardMessageCodec.readValueFromBuffer(buffer) as String?
                val message = StandardMessageCodec.readValueFromBuffer(buffer) as String?
                val details = StandardMessageCodec.readValueFromBuffer(buffer)
                throw RuntimeException("Dart error: ${message ?: code} (code: $code, details: $details)")
            }
            else -> throw RuntimeException("Invalid response envelope from Dart (byte $kind)")
        }
    }

    /**
     * Called from JNI. Input: StandardMessageCodec-encoded (methodName, args).
     * Output: envelope byte 0 + encoded result, or byte 1 + code + message + details.
     */
    @JvmStatic
    fun handleCall(input: ByteArray): ByteArray {
        if (input.isEmpty()) return encodeError("invalid", "Empty input", null)
        val buffer = ByteBuffer.wrap(input).order(ByteOrder.LITTLE_ENDIAN)
        val method = StandardMessageCodec.readValueFromBuffer(buffer)
        val args = if (buffer.hasRemaining()) StandardMessageCodec.readValueFromBuffer(buffer) else null
        if (method !is String) return encodeError("invalid", "Method name must be String", null)
        val handler = handlers[method]
            ?: return encodeError("not_found", "No handler for method: $method", null)
        return try {
            val result = handler(args)
            encodeSuccess(result)
        } catch (e: Throwable) {
            encodeError("error", e.message ?: e.toString(), null)
        }
    }

    private fun encodeSuccess(result: Any?): ByteArray {
        val stream = ByteArrayOutputStream()
        stream.write(0)  // Success envelope marker
        StandardMessageCodec.writeValueToStream(stream, result)
        return stream.toByteArray()
    }

    private fun encodeError(code: String, message: String?, details: Any?): ByteArray {
        val stream = ByteArrayOutputStream()
        stream.write(1)  // Error envelope marker
        StandardMessageCodec.writeValueToStream(stream, code)
        StandardMessageCodec.writeValueToStream(stream, message)
        StandardMessageCodec.writeValueToStream(stream, details)
        return stream.toByteArray()
    }
}
