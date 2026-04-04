package com.acautomaton.receipt.tamer

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
        private val mnnLoadLatch = CountDownLatch(1)

        /**
         * 检查 MNN 库是否已加载（非阻塞）
         */
        private fun isMnnLibLoaded(): Boolean {
            return mnnLibLoaded
        }

        /**
         * 等待 MNN 库加载完成（可阻塞，应在后台线程调用）
         */
        private fun waitForMnnLibLoaded(timeoutMs: Long = 10000): Boolean {
            if (mnnLibLoaded) return true
            return try {
                mnnLoadLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
                mnnLibLoaded
            } catch (e: InterruptedException) {
                LogHelper.w("APP", "等待MNN库加载被中断: ${e.message}")
                false
            }
        }

        /**
         * 同步加载 MNN 库（应在后台线程调用）
         */
        private fun loadMnnLibrarySync(): Boolean {
            if (mnnLibLoadAttempted) return mnnLibLoaded
            mnnLibLoadAttempted = true

            // 检查是否为 arm64-v8a 架构
            val arch = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
            if (arch != "arm64-v8a") {
                LogHelper.w("LLM", "MNN 仅支持 arm64-v8a 架构，当前架构: $arch，跳过加载")
                mnnLoadLatch.countDown()
                return false
            }

            return try {
                System.loadLibrary("mnn_jni")
                mnnLibLoaded = true
                LogHelper.i("LLM", "MNN 库加载成功")
                mnnLoadLatch.countDown()
                true
            } catch (e: UnsatisfiedLinkError) {
                LogHelper.e("LLM", "MNN 库加载失败: ${e.message}")
                mnnLoadLatch.countDown()
                false
            }
        }

        /**
         * 在后台线程预加载 MNN 库
         */
        private fun preloadMnnLibraryAsync() {
            if (mnnLibLoadAttempted) return

            Thread {
                loadMnnLibrarySync()
            }.start()
        }
    }

    // Native method to disable OpenMP affinity (prevents crash on Xiaomi devices)
    private external fun setOmpAffinityDisabled()
    // Native methods for C++ log bridge
    private external fun initCppLogBridge()
    private external fun shutdownCppLogBridge()

    private val OCR_CHANNEL = "com.acautomaton.receipt.tamer/ocr"
    private val LLM_CHANNEL = "com.acautomaton.receipt.tamer/llm"
    private val STORAGE_CHANNEL = "com.acautomaton.receipt.tamer/storage"
    private val LOG_CHANNEL = "com.acautomaton.receipt.tamer/log"
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

    // 处理分享Intent的标志
    private var pendingShareIntent: android.content.Intent? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // 在后台线程预加载 MNN 库，不阻塞 UI 渲染
        // 库会在 Flutter 引擎启动期间加载完成
        preloadMnnLibraryAsync()

        // 保存分享Intent，以便Flutter准备好后处理
        if (intent?.action in listOf(android.content.Intent.ACTION_SEND, android.content.Intent.ACTION_SEND_MULTIPLE)) {
            pendingShareIntent = intent
            LogHelper.d("APP", "onCreate: 保存分享Intent: ${intent?.action}")
        }
        super.onCreate(savedInstanceState)
        LogHelper.d("APP", "onCreate: Activity创建")
    }

    override fun onStart() {
        super.onStart()
        LogHelper.d("APP", "onStart: Activity启动")
    }

    override fun onResume() {
        super.onResume()
        LogHelper.d("APP", "onResume: Activity恢复")
    }

    override fun onPause() {
        super.onPause()
        LogHelper.d("APP", "onPause: Activity暂停")
    }

    override fun onStop() {
        super.onStop()
        LogHelper.d("APP", "onStop: Activity停止")
    }

    override fun onDestroy() {
        LogHelper.d("APP", "onDestroy: Activity销毁")
        // 关闭C++层日志桥接
        if (mnnLibLoaded) {
            try {
                shutdownCppLogBridge()
                LogHelper.i("APP", "C++ log bridge 已关闭")
            } catch (e: UnsatisfiedLinkError) {
                LogHelper.w("APP", "shutdownCppLogBridge 调用失败: ${e.message}")
            }
        }
        super.onDestroy()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        // 保存分享Intent，以便Flutter准备好后处理
        if (intent.action in listOf(android.content.Intent.ACTION_SEND, android.content.Intent.ACTION_SEND_MULTIPLE)) {
            pendingShareIntent = intent
            LogHelper.d("APP", "onNewIntent: 保存分享Intent: ${intent.action}")
        }
        super.onNewIntent(intent)
        // 更新当前Activity的intent，让插件能够访问新的Intent数据
        setIntent(intent)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化日志MethodChannel
        val logChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL)
        LogHelper.setMethodChannel(logChannel)
        LogHelper.i("APP", "日志 MethodChannel 初始化完成")

        // 初始化C++层日志桥接（将C++日志转发到Flutter）
        if (mnnLibLoaded) {
            try {
                initCppLogBridge()
                LogHelper.i("APP", "C++ log bridge 初始化完成")
            } catch (e: UnsatisfiedLinkError) {
                LogHelper.w("APP", "initCppLogBridge 调用失败: ${e.message}")
            }
        }

        // OCR MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    // 异步初始化 OCR，避免阻塞主线程
                    initializeOcrAsync { success ->
                        result.success(success)
                    }
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

        // Storage MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFilesDirPath" -> {
                    result.success(filesDir.absolutePath)
                }
                "saveToDownloadDirectory" -> {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")
                    val subDir = call.argument<String>("subDir") ?: ""
                    if (fileName != null && bytes != null) {
                        val saveResult = DownloadHelper.saveToDownloadDirectory(
                            applicationContext,
                            fileName,
                            bytes,
                            subDir
                        )
                        result.success(saveResult)
                    } else {
                        result.error("INVALID_ARGUMENT", "fileName or bytes is null", null)
                    }
                }
                "copyToDownloadDirectory" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val customFileName = call.argument<String>("customFileName")
                    val subDir = call.argument<String>("subDir") ?: ""
                    if (sourcePath != null) {
                        val saveResult = DownloadHelper.copyToDownloadDirectory(
                            applicationContext,
                            sourcePath,
                            customFileName,
                            subDir
                        )
                        result.success(saveResult)
                    } else {
                        result.error("INVALID_ARGUMENT", "sourcePath is null", null)
                    }
                }
                "getDownloadDirectoryPath" -> {
                    val subDir = call.argument<String>("subDir") ?: ""
                    result.success(DownloadHelper.getDownloadDirectoryPath(subDir))
                }
                "openFileManager" -> {
                    val subDir = call.argument<String>("subDir") ?: ""
                    val success = DownloadHelper.openFileManager(applicationContext, subDir)
                    result.success(success)
                }
                "listFilesInDirectory" -> {
                    val subDir = call.argument<String>("subDir") ?: ""
                    val files = DownloadHelper.listFilesInDirectory(applicationContext, subDir)
                    result.success(files)
                }
                "listSubDirectories" -> {
                    val parentDir = call.argument<String>("parentDir") ?: ""
                    val dirs = DownloadHelper.listSubDirectories(applicationContext, parentDir)
                    result.success(dirs)
                }
                "shareFile" -> {
                    val fileUri = call.argument<String>("fileUri")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (fileUri != null && fileName != null) {
                        val success = DownloadHelper.shareFile(applicationContext, fileUri, fileName, mimeType)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "fileUri or fileName is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ==================== OCR 相关方法 ====================

    /**
     * 异步初始化 OCR 引擎（在后台线程执行，避免阻塞UI）
     */
    private fun initializeOcrAsync(callback: (Boolean) -> Unit) {
        ocrExecutor.execute {
            try {
                // Disable OpenMP affinity BEFORE creating OcrEngine to prevent crash on Xiaomi devices
                // 仅在 arm64-v8a 上调用 native 方法
                if (mnnLibLoaded) {
                    try {
                        setOmpAffinityDisabled()
                    } catch (e: UnsatisfiedLinkError) {
                        LogHelper.w("APP", "setOmpAffinityDisabled 调用失败: ${e.message}")
                    }
                }

                if (ocrEngine == null) {
                    ocrEngine = OcrEngine(applicationContext)
                }
                LogHelper.d("APP", "OCR引擎初始化成功 (RapidOcrAndroidOnnx)")
                mainHandler.post { callback(true) }
            } catch (e: Exception) {
                LogHelper.e("APP", "OCR初始化失败: ${e.message}")
                mainHandler.post { callback(false) }
            }
        }
    }

    /**
     * 初始化 OCR 引擎（同步方法，已弃用，请使用 initializeOcrAsync）
     * @deprecated 使用 initializeOcrAsync 替代，避免阻塞主线程
     */
    @Deprecated("Use initializeOcrAsync instead", ReplaceWith("initializeOcrAsync(callback)"))
    private fun initializeOcr(): Boolean {
        return try {
            // Disable OpenMP affinity BEFORE creating OcrEngine to prevent crash on Xiaomi devices
            // 仅在 arm64-v8a 上调用 native 方法
            if (mnnLibLoaded) {
                try {
                    setOmpAffinityDisabled()
                } catch (e: UnsatisfiedLinkError) {
                    LogHelper.w("APP", "setOmpAffinityDisabled 调用失败: ${e.message}")
                }
            }

            if (ocrEngine == null) {
                ocrEngine = OcrEngine(applicationContext)
            }
            LogHelper.d("APP", "OCR引擎初始化成功 (RapidOcrAndroidOnnx)")
            true
        } catch (e: Exception) {
            LogHelper.e("APP", "OCR初始化失败: ${e.message}")
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
                    LogHelper.w("OCR", "无法解码图片")
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
                    LogHelper.e("OCR", "OCR引擎未初始化")
                    mainHandler.post { callback(null, "OCR引擎未初始化") }
                }

                outputBitmap.recycle()

            } catch (e: Exception) {
                LogHelper.e("OCR", "OCR识别异常", e)
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
                    LogHelper.w("OCR", "无法解码图片")
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

                    LogHelper.d("APP", "OCR识别完成，耗时: ${System.currentTimeMillis() - startTime}ms，识别到 ${textBlocks.size} 个文本块")
                    mainHandler.post { callback(textBlocks, null) }
                } else {
                    LogHelper.e("OCR", "OCR引擎未初始化")
                    mainHandler.post { callback(null, "OCR引擎未初始化") }
                }

                outputBitmap.recycle()

            } catch (e: Exception) {
                LogHelper.e("OCR", "OCR识别异常", e)
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
        LogHelper.i("APP", "OCR资源释放完成")
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
     * 必需文件: llm_config.json, llm.mnn, llm.mnn.weight, tokenizer.txt
     */
    private fun isModelDirValid(modelDir: File): Boolean {
        if (!modelDir.exists() || !modelDir.isDirectory) {
            return false
        }

        // 检查所有必需文件是否存在
        val requiredFiles = listOf(
            "llm_config.json",
            "llm.mnn",
            "llm.mnn.weight",
            "tokenizer.txt"
        )

        for (fileName in requiredFiles) {
            val file = File(modelDir, fileName)
            if (!file.exists()) {
                LogHelper.w("APP", "模型文件缺失: $fileName")
                return false
            }
        }

        // 检查权重文件大小合理（约450MB）
        val weightFile = File(modelDir, "llm.mnn.weight")
        if (weightFile.length() < 400_000_000) {
            LogHelper.w("APP", "权重文件大小不足: ${weightFile.length()} bytes")
            return false
        }

        return true
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
            LogHelper.e("APP", "等待LLM加载被中断: ${e.message}")
            false
        }
    }

    /**
     * 异步初始化 LLM 引擎
     * 立即返回，不阻塞主线程
     * 返回状态Map，包含isLoading、archNotSupported、error等信息
     */
    private fun initializeLlmAsync(modelPath: String): Map<String, Any?> {
        // 架构检查（快速非阻塞检查）
        if (!isArm64V8()) {
            val arch = getDeviceArch()
            archNotSupported = true
            llmLoadError = "仅支持 arm64-v8a 架构，当前架构: $arch"
            LogHelper.w("APP", llmLoadError!!)
            return mapOf(
                "isLoading" to false,
                "archNotSupported" to true,
                "error" to llmLoadError,
                "deviceArch" to arch
            )
        }

        // 已加载检查
        if (mnnEngine?.isInitialized() == true) {
            LogHelper.i("APP", "LLM已初始化，跳过重复加载")
            return mapOf(
                "isLoading" to false,
                "isInitialized" to true,
                "archNotSupported" to false
            )
        }

        // 正在加载检查
        if (isLlmLoading) {
            LogHelper.i("APP", "LLM正在加载中...")
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
                // 等待 MNN 库加载完成（在后台线程等待，不阻塞主线程）
                if (!waitForMnnLibLoaded()) {
                    llmLoadError = "MNN库加载超时"
                    LogHelper.e("APP", llmLoadError!!)
                    return@Thread
                }

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
                    LogHelper.i("APP", "模型目录已存在且有效，跳过拷贝: $destModelDir")
                } else {
                    // 目录无效，删除旧文件后重新拷贝
                    if (modelDir.exists()) {
                        LogHelper.i("APP", "模型目录不完整，删除旧文件...")
                        modelDir.deleteRecursively()
                    }
                    LogHelper.i("APP", "模型文件不存在或不完整，正在从assets复制...")
                    val assetBasePath = "flutter_assets/$modelPath"
                    LogHelper.d("APP", "Asset基础路径: $assetBasePath")
                    if (!copyModelDirFromAssets(assetBasePath, destModelDir)) {
                        llmLoadError = "模型复制失败"
                        LogHelper.e("APP", llmLoadError!!)
                        return@Thread
                    }
                }

                // 加载模型
                LogHelper.i("APP", "开始在后台线程加载MNN模型...")
                val loadSuccess = mnnEngine?.loadModel(destModelDir, 4) ?: false

                if (loadSuccess) {
                    LogHelper.i("APP", "LLM引擎初始化成功 (MNN)")
                } else {
                    llmLoadError = "MNN模型加载失败"
                    LogHelper.e("APP", llmLoadError!!)
                }
            } catch (e: Exception) {
                llmLoadError = "LLM初始化异常: ${e.message}"
                LogHelper.e("APP", llmLoadError!!)
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
            LogHelper.w("LLM", "LLM引擎未初始化")
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
            LogHelper.w("LLM", "LLM引擎未初始化")
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
            LogHelper.i("APP", "LLM资源释放完成")
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
                LogHelper.e("APP", "Asset路径下未找到文件: $assetPath")
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

            LogHelper.i("APP", "模型目录复制成功: $destPath (${assetFiles.size} 个文件)")
            true
        } catch (e: IOException) {
            LogHelper.e("APP", "模型目录复制失败: ${e.message}")
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
            LogHelper.e("APP", "文件复制失败: ${e.message}")
            false
        }
    }
}