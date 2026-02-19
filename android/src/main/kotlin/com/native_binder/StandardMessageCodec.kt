package com.native_binder

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets
import java.util.ArrayList
import java.util.HashMap

/**
 * Kotlin implementation of Flutter's StandardMessageCodec binary format
 * (subset: null, bool, int, long, double, String, List, Map).
 */
internal object StandardMessageCodec {
    private const val NULL: Byte = 0
    private const val TRUE: Byte = 1
    private const val FALSE: Byte = 2
    private const val INT: Byte = 3
    private const val LONG: Byte = 4
    private const val DOUBLE: Byte = 6
    private const val STRING: Byte = 7
    private const val LIST: Byte = 12
    private const val MAP: Byte = 13

    /** Reads a single value from [buffer] (used for multi-value messages). */
    fun readValueFromBuffer(buffer: ByteBuffer): Any? = readValue(buffer)

    fun encodeMessage(value: Any?): ByteArray {
        val stream = ByteArrayOutputStream()
        writeValue(stream, value)
        return stream.toByteArray()
    }

    /** Writes a single value to an existing stream (for multi-value messages). */
    fun writeValueToStream(stream: ByteArrayOutputStream, value: Any?) {
        writeValue(stream, value)
    }

    private fun writeSize(stream: ByteArrayOutputStream, value: Int) {
        when {
            value < 254 -> stream.write(value)
            value <= 0xFFFF -> {
                stream.write(254)
                stream.writeShort(value)
            }
            else -> {
                stream.write(255)
                stream.writeInt(value)
            }
        }
    }

    private fun writeValue(stream: ByteArrayOutputStream, value: Any?) {
        when (value) {
            null -> stream.write(NULL.toInt())
            is Boolean -> stream.write(if (value) TRUE.toInt() else FALSE.toInt())
            is Int -> {
                stream.write(INT.toInt())
                stream.writeInt(value)
            }
            is Long -> {
                stream.write(LONG.toInt())
                stream.writeLong(value)
            }
            is Double, is Float -> {
                stream.write(DOUBLE.toInt())
                stream.writeAlignment(8)
                stream.writeLong(java.lang.Double.doubleToLongBits((value as Number).toDouble()))
            }
            is Number -> {
                val v = value.toLong()
                if (v >= Int.MIN_VALUE && v <= Int.MAX_VALUE) {
                    stream.write(INT.toInt())
                    stream.writeInt(v.toInt())
                } else {
                    stream.write(LONG.toInt())
                    stream.writeLong(v)
                }
            }
            is String -> {
                stream.write(STRING.toInt())
                val utf8 = value.toByteArray(StandardCharsets.UTF_8)
                writeSize(stream, utf8.size)
                stream.write(utf8)
            }
            is List<*> -> {
                stream.write(LIST.toInt())
                writeSize(stream, value.size)
                value.forEach { writeValue(stream, it) }
            }
            is Map<*, *> -> {
                stream.write(MAP.toInt())
                writeSize(stream, value.size)
                value.forEach { (k, v) ->
                    writeValue(stream, k)
                    writeValue(stream, v)
                }
            }
            else -> throw IllegalArgumentException("Unsupported type: ${value::class.java}")
        }
    }

    private fun readSize(buffer: ByteBuffer): Int {
        if (!buffer.hasRemaining()) throw IllegalArgumentException("Message corrupted")
        val b = buffer.get().toInt() and 0xFF
        return when (b) {
            254 -> buffer.short.toInt() and 0xFFFF
            255 -> buffer.int
            else -> b
        }
    }

    private fun readValue(buffer: ByteBuffer): Any? {
        if (!buffer.hasRemaining()) throw IllegalArgumentException("Message corrupted")
        val type = buffer.get()
        return readValueOfType(type, buffer)
    }

    private fun readValueOfType(type: Byte, buffer: ByteBuffer): Any? {
        return when (type) {
            NULL -> null
            TRUE -> true
            FALSE -> false
            INT -> buffer.int
            LONG -> buffer.long
            DOUBLE -> {
                readAlignment(buffer, 8)
                buffer.double
            }
            STRING -> {
                val len = readSize(buffer)
                val bytes = ByteArray(len)
                buffer.get(bytes)
                String(bytes, StandardCharsets.UTF_8)
            }
            LIST -> {
                val size = readSize(buffer)
                ArrayList<Any?>().apply {
                    repeat(size) { add(readValue(buffer)) }
                }
            }
            MAP -> {
                val size = readSize(buffer)
                HashMap<Any?, Any?>().apply {
                    repeat(size) {
                        put(readValue(buffer), readValue(buffer))
                    }
                }
            }
            else -> throw IllegalArgumentException("Message corrupted: type $type")
        }
    }

    private fun readAlignment(buffer: ByteBuffer, alignment: Int) {
        val mod = buffer.position() % alignment
        if (mod != 0) buffer.position(buffer.position() + alignment - mod)
    }
}

internal class ByteArrayOutputStream {
    private val list = mutableListOf<Byte>()

    fun write(b: Int) { list.add(b.toByte()) }
    fun write(bytes: ByteArray) { list.addAll(bytes.toList()) }
    fun writeShort(v: Int) {
        list.add((v and 0xFF).toByte())
        list.add((v shr 8 and 0xFF).toByte())
    }
    fun writeInt(v: Int) {
        list.add((v and 0xFF).toByte())
        list.add((v shr 8 and 0xFF).toByte())
        list.add((v shr 16 and 0xFF).toByte())
        list.add((v shr 24 and 0xFF).toByte())
    }
    fun writeLong(v: Long) {
        for (i in 0..7) list.add((v shr (i * 8) and 0xFF).toByte())
    }
    fun writeAlignment(alignment: Int) {
        val mod = list.size % alignment
        if (mod != 0) repeat(alignment - mod) { list.add(0) }
    }
    fun toByteArray() = list.toByteArray()
}
