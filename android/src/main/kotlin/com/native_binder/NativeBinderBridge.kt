package com.native_binder

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Entry point for JNI: receives encoded (method, args), dispatches to registered handlers,
 * returns encoded response (success or error envelope).
 */
object NativeBinderBridge {

    private val handlers = mutableMapOf<String, (Any?) -> Any?>()

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
