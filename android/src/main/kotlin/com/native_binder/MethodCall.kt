package com.native_binder

/**
 * Represents a method call with a method name and optional arguments.
 *
 * Compatible with Flutter's MethodCall API pattern.
 */
data class MethodCall(
    val method: String,
    val arguments: Any? = null
) {
    @Suppress("UNCHECKED_CAST")
    fun <T> arguments(): T = arguments as T

    override fun toString(): String = "MethodCall($method, $arguments)"
}
