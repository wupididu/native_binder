package com.native_binder

import io.flutter.plugin.common.StandardMessageCodec
import java.nio.ByteBuffer

/**
 * Entry point for JNI: receives encoded (method, args), dispatches to registered handlers,
 * returns encoded response (success or error envelope).
 */
object NativeBinderBridge {

    private val handlers = mutableMapOf<String, (Any?) -> Any?>()
    private val codec = StandardMessageCodec.INSTANCE

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
        val callList = listOf(method, args)
        val input = encodeToByteArray(callList)

        val response = callDartNative(input)
            ?: throw RuntimeException("Dart callback not registered or call failed")

        if (response.isEmpty()) throw RuntimeException("Empty response from Dart")
        val envelope = decodeFromByteArray(response) as? List<*>
            ?: throw RuntimeException("Invalid response envelope from Dart")
        val kind = (envelope.getOrNull(0) as? Number)?.toInt()
            ?: throw RuntimeException("Invalid response envelope kind")
        return when (kind) {
            0 -> envelope.getOrNull(1) as T?
            1 -> {
                val code = envelope.getOrNull(1) as? String
                val message = envelope.getOrNull(2) as? String
                val details = envelope.getOrNull(3)
                throw RuntimeException("Dart error: ${message ?: code} (code: $code, details: $details)")
            }
            else -> throw RuntimeException("Invalid response envelope from Dart (kind $kind)")
        }
    }

    /**
     * Called from JNI. Input: single StandardMessageCodec value [methodName, args].
     * Output: envelope byte 0 + encoded result, or byte 1 + encoded [code, message, details].
     */
    @JvmStatic
    fun handleCall(input: ByteArray): ByteArray {
        if (input.isEmpty()) return encodeError("invalid", "Empty input", null)
        val decoded = decodeFromByteArray(input) as? List<*>
            ?: return encodeError("invalid", "Decoded value must be [String, args]", null)
        val method = decoded.getOrNull(0) as? String ?: return encodeError("invalid", "Method name must be String", null)
        val args = decoded.getOrNull(1)
        val handler = handlers[method]
            ?: return encodeError("not_found", "No handler for method: $method", null)
        return try {
            val result = handler(args)
            encodeSuccess(result)
        } catch (e: Throwable) {
            encodeError("error", e.message ?: e.toString(), null)
        }
    }

    private fun encodeToByteArray(value: Any?): ByteArray {
        val buffer = codec.encodeMessage(value) ?: return ByteArray(0)
        buffer.flip()
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return bytes
    }

    private fun decodeFromByteArray(bytes: ByteArray): Any? {
        return codec.decodeMessage(ByteBuffer.wrap(bytes))
    }

    private fun encodeSuccess(result: Any?): ByteArray {
        return encodeToByteArray(listOf(0, result))
    }

    private fun encodeError(code: String, message: String?, details: Any?): ByteArray {
        return encodeToByteArray(listOf(1, code, message, details))
    }
}
