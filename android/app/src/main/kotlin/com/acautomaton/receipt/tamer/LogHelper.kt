package com.acautomaton.receipt.tamer

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * 统一日志封装
 * 通过MethodChannel将日志发送到Flutter层统一写入文件
 * 同时输出到Logcat便于开发调试
 * 日志格式与Flutter层完全一致
 */
object LogHelper {
    /// MethodChannel实例，由MainActivity设置
    private var methodChannel: MethodChannel? = null

    /// Logcat标签前缀
    private const val LOG_TAG_PREFIX = "ReceiptTamer"

    /// 主线程Handler，用于在主线程调用MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * 设置MethodChannel实例
     * 在MainActivity.configureFlutterEngine中调用
     */
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }

    /**
     * 异步发送日志到Flutter层（在主线程执行）
     */
    private fun sendToFlutter(level: String, module: String, message: String, error: String? = null, stackTrace: String? = null) {
        // MethodChannel必须在主线程调用
        mainHandler.post {
            methodChannel?.invokeMethod("writeLog", mapOf(
                "level" to level,
                "module" to module,
                "message" to message,
                "error" to error,
                "stackTrace" to stackTrace
            ))
        }
    }

    /**
     * 输出到Logcat
     */
    private fun writeToLogcat(level: String, module: String, message: String, error: String? = null) {
        val tag = "$LOG_TAG_PREFIX/$module"
        val fullMessage = if (error != null) "$message | Error: $error" else message

        when (level.uppercase()) {
            "D" -> Log.d(tag, fullMessage)
            "I" -> Log.i(tag, fullMessage)
            "W" -> Log.w(tag, fullMessage)
            "E" -> Log.e(tag, fullMessage)
            else -> Log.i(tag, fullMessage)
        }
    }

    /**
     * DEBUG级别日志
     */
    fun d(module: String, message: String) {
        writeToLogcat("D", module, message)
        sendToFlutter("D", module, message)
    }

    /**
     * INFO级别日志
     */
    fun i(module: String, message: String) {
        writeToLogcat("I", module, message)
        sendToFlutter("I", module, message)
    }

    /**
     * WARN级别日志
     */
    fun w(module: String, message: String) {
        writeToLogcat("W", module, message)
        sendToFlutter("W", module, message)
    }

    /**
     * ERROR级别日志（带异常栈）
     */
    fun e(module: String, message: String, throwable: Throwable? = null) {
        val error = throwable?.message
        val stackTrace = throwable?.stackTraceToString()

        writeToLogcat("E", module, message, error)
        if (throwable != null) {
            sendToFlutter("E", module, message, error, stackTrace)
        } else {
            sendToFlutter("E", module, message)
        }
    }

    /**
     * 诊断日志（INFO级别，带DIAG标签）
     */
    fun diag(module: String, metric: String, value: Any) {
        val message = "[$module] [DIAG] $metric: $value"
        writeToLogcat("I", module, message)
        sendToFlutter("I", module, message)
    }

    /**
     * 批量诊断日志
     */
    fun diagBatch(module: String, metrics: Map<String, Any>) {
        metrics.forEach { (key, value) ->
            diag(module, key, value)
        }
    }
}