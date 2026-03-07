package com.acautomaton.catering_receipt_recorder

import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.Future

/**
 * MnnEngine - Kotlin封装类，管理MNN LLM native实例
 *
 * 提供线程安全的模型加载和推理接口
 * 使用 MNN (Mobile Neural Network) 框架进行 LLM 推理
 */
class MnnEngine private constructor() {

    companion object {
        private const val TAG = "MnnEngine"

        // 加载 native 库
        init {
            System.loadLibrary("mnn_jni")
        }

        // 默认参数
        private const val DEFAULT_N_THREADS = 4
        private const val DEFAULT_MAX_TOKENS = 256
        private const val DEFAULT_TEMPERATURE = 0.0f
        private const val DEFAULT_TOP_P = 1.0f

        @Volatile
        private var instance: MnnEngine? = null

        fun getInstance(): MnnEngine {
            return instance ?: synchronized(this) {
                instance ?: MnnEngine().also { instance = it }
            }
        }
    }

    // Native方法
    external fun loadModel(modelDir: String, nThreads: Int): Boolean
    external fun generate(prompt: String, maxTokens: Int, temperature: Float, topP: Float): String
    external fun dispose()
    external fun isInitialized(): Boolean

    // 后台执行器
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * 异步加载模型
     * 如果模型已加载，直接返回成功
     */
    fun loadModelAsync(
        modelDir: String,
        nThreads: Int = DEFAULT_N_THREADS,
        callback: (Boolean, String?) -> Unit
    ): Future<*> {
        return executor.submit {
            try {
                // 检查是否已初始化
                if (isInitialized()) {
                    Log.i(TAG, "模型已加载，跳过重复加载")
                    mainHandler.post { callback(true, null) }
                    return@submit
                }

                Log.i(TAG, "开始加载MNN模型: $modelDir")
                val success = loadModel(modelDir, nThreads)
                mainHandler.post {
                    if (success) {
                        Log.i(TAG, "MNN模型加载成功")
                        callback(true, null)
                    } else {
                        Log.e(TAG, "MNN模型加载失败")
                        callback(false, "模型加载失败")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "MNN模型加载异常: ${e.message}")
                mainHandler.post { callback(false, e.message) }
            }
        }
    }

    /**
     * 异步生成文本
     */
    fun generateAsync(
        prompt: String,
        maxTokens: Int = DEFAULT_MAX_TOKENS,
        temperature: Float = DEFAULT_TEMPERATURE,
        topP: Float = DEFAULT_TOP_P,
        callback: (String?, String?) -> Unit
    ): Future<*> {
        return executor.submit {
            try {
                if (!isInitialized()) {
                    mainHandler.post { callback(null, "模型未初始化") }
                    return@submit
                }

                Log.i(TAG, "========== MNN LLM Pipeline Start ==========")
                Log.i(TAG, "Prompt: ${prompt.take(100)}${if (prompt.length > 100) "..." else ""}")
                Log.i(TAG, "Max tokens: $maxTokens, Temperature: $temperature, Top-P: $topP")

                val pipelineStart = System.currentTimeMillis()

                val result = generate(prompt, maxTokens, temperature, topP)

                val pipelineEnd = System.currentTimeMillis()
                val pipelineMs = pipelineEnd - pipelineStart

                Log.i(TAG, "========== MNN LLM Pipeline Complete ==========")
                Log.i(TAG, "[DIAG] Total pipeline time: ${pipelineMs}ms")
                Log.i(TAG, "[DIAG] Result length: ${result.length} chars")
                Log.i(TAG, "[DIAG] Result: ${result.take(200)}${if (result.length > 200) "..." else ""}")

                mainHandler.post {
                    if (result.isNotEmpty()) {
                        callback(result, null)
                    } else {
                        callback(null, "生成失败")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "MNN生成异常: ${e.message}")
                e.printStackTrace()
                mainHandler.post { callback(null, e.message) }
            }
        }
    }

    /**
     * 从OCR文本中提取订单信息
     */
    fun extractOrderInfo(
        ocrText: String,
        callback: (String?, String?) -> Unit
    ): Future<*> {
        Log.i(TAG, "========== Extract Order Info ==========")
        Log.i(TAG, "[DIAG] OCR text length: ${ocrText.length} chars")
        Log.i(TAG, "[DIAG] OCR text preview: ${ocrText.take(200)}${if (ocrText.length > 200) "..." else ""}")

        val prompt = buildOrderExtractionPrompt(ocrText)
        Log.i(TAG, "[DIAG] Full prompt length: ${prompt.length} chars")
        Log.i(TAG, "[DIAG] Full prompt: $prompt")

        return generateAsync(prompt, maxTokens = 256, callback = callback)
    }

    /**
     * 从OCR文本中提取发票信息
     */
    fun extractInvoiceInfo(
        ocrText: String,
        callback: (String?, String?) -> Unit
    ): Future<*> {
        Log.i(TAG, "========== Extract Invoice Info ==========")
        Log.i(TAG, "[DIAG] OCR text length: ${ocrText.length} chars")
        Log.i(TAG, "[DIAG] OCR text preview: ${ocrText.take(200)}${if (ocrText.length > 200) "..." else ""}")

        val prompt = buildInvoiceExtractionPrompt(ocrText)
        Log.i(TAG, "[DIAG] Full prompt length: ${prompt.length} chars")
        Log.i(TAG, "[DIAG] Full prompt: $prompt")

        return generateAsync(prompt, maxTokens = 256, callback = callback)
    }

    /**
     * 构建订单信息提取提示词
     */
    private fun buildOrderExtractionPrompt(ocrText: String): String {
        return """从外卖订单OCR文本中提取以下字段：

- shopName: 外卖店铺名称，寻找最像店铺的名称，若找不到填写"其它"
- amount: 实付金额，找"实付"或相似含义后面的数字，如"实付￥29.8"中的29.8
- orderTime: 下单时间，格式如"yyyy-MM-dd HH:mm:ss"
- orderNumber: 订单号，不要包含中文或特殊字符等无关信息，若找不到填写""

只返回JSON，不要其他内容。

OCR文本：
$ocrText"""
    }

    /**
     * 构建发票信息提取提示词
     */
    private fun buildInvoiceExtractionPrompt(ocrText: String): String {
        return """从发票OCR文本中提取以下字段：

- invoiceNumber: 发票号码，纯数字
- invoiceDate: 开票日期
- totalAmount: 价税合计金额

只返回JSON，不要其他内容。

OCR文本：
$ocrText"""
    }

    /**
     * 释放资源
     */
    fun disposeAsync(callback: (() -> Unit)? = null) {
        executor.submit {
            try {
                dispose()
                Log.i(TAG, "MNN资源释放完成")
            } catch (e: Exception) {
                Log.e(TAG, "MNN资源释放异常: ${e.message}")
            }
            callback?.let { mainHandler.post(it) }
        }
    }
}