package com.acautomaton.catering_receipt_recorder

import android.content.res.AssetFileDescriptor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.benjaminwan.ocrlibrary.OcrEngine
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors
import android.os.Handler
import android.os.Looper

/**
 * MainActivity - Flutter应用主Activity
 *
 * 集成 Paddle-Lite OCR 功能 (使用 RapidOcrAndroidOnnx 库)
 * 集成 MNN LLM 功能 (使用 Qwen3.5-0.8B MNN 模型)
 */
class MainActivity : FlutterActivity() {

    companion object {
        // 延迟加载 MNN 库，避免在 x86 模拟器上崩溃
        private var mnnLibLoaded = false
        private var mnnLibLoadAttempted = false

        /**
         * 尝试加载 MNN 库，仅在 arm64-v8a 架构上加载
         */
        private fun tryLoadMnnLibrary(): Boolean {
            if (mnnLibLoadAttempted) return mnnLibLoaded
            mnnLibLoadAttempted = true

            // 检查是否为 arm64-v8a 架构
            val arch = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
            if (arch != "arm64-v8a") {
                android.util.Log.w("MainActivity", "MNN 仅支持 arm64-v8a 架构，当前架构: $arch，跳过加载")
                return false
            }

            return try {
                System.loadLibrary("mnn_jni")
                mnnLibLoaded = true
                android.util.Log.i("MainActivity", "MNN 库加载成功")
                true
            } catch (e: UnsatisfiedLinkError) {
                android.util.Log.e("MainActivity", "MNN 库加载失败: ${e.message}")
                false
            }
        }
    }

    // Native method to disable OpenMP affinity (prevents crash on Xiaomi devices)
    private external fun setOmpAffinityDisabled()

    private val OCR_CHANNEL = "com.example.catering_receipt_recorder/ocr"
    private val LLM_CHANNEL = "com.example.catering_receipt_recorder/llm"
    private var ocrEngine: OcrEngine? = null
    private var mnnEngine: MnnEngine? = null

    // LLM 加载状态
    private var isLlmLoading = false
    private var llmLoadError: String? = null
    private var archNotSupported = false
    private val llmLoadLatch = CountDownLatch(1)

    // 保存AssetFileDescriptor引用，防止被GC
    private val assetFds = mutableListOf<AssetFileDescriptor>()

    // 后台线程执行器（用于OCR等耗时操作）
    private val ocrExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // OCR MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val success = initializeOcr()
                    result.success(success)
                }
                "recognize" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    if (imageBytes != null) {
                        recognizeText(imageBytes) { text, error ->
                            if (text != null) {
                                result.success(mapOf(
                                    "success" to true,
                                    "text" to text
                                ))
                            } else {
                                result.success(mapOf(
                                    "success" to false,
                                    "error" to (error ?: "OCR识别失败")
                                ))
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "imageBytes is null", null)
                    }
                }
                "recognizeRaw" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    if (imageBytes != null) {
                        recognizeRaw(imageBytes) { textBlocks, error ->
                            if (textBlocks != null) {
                                result.success(mapOf(
                                    "success" to true,
                                    "textBlocks" to textBlocks
                                ))
                            } else {
                                result.success(mapOf(
                                    "success" to false,
                                    "error" to (error ?: "OCR识别失败")
                                ))
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "imageBytes is null", null)
                    }
                }
                "dispose" -> {
                    disposeOcr()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // LLM MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LLM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath != null) {
                        val status = initializeLlmAsync(modelPath)
                        result.success(status)
                    } else {
                        result.error("INVALID_ARGUMENT", "modelPath is null", null)
                    }
                }
                "waitForLoaded" -> {
                    val timeoutArg = call.argument<Number>("timeoutMs")
                    val timeoutMs = timeoutArg?.toLong() ?: 120000L
                    val success = waitForLlmLoaded(timeoutMs)
                    result.success(success)
                }
                "getStatus" -> {
                    result.success(getLlmStatus())
                }
                "extractOrder" -> {
                    val ocrText = call.argument<String>("ocrText")
                    if (ocrText != null) {
                        extractOrderInfo(ocrText) { jsonResult, error ->
                            if (jsonResult != null) {
                                result.success(mapOf(
                                    "success" to true,
                                    "result" to jsonResult
                                ))
                            } else {
                                result.success(mapOf(
                                    "success" to false,
                                    "error" to (error ?: "LLM提取失败")
                                ))
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "ocrText is null", null)
                    }
                }
                "extractInvoice" -> {
                    val ocrText = call.argument<String>("ocrText")
                    if (ocrText != null) {
                        extractInvoiceInfo(ocrText) { jsonResult, error ->
                            if (jsonResult != null) {
                                result.success(mapOf(
                                    "success" to true,
                                    "result" to jsonResult
                                ))
                            } else {
                                result.success(mapOf(
                                    "success" to false,
                                    "error" to (error ?: "LLM提取失败")
                                ))
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "ocrText is null", null)
                    }
                }
                "disposeLlm" -> {
                    disposeLlm()
                    result.success(null)
                }
                "isInitialized" -> {
                    result.success(isLlmInitialized())
                }
                else -> result.notImplemented()
            }
        }
    }

    // ==================== OCR 相关方法 ====================

    /**
     * 初始化 OCR 引擎
     */
    private fun initializeOcr(): Boolean {
        return try {
            // Disable OpenMP affinity BEFORE creating OcrEngine to prevent crash on Xiaomi devices
            // 仅在 arm64-v8a 上调用 native 方法
            if (mnnLibLoaded) {
                try {
                    setOmpAffinityDisabled()
                } catch (e: UnsatisfiedLinkError) {
                    android.util.Log.w("MainActivity", "setOmpAffinityDisabled 调用失败: ${e.message}")
                }
            }

            if (ocrEngine == null) {
                ocrEngine = OcrEngine(applicationContext)
            }
            android.util.Log.d("MainActivity", "OCR引擎初始化成功 (RapidOcrAndroidOnnx)")
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "OCR初始化失败: ${e.message}")
            false
        }
    }

    /**
     * 执行 OCR 识别（在后台线程执行，避免阻塞UI）
     */
    private fun recognizeText(imageBytes: ByteArray, callback: (String?, String?) -> Unit) {
        ocrExecutor.execute {
            try {
                val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                if (bitmap == null) {
                    mainHandler.post { callback(null, "无法解码图片") }
                    return@execute
                }

                // 创建输出Bitmap（与输入相同大小）
                val outputBitmap = bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, true)

                // 执行OCR识别，maxSideLen设为1024
                val ocrResult = ocrEngine?.detect(bitmap, outputBitmap, 1024)

                if (ocrResult != null) {
                    mainHandler.post { callback(ocrResult.strRes, null) }
                } else {
                    mainHandler.post { callback(null, "OCR引擎未初始化") }
                }

                outputBitmap.recycle()

            } catch (e: Exception) {
                mainHandler.post { callback(null, "OCR识别异常: ${e.message}") }
            }
        }
    }

    /**
     * 执行 OCR 识别并返回原始结果（包含坐标和置信度）
     * 在后台线程执行，避免阻塞UI
     */
    private fun recognizeRaw(imageBytes: ByteArray, callback: (List<Map<String, Any?>>?, String?) -> Unit) {
        ocrExecutor.execute {
            try {
                val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                if (bitmap == null) {
                    mainHandler.post { callback(null, "无法解码图片") }
                    return@execute
                }

                // 创建输出Bitmap（与输入相同大小）
                val outputBitmap = bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, true)

                val startTime = System.currentTimeMillis()
                // 执行OCR识别，maxSideLen设为1024
                val ocrResult = ocrEngine?.detect(bitmap, outputBitmap, 1024)

                if (ocrResult != null) {
                    val textBlocks = mutableListOf<Map<String, Any?>>()

                    for (block in ocrResult.textBlocks) {
                        val points = mutableListOf<Map<String, Int>>()
                        val boxPoint = block.boxPoint

                        // 添加四个角点
                        if (boxPoint != null && boxPoint.size >= 4) {
                            points.add(mapOf("x" to boxPoint[0].x, "y" to boxPoint[0].y))
                            points.add(mapOf("x" to boxPoint[1].x, "y" to boxPoint[1].y))
                            points.add(mapOf("x" to boxPoint[2].x, "y" to boxPoint[2].y))
                            points.add(mapOf("x" to boxPoint[3].x, "y" to boxPoint[3].y))
                        }

                        textBlocks.add(mapOf(
                            "text" to block.text,
                            "boundingBox" to points,
                            "confidence" to block.boxScore
                        ))
                    }

                    android.util.Log.d("MainActivity", "OCR识别完成，耗时: ${System.currentTimeMillis() - startTime}ms，识别到 ${textBlocks.size} 个文本块")
                    mainHandler.post { callback(textBlocks, null) }
                } else {
                    mainHandler.post { callback(null, "OCR引擎未初始化") }
                }

                outputBitmap.recycle()

            } catch (e: Exception) {
                mainHandler.post { callback(null, "OCR识别异常: ${e.message}") }
            }
        }
    }

    /**
     * 释放 OCR 资源
     */
    private fun disposeOcr() {
        ocrEngine = null
        ocrExecutor.shutdown()
    }

    // ==================== LLM 相关方法 ====================

    /**
     * 获取设备架构
     */
    private fun getDeviceArch(): String {
        return Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
    }

    /**
     * 检查是否为 arm64-v8a 架构
     */
    private fun isArm64V8(): Boolean {
        return getDeviceArch() == "arm64-v8a"
    }

    /**
     * 检查模型目录是否有效
     */
    private fun isModelDirValid(modelDir: File): Boolean {
        if (!modelDir.exists() || modelDir.listFiles()?.isEmpty() != false) {
            return false
        }
        // 检查关键文件是否存在且大小合理（权重文件约450MB）
        val weightFile = File(modelDir, "llm.mnn.weight")
        return weightFile.exists() && weightFile.length() > 400_000_000
    }

    /**
     * 获取 LLM 加载状态
     */
    private fun getLlmStatus(): Map<String, Any?> {
        return mapOf(
            "isLoading" to isLlmLoading,
            "isInitialized" to (mnnEngine?.isInitialized() ?: false),
            "archNotSupported" to archNotSupported,
            "error" to llmLoadError,
            "deviceArch" to getDeviceArch()
        )
    }

    /**
     * 等待 LLM 加载完成
     */
    private fun waitForLlmLoaded(timeoutMs: Long): Boolean {
        if (mnnEngine?.isInitialized() == true) {
            return true
        }
        if (archNotSupported) {
            return false
        }
        return try {
            llmLoadLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
            mnnEngine?.isInitialized() ?: false
        } catch (e: InterruptedException) {
            android.util.Log.e("MainActivity", "等待LLM加载被中断: ${e.message}")
            false
        }
    }

    /**
     * 异步初始化 LLM 引擎
     * 立即返回，不阻塞主线程
     * 返回状态Map，包含isLoading、archNotSupported、error等信息
     */
    private fun initializeLlmAsync(modelPath: String): Map<String, Any?> {
        // 先尝试加载 MNN 库
        if (!tryLoadMnnLibrary()) {
            val arch = getDeviceArch()
            archNotSupported = true
            llmLoadError = "仅支持 arm64-v8a 架构，当前架构: $arch"
            android.util.Log.w("MainActivity", llmLoadError!!)
            return mapOf(
                "isLoading" to false,
                "archNotSupported" to true,
                "error" to llmLoadError,
                "deviceArch" to arch
            )
        }

        // 架构检查
        if (!isArm64V8()) {
            val arch = getDeviceArch()
            archNotSupported = true
            llmLoadError = "仅支持 arm64-v8a 架构，当前架构: $arch"
            android.util.Log.w("MainActivity", llmLoadError!!)
            return mapOf(
                "isLoading" to false,
                "archNotSupported" to true,
                "error" to llmLoadError
            )
        }

        // 已加载检查
        if (mnnEngine?.isInitialized() == true) {
            android.util.Log.i("MainActivity", "LLM已初始化，跳过重复加载")
            return mapOf(
                "isLoading" to false,
                "isInitialized" to true,
                "archNotSupported" to false
            )
        }

        // 正在加载检查
        if (isLlmLoading) {
            android.util.Log.i("MainActivity", "LLM正在加载中...")
            return mapOf(
                "isLoading" to true,
                "archNotSupported" to false
            )
        }

        // 开始异步加载
        isLlmLoading = true
        llmLoadError = null
        archNotSupported = false

        Thread {
            try {
                // 获取MnnEngine单例
                if (mnnEngine == null) {
                    mnnEngine = MnnEngine.getInstance()
                }

                // 构建目标路径（应用内部存储目录）
                val destDir = filesDir.absolutePath
                val modelDirName = modelPath.substringAfterLast("/").removeSuffix(".mnn")
                val destModelDir = "$destDir/$modelDirName"
                val modelDir = File(destModelDir)

                // 检查模型目录是否已存在且有效
                if (isModelDirValid(modelDir)) {
                    android.util.Log.i("MainActivity", "模型目录已存在且有效，跳过拷贝: $destModelDir")
                } else if (!modelDir.exists() || modelDir.listFiles()?.isEmpty() != false) {
                    android.util.Log.i("MainActivity", "模型文件不存在或不完整，正在从assets复制...")
                    val assetBasePath = "flutter_assets/$modelPath"
                    android.util.Log.d("MainActivity", "Asset base path: $assetBasePath")
                    if (!copyModelDirFromAssets(assetBasePath, destModelDir)) {
                        llmLoadError = "模型复制失败"
                        android.util.Log.e("MainActivity", llmLoadError!!)
                        return@Thread
                    }
                } else {
                    android.util.Log.i("MainActivity", "模型文件已存在: $destModelDir")
                }

                // 加载模型
                android.util.Log.i("MainActivity", "开始在后台线程加载MNN模型...")
                val loadSuccess = mnnEngine?.loadModel(destModelDir, 4) ?: false

                if (loadSuccess) {
                    android.util.Log.i("MainActivity", "LLM引擎初始化成功 (MNN)")
                } else {
                    llmLoadError = "MNN模型加载失败"
                    android.util.Log.e("MainActivity", llmLoadError!!)
                }
            } catch (e: Exception) {
                llmLoadError = "LLM初始化异常: ${e.message}"
                android.util.Log.e("MainActivity", llmLoadError!!)
            } finally {
                isLlmLoading = false
                llmLoadLatch.countDown()
            }
        }.start()

        return mapOf(
            "isLoading" to true,
            "archNotSupported" to false
        )
    }

    /**
     * 使用 LLM 提取订单信息
     */
    private fun extractOrderInfo(ocrText: String, callback: (String?, String?) -> Unit) {
        if (mnnEngine == null || !mnnEngine!!.isInitialized()) {
            callback(null, "LLM引擎未初始化")
            return
        }

        mnnEngine?.extractOrderInfo(ocrText) { result, error ->
            callback(result, error)
        }
    }

    /**
     * 使用 LLM 提取发票信息
     */
    private fun extractInvoiceInfo(ocrText: String, callback: (String?, String?) -> Unit) {
        if (mnnEngine == null || !mnnEngine!!.isInitialized()) {
            callback(null, "LLM引擎未初始化")
            return
        }

        mnnEngine?.extractInvoiceInfo(ocrText) { result, error ->
            callback(result, error)
        }
    }

    /**
     * 释放 LLM 资源
     */
    private fun disposeLlm() {
        mnnEngine?.disposeAsync {
            android.util.Log.i("MainActivity", "LLM资源释放完成")
        }
    }

    /**
     * 检查 LLM 是否已初始化
     */
    private fun isLlmInitialized(): Boolean {
        return mnnEngine?.isInitialized() ?: false
    }

    /**
     * 复制assets中的模型目录到内部存储
     */
    private fun copyModelDirFromAssets(assetPath: String, destPath: String): Boolean {
        return try {
            val destDir = File(destPath)
            destDir.mkdirs()

            // 获取目录下的所有文件
            val assetFiles = assets.list(assetPath)
            if (assetFiles.isNullOrEmpty()) {
                android.util.Log.e("MainActivity", "No files found in asset path: $assetPath")
                return false
            }

            for (fileName in assetFiles) {
                val srcPath = "$assetPath/$fileName"
                val destFile = File(destDir, fileName)

                // 检查是否是目录
                val subFiles = assets.list(srcPath)
                if (!subFiles.isNullOrEmpty()) {
                    // 递归复制子目录
                    copyModelDirFromAssets(srcPath, destFile.absolutePath)
                } else {
                    // 复制文件
                    copyFileFromAssets(srcPath, destFile.absolutePath)
                }
            }

            android.util.Log.i("MainActivity", "模型目录复制成功: $destPath (${assetFiles.size} files)")
            true
        } catch (e: IOException) {
            android.util.Log.e("MainActivity", "模型目录复制失败: ${e.message}")
            false
        }
    }

    /**
     * 复制单个文件从assets
     */
    private fun copyFileFromAssets(assetPath: String, destPath: String): Boolean {
        return try {
            val inputStream = assets.open(assetPath)
            val outputFile = File(destPath)

            // 确保父目录存在
            outputFile.parentFile?.mkdirs()

            val outputStream = java.io.FileOutputStream(outputFile)
            val buffer = ByteArray(8192)
            var bytesRead: Int

            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
            }

            outputStream.close()
            inputStream.close()

            true
        } catch (e: IOException) {
            android.util.Log.e("MainActivity", "文件复制失败: ${e.message}")
            false
        }
    }
}