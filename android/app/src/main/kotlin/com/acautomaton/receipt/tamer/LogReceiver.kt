package com.acautomaton.receipt.tamer

/**
 * C++层日志接收器
 *
 * 接收来自C++ native层的日志，并转发到LogHelper统一处理
 * 通过MethodChannel发送到Flutter层写入文件
 */
object LogReceiver {

    /**
     * 接收来自C++层的单条日志
     * 由mnn-jni.cpp的logSenderThread调用
     *
     * @param level 日志级别 (D/I/W/E)
     * @param module 模块标签 (LLM/OCR等)
     * @param message 日志消息
     */
    @JvmStatic
    fun receiveLog(level: String, module: String, message: String) {
        // 转发到LogHelper，由其发送到Flutter层
        when (level.uppercase()) {
            "D" -> LogHelper.d(module, message)
            "I" -> LogHelper.i(module, message)
            "W" -> LogHelper.w(module, message)
            "E" -> LogHelper.e(module, message)
            else -> LogHelper.i(module, message)
        }
    }
}