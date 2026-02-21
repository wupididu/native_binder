package com.native_binder

import io.flutter.plugin.common.StandardMessageCodec
import java.nio.ByteBuffer

typealias MethodCallHandler = (MethodCall) -> Any?

/**
 * Synchronous bridge from Kotlin to Dart using FFI and StandardMessageCodec.
 *
 * Create instances with channel names, similar to MethodChannel:
 * ```kotlin
 * val channel = NativeBinder.createChannel("my_channel")
 * channel.setMethodCallHandler { call ->
 *     when (call.method) {
 *         "echo" -> call.arguments
 *         else -> throw NotImplementedError("Method not implemented")
 *     }
 * }
 * val result = channel.invokeMethod<String>("dartMethod", listOf("arg"))
 * ```
 */
class NativeBinder private constructor(val name: String) {

    companion object {
        private val channels = mutableMapOf<String, NativeBinder>()
        private val codec = StandardMessageCodec.INSTANCE

        init {
            System.loadLibrary("native_binder")
        }

        /**
         * Creates or retrieves a NativeBinder channel with the specified name.
         */
        @JvmStatic
        fun createChannel(name: String): NativeBinder {
            return channels.getOrPut(name) { NativeBinder(name) }
        }

        /**
         * Native method that calls into Dart via registered callback.
         * Returns encoded response or null if Dart callback is not registered.
         */
        @JvmStatic
        private external fun callDartNative(input: ByteArray): ByteArray?

        /**
         * Called from JNI. Input: single StandardMessageCodec value [channelName, method, args].
         * Output: envelope [0, result] for success, or [1, code, message, details] for error.
         */
        @JvmStatic
        fun handleCall(input: ByteArray): ByteArray {
            if (input.isEmpty()) return encodeError("INVALID_INPUT", "Empty input", null)

            // Measure decode time
            val decodeStart = System.nanoTime()
            val decoded = decodeFromByteArray(input) as? List<*>
                ?: return encodeError("INVALID_INPUT", "Decoded value must be [channelName, method, args]", null)
            val decodeEnd = System.nanoTime()
            val decodeTimeUs = (decodeEnd - decodeStart) / 1000.0

            if (decoded.size < 2) {
                return encodeError("INVALID_INPUT", "Expected [channelName, method, args], got ${decoded.size} elements", null)
            }

            val channelName = decoded.getOrNull(0) as? String
                ?: return encodeError("INVALID_INPUT", "Channel name must be String", null)
            val method = decoded.getOrNull(1) as? String
                ?: return encodeError("INVALID_INPUT", "Method name must be String", null)
            val args = decoded.getOrNull(2)

            val channel = channels[channelName]
                ?: return encodeError("NO_HANDLER", "No handler registered for channel: $channelName", null)

            val handler = channel.handler
                ?: return encodeError("NO_HANDLER", "No handler set for channel: $channelName", null)

            return try {
                // Measure handler execution time
                val handlerStart = System.nanoTime()
                val call = MethodCall(method, args)
                val result = handler(call)
                val handlerEnd = System.nanoTime()
                val handlerTimeUs = (handlerEnd - handlerStart) / 1000.0

                // Measure encode time (includes wrapping result with timing metadata)
                val encodeStart = System.nanoTime()
                val encoded = encodeSuccessWithTiming(result, decodeTimeUs, handlerTimeUs)
                val encodeEnd = System.nanoTime()
                val encodeTimeUs = (encodeEnd - encodeStart) / 1000.0

                // Return encoded result (timing included as metadata)
                encoded
            } catch (e: NotImplementedError) {
                encodeError("NOT_IMPLEMENTED", e.message ?: "Method not implemented", null)
            } catch (e: Throwable) {
                encodeError("HANDLER_ERROR", e.message ?: e.toString(), null)
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

        /**
         * Encodes a success response with timing metadata.
         * The result is wrapped in a Map with '_value' and '_timing' keys.
         * The '_timing' map contains 'decode', 'handler', and 'encode' times in microseconds.
         */
        private fun encodeSuccessWithTiming(
            result: Any?,
            decodeTimeUs: Double,
            handlerTimeUs: Double
        ): ByteArray {
            // First encode to measure the encode time
            val encodeStart = System.nanoTime()

            // Create wrapper with timing metadata
            val wrapper = mapOf(
                "_value" to result,
                "_timing" to mapOf(
                    "decode" to decodeTimeUs,
                    "handler" to handlerTimeUs,
                    "encode" to 0.0  // Placeholder, will be updated
                )
            )
            val tempEncoded = encodeToByteArray(listOf(0, wrapper))
            val encodeEnd = System.nanoTime()
            val encodeTimeUs = (encodeEnd - encodeStart) / 1000.0

            // Re-encode with actual encode time
            val finalWrapper = mapOf(
                "_value" to result,
                "_timing" to mapOf(
                    "decode" to decodeTimeUs,
                    "handler" to handlerTimeUs,
                    "encode" to encodeTimeUs
                )
            )
            return encodeToByteArray(listOf(0, finalWrapper))
        }

        private fun encodeError(code: String, message: String?, details: Any?): ByteArray {
            return encodeToByteArray(listOf(1, code, message, details))
        }
    }

    private var handler: MethodCallHandler? = null

    /**
     * Sets the handler for method calls from Dart on this channel.
     *
     * The handler receives a [MethodCall] and should return a value or throw.
     * Throw [NotImplementedError] for unrecognized methods.
     *
     * Pass null to remove the handler.
     */
    fun setMethodCallHandler(handler: MethodCallHandler?) {
        this.handler = handler
    }

    /**
     * Invokes a Dart method on this channel synchronously.
     *
     * Returns the decoded result or throws if the call fails.
     *
     * Example:
     * ```kotlin
     * val result = channel.invokeMethod<String>("greet", listOf("World"))
     * ```
     */
    @Suppress("UNCHECKED_CAST")
    fun <T> invokeMethod(method: String, arguments: Any? = null): T? {
        val callList = listOf(name, method, arguments)
        val input = Companion.encodeToByteArray(callList)

        val response = callDartNative(input)
            ?: throw RuntimeException("Dart callback not registered or call failed")

        if (response.isEmpty()) throw RuntimeException("Empty response from Dart")
        val envelope = Companion.decodeFromByteArray(response) as? List<*>
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
}
