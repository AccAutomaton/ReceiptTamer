package com.acautomaton.catering_receipt_recorder

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.benjaminwan.ocrlibrary.OcrEngine
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * MainActivity - Flutter应用主Activity
 *
 * 集成 Paddle-Lite OCR 功能 (使用 RapidOcrAndroidOnnx 库)
 * 集成 MNN LLM 功能 (使用 Qwen3.5-0.8B MNN 模型)
 */
class MainActivity : FlutterActivity() {

    companion object {
        init {
            // Load mnn_jni library early
            System.loadLibrary("mnn_jni")
        }
    }

    // Native method to disable OpenMP affinity (prevents crash on Xiaomi devices)
    private external fun setOmpAffinityDisabled()

    private val OCR_CHANNEL = "com.example.catering_receipt_recorder/ocr"
    private val LLM_CHANNEL = "com.example.catering_receipt_recorder/llm"
    private var ocrEngine: OcrEngine? = null
    private var mnnEngine: MnnEngine? = null

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
                        val success = initializeLlm(modelPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "modelPath is null", null)
                    }
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
            setOmpAffinityDisabled()

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
     * 执行 OCR 识别
     */
    private fun recognizeText(imageBytes: ByteArray, callback: (String?, String?) -> Unit) {
        try {
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            if (bitmap == null) {
                callback(null, "无法解码图片")
                return
            }

            // 创建输出Bitmap（与输入相同大小）
            val outputBitmap = bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, true)

            // 执行OCR识别，maxSideLen设为1024
            val ocrResult = ocrEngine?.detect(bitmap, outputBitmap, 1024)

            if (ocrResult != null) {
                callback(ocrResult.strRes, null)
            } else {
                callback(null, "OCR引擎未初始化")
            }

            outputBitmap.recycle()

        } catch (e: Exception) {
            callback(null, "OCR识别异常: ${e.message}")
        }
    }

    /**
     * 执行 OCR 识别并返回原始结果（包含坐标和置信度）
     */
    private fun recognizeRaw(imageBytes: ByteArray, callback: (List<Map<String, Any?>>?, String?) -> Unit) {
        try {
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            if (bitmap == null) {
                callback(null, "无法解码图片")
                return
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
                callback(textBlocks, null)
            } else {
                callback(null, "OCR引擎未初始化")
            }

            outputBitmap.recycle()

        } catch (e: Exception) {
            callback(null, "OCR识别异常: ${e.message}")
        }
    }

    /**
     * 释放 OCR 资源
     */
    private fun disposeOcr() {
        ocrEngine = null
    }

    // ==================== LLM 相关方法 ====================

    /**
     * 初始化 LLM 引擎
     * 将模型从assets复制到内部存储，然后加载
     */
    private fun initializeLlm(modelPath: String): Boolean {
        return try {
            // 获取MnnEngine单例
            if (mnnEngine == null) {
                mnnEngine = MnnEngine.getInstance()
            }

            // 构建目标路径（应用内部存储目录）
            // MNN模型是一个目录，包含多个文件
            val destDir = filesDir.absolutePath
            val modelDirName = modelPath.substringAfterLast("/").removeSuffix(".mnn")
            val destModelDir = "$destDir/$modelDirName"
            val modelDir = File(destModelDir)

            // 如果模型目录不存在，从assets复制
            if (!modelDir.exists() || modelDir.listFiles()?.isEmpty() != false) {
                android.util.Log.i("MainActivity", "模型文件不存在，正在从assets复制...")
                // Flutter assets 在 APK 中的路径格式为: flutter_assets/<asset_path>
                val assetBasePath = "flutter_assets/$modelPath"
                android.util.Log.d("MainActivity", "Asset base path: $assetBasePath")
                if (!copyModelDirFromAssets(assetBasePath, destModelDir)) {
                    android.util.Log.e("MainActivity", "模型复制失败")
                    return false
                }
            } else {
                android.util.Log.i("MainActivity", "模型文件已存在: $destModelDir")
            }

            // 在后台线程同步加载模型，避免阻塞主线程
            var loadSuccess = false
            val latch = java.util.concurrent.CountDownLatch(1)

            Thread {
                try {
                    android.util.Log.i("MainActivity", "开始在后台线程加载MNN模型...")
                    loadSuccess = mnnEngine?.loadModel(destModelDir, 4) ?: false
                    android.util.Log.i("MainActivity", if (loadSuccess) "MNN模型加载成功" else "MNN模型加载失败")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "MNN模型加载异常: ${e.message}")
                }
                latch.countDown()
            }.start()

            // 等待加载完成（最多等待120秒，模型加载可能需要较长时间）
            latch.await(120, java.util.concurrent.TimeUnit.SECONDS)

            if (loadSuccess) {
                android.util.Log.i("MainActivity", "LLM引擎初始化成功 (MNN)")
            } else {
                android.util.Log.e("MainActivity", "LLM引擎初始化失败")
            }
            loadSuccess
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "LLM初始化失败: ${e.message}")
            false
        }
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