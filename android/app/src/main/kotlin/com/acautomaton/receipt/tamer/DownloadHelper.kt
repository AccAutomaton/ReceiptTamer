package com.acautomaton.receipt.tamer

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import java.io.File
import java.io.OutputStream

/**
 * DownloadHelper - 文件下载辅助类
 *
 * 使用 MediaStore API 将文件保存到公共 Download/ReceiptTamer 目录
 * - Android 10+: 使用 MediaStore API，无需权限
 * - Android 9及以下: 使用传统文件操作，需要 WRITE_EXTERNAL_STORAGE 权限
 */
object DownloadHelper {
    private const val BASE_DIR = "ReceiptTamer"

    // 保存最后一次成功保存的文件 Uri，用于打开文件管理器
    private var lastSavedFileUri: Uri? = null
    private var lastSavedFilePath: String? = null

    /**
     * 保存字节数据到 Download/ReceiptTamer/[subDir] 目录
     *
     * @param context Application context
     * @param fileName 文件名
     * @param bytes 文件字节数据
     * @param subDir 子目录路径，如 "materials/20260331" 或 "backup/20260331"
     * @return 保存结果 Map，包含 success、path、error 字段
     */
    fun saveToDownloadDirectory(
        context: Context,
        fileName: String,
        bytes: ByteArray,
        subDir: String = ""
    ): Map<String, Any?> {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+: 使用 MediaStore API
                saveWithMediaStore(context, fileName, bytes, subDir)
            } else {
                // Android 9及以下: 使用传统文件操作
                saveWithTraditionalMethod(context, fileName, bytes, subDir)
            }
        } catch (e: Exception) {
            LogHelper.e("FILE", "保存文件失败: ${e.message}", e)
            mapOf(
                "success" to false,
                "error" to e.message
            )
        }
    }

    /**
     * 复制文件到 Download/ReceiptTamer/[subDir] 目录
     *
     * @param context Application context
     * @param sourcePath 源文件路径
     * @param customFileName 自定义文件名（可选）
     * @param subDir 子目录路径，如 "materials/20260331" 或 "backup/20260331"
     * @return 保存结果 Map，包含 success、path、error 字段
     */
    fun copyToDownloadDirectory(
        context: Context,
        sourcePath: String,
        customFileName: String? = null,
        subDir: String = ""
    ): Map<String, Any?> {
        return try {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists()) {
                return mapOf(
                    "success" to false,
                    "error" to "源文件不存在"
                )
            }

            val fileName = customFileName ?: sourceFile.name
            val bytes = sourceFile.readBytes()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveWithMediaStore(context, fileName, bytes, subDir)
            } else {
                saveWithTraditionalMethod(context, fileName, bytes, subDir)
            }
        } catch (e: Exception) {
            LogHelper.e("FILE", "复制文件失败: ${e.message}", e)
            mapOf(
                "success" to false,
                "error" to e.message
            )
        }
    }

    /**
     * 获取 Download/ReceiptTamer/[subDir] 目录路径
     * 用于在 UI 中显示保存位置
     *
     * @param subDir 子目录路径
     * @return 目录路径字符串
     */
    fun getDownloadDirectoryPath(subDir: String = ""): String {
        val basePath = "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/$BASE_DIR"
        return if (subDir.isNotEmpty()) {
            "$basePath/$subDir"
        } else {
            basePath
        }
    }

    /**
     * 打开文件管理器
     * 注意：Android DocumentsUI 不支持直接导航到特定深层目录
     * 此方法尝试打开 Downloads 应用或系统文件管理器
     *
     * @param context Application context
     * @param subDir 子目录路径（仅用于日志记录）
     * @return 是否成功启动
     */
    fun openFileManager(context: Context, subDir: String = ""): Boolean {
        val targetPath = getDownloadDirectoryPath(subDir)
        LogHelper.i("FILE", "目标目录: $targetPath")

        return try {
            // 方式1: 尝试打开厂商文件管理器（部分厂商支持路径参数）
            val fmSuccess = tryOpenFileManagerWithPath(context, targetPath)
            if (fmSuccess) {
                LogHelper.i("FILE", "使用厂商文件管理器打开成功")
                return true
            }

            // 方式2: 打开 Downloads 应用（显示下载列表）
            val downloadsIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(null, "vnd.android.cursor.dir/download")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (downloadsIntent.resolveActivity(context.packageManager) != null) {
                context.startActivity(downloadsIntent)
                LogHelper.i("FILE", "打开 Downloads 应用成功")
                return true
            }

            LogHelper.w("FILE", "无法打开文件管理器")
            false
        } catch (e: Exception) {
            LogHelper.e("FILE", "打开文件管理器失败: ${e.message}", e)
            false
        }
    }

    /**
     * 尝试打开厂商文件管理器并传递路径参数
     * 注意：这是厂商特定的实现，不是标准 Android API
     */
    private fun tryOpenFileManagerWithPath(context: Context, targetPath: String): Boolean {
        // 常见文件管理器包名及其路径参数名称（厂商特定）
        val fileManagers = listOf(
            Pair("com.sec.android.app.myfiles", "path"),           // Samsung
            Pair("com.mi.android.globalFileexplorer", "current_dir"), // Xiaomi
            Pair("com.huawei.hidisk", "path"),                      // Huawei
            Pair("com.oplus.filemanager", "path"),                  // OnePlus/Oppo
            Pair("com.vivo.filemanager", "path"),                   // Vivo
        )

        for (fm in fileManagers) {
            try {
                val intent = context.packageManager.getLaunchIntentForPackage(fm.first)
                if (intent != null) {
                    intent.action = Intent.ACTION_VIEW
                    intent.putExtra(fm.second, targetPath)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    LogHelper.i("FILE", "启动 ${fm.first} 成功，路径: $targetPath")
                    return true
                }
            } catch (e: Exception) {
                LogHelper.d("FILE", "${fm.first} 不可用")
            }
        }
        return false
    }

    /**
     * Android 10+: 使用 MediaStore API 保存文件
     */
    private fun saveWithMediaStore(
        context: Context,
        fileName: String,
        bytes: ByteArray,
        subDir: String
    ): Map<String, Any?> {
        val resolver = context.contentResolver

        // 确定 MIME 类型
        val mimeType = getMimeType(fileName)

        // 构建完整的相对路径
        val relativePath = if (subDir.isNotEmpty()) {
            "${Environment.DIRECTORY_DOWNLOADS}/$BASE_DIR/$subDir"
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$BASE_DIR"
        }

        // 创建 ContentValues
        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
            // 设置文件在下载目录中可见
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        // 插入文件记录
        val uri: Uri? = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)

        if (uri == null) {
            return mapOf(
                "success" to false,
                "error" to "无法创建文件记录"
            )
        }

        // 写入文件内容
        var outputStream: OutputStream? = null
        try {
            outputStream = resolver.openOutputStream(uri)
            if (outputStream == null) {
                return mapOf(
                    "success" to false,
                    "error" to "无法打开输出流"
                )
            }
            outputStream.write(bytes)
            outputStream.flush()

            // 标记文件写入完成
            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            val savedPath = getDownloadDirectoryPath(subDir) + "/" + fileName
            LogHelper.i("FILE", "文件保存成功: $savedPath")

            // 保存 Uri 用于后续打开文件管理器
            lastSavedFileUri = uri
            lastSavedFilePath = savedPath

            return mapOf(
                "success" to true,
                "path" to savedPath
            )
        } catch (e: Exception) {
            LogHelper.e("FILE", "写入文件失败: ${e.message}", e)
            // 删除失败的文件记录
            resolver.delete(uri, null, null)
            return mapOf(
                "success" to false,
                "error" to e.message
            )
        } finally {
            outputStream?.close()
        }
    }

    /**
     * Android 9及以下: 使用传统文件操作保存文件
     */
    private fun saveWithTraditionalMethod(
        context: Context,
        fileName: String,
        bytes: ByteArray,
        subDir: String
    ): Map<String, Any?> {
        // 获取公共 Download 目录
        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val subPath = if (subDir.isNotEmpty()) {
            "$BASE_DIR/$subDir"
        } else {
            BASE_DIR
        }
        val targetDir = File(downloadDir, subPath)

        // 创建子目录
        if (!targetDir.exists()) {
            if (!targetDir.mkdirs()) {
                return mapOf(
                    "success" to false,
                    "error" to "无法创建目录"
                )
            }
        }

        // 处理文件名冲突
        var targetFile = File(targetDir, fileName)
        if (targetFile.exists()) {
            // 添加时间戳后缀
            val timestamp = System.currentTimeMillis()
            val name = fileName.substringBeforeLast(".")
            val ext = fileName.substringAfterLast(".", "")
            val newFileName = if (ext.isNotEmpty()) {
                "${name}_$timestamp.$ext"
            } else {
                "${name}_$timestamp"
            }
            targetFile = File(targetDir, newFileName)
        }

        // 写入文件
        try {
            targetFile.writeBytes(bytes)
            LogHelper.i("FILE", "文件保存成功: ${targetFile.absolutePath}")

            // 保存路径用于后续打开文件管理器
            lastSavedFilePath = targetFile.absolutePath

            return mapOf(
                "success" to true,
                "path" to targetFile.absolutePath
            )
        } catch (e: Exception) {
            LogHelper.e("FILE", "写入文件失败: ${e.message}", e)
            return mapOf(
                "success" to false,
                "error" to e.message
            )
        }
    }

    /**
     * 根据文件扩展名获取 MIME 类型
     */
    private fun getMimeType(fileName: String): String {
        val extension = fileName.substringAfterLast(".").lowercase()
        return when (extension) {
            "pdf" -> "application/pdf"
            "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            "xls" -> "application/vnd.ms-excel"
            "zip" -> "application/zip"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "txt" -> "text/plain"
            "json" -> "application/json"
            "apk" -> "application/vnd.android.package-archive"
            else -> "application/octet-stream"
        }
    }

    /**
     * 列出 Download/ReceiptTamer/[subDir] 目录下的文件
     * 使用 MediaStore 查询（Android 10+）或直接文件操作（Android 9及以下）
     *
     * @param context Application context
     * @param subDir 子目录路径，如 "materials/20260331"
     * @return 文件列表，每个文件包含 name、path、size、date、uri 字段
     */
    fun listFilesInDirectory(context: Context, subDir: String = ""): List<Map<String, Any?>> {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                listFilesWithMediaStore(context, subDir)
            } else {
                listFilesWithTraditionalMethod(subDir)
            }
        } catch (e: Exception) {
            LogHelper.e("FILE", "列出文件失败: ${e.message}", e)
            emptyList()
        }
    }

    /**
     * Android 10+: 使用 MediaStore 查询文件列表
     */
    private fun listFilesWithMediaStore(context: Context, subDir: String): List<Map<String, Any?>> {
        val resolver = context.contentResolver

        // 构建相对路径
        val relativePath = if (subDir.isNotEmpty()) {
            "${Environment.DIRECTORY_DOWNLOADS}/$BASE_DIR/$subDir"
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$BASE_DIR"
        }

        // 查询条件：匹配相对路径
        val selection = "${MediaStore.Downloads.RELATIVE_PATH} LIKE ?"
        val selectionArgs = arrayOf("$relativePath%")

        val cursor = resolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(
                MediaStore.Downloads._ID,
                MediaStore.Downloads.DISPLAY_NAME,
                MediaStore.Downloads.SIZE,
                MediaStore.Downloads.DATE_MODIFIED,
                MediaStore.Downloads.RELATIVE_PATH,
                MediaStore.MediaColumns.DATA
            ),
            selection,
            selectionArgs,
            "${MediaStore.Downloads.DATE_MODIFIED} DESC"
        )

        val files = mutableListOf<Map<String, Any?>>()

        cursor?.use {
            val idColumn = it.getColumnIndex(MediaStore.Downloads._ID)
            val nameColumn = it.getColumnIndex(MediaStore.Downloads.DISPLAY_NAME)
            val sizeColumn = it.getColumnIndex(MediaStore.Downloads.SIZE)
            val dateColumn = it.getColumnIndex(MediaStore.Downloads.DATE_MODIFIED)
            val pathColumn = it.getColumnIndex(MediaStore.MediaColumns.DATA)

            while (it.moveToNext()) {
                val id = it.getLong(idColumn)
                val name = it.getString(nameColumn) ?: ""
                val size = it.getLong(sizeColumn)
                val date = it.getLong(dateColumn) * 1000 // 转换为毫秒
                val fullPath = it.getString(pathColumn) ?: ""

                // 构建内容 URI
                val uri = Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString())

                files.add(mapOf(
                    "name" to name,
                    "path" to fullPath,
                    "size" to size,
                    "date" to date,
                    "uri" to uri.toString()
                ))
            }
        }

        LogHelper.i("FILE", "查询到 ${files.size} 个文件")
        return files
    }

    /**
     * Android 9及以下: 使用传统文件操作列出文件
     */
    private fun listFilesWithTraditionalMethod(subDir: String): List<Map<String, Any?>> {
        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val subPath = if (subDir.isNotEmpty()) {
            "$BASE_DIR/$subDir"
        } else {
            BASE_DIR
        }
        val targetDir = File(downloadDir, subPath)

        if (!targetDir.exists() || !targetDir.isDirectory) {
            return emptyList()
        }

        val files = targetDir.listFiles()
        if (files == null) {
            return emptyList()
        }

        return files
            .filter { it.isFile }
            .sortedByDescending { it.lastModified() }
            .map { file ->
                mapOf(
                    "name" to file.name,
                    "path" to file.absolutePath,
                    "size" to file.length(),
                    "date" to file.lastModified(),
                    "uri" to Uri.fromFile(file).toString()
                )
            }
    }

    /**
     * 列出 Download/ReceiptTamer 下的所有子目录
     * 用于按日期分组显示
     *
     * @param context Application context
     * @param parentDir 父目录路径，如 "materials" 或 "backup"
     * @return 子目录列表，每个包含 name、path 字段
     */
    fun listSubDirectories(context: Context, parentDir: String = ""): List<Map<String, Any?>> {
        return try {
            val basePath = if (parentDir.isNotEmpty()) {
                "$BASE_DIR/$parentDir"
            } else {
                BASE_DIR
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                listSubDirsWithMediaStore(context, basePath)
            } else {
                listSubDirsTraditional(basePath)
            }
        } catch (e: Exception) {
            LogHelper.e("FILE", "列出子目录失败: ${e.message}", e)
            emptyList()
        }
    }

    private fun listSubDirsWithMediaStore(context: Context, basePath: String): List<Map<String, Any?>> {
        val resolver = context.contentResolver
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$basePath"

        val selection = "${MediaStore.Downloads.RELATIVE_PATH} LIKE ?"
        val selectionArgs = arrayOf("$relativePath/%")

        val cursor = resolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Downloads.RELATIVE_PATH),
            selection,
            selectionArgs,
            null
        )

        val dirs = mutableSetOf<String>()

        cursor?.use {
            val pathColumn = it.getColumnIndex(MediaStore.Downloads.RELATIVE_PATH)
            while (it.moveToNext()) {
                val path = it.getString(pathColumn) ?: ""
                // 提取直接子目录名
                val remaining = path.removePrefix(relativePath + "/")
                val subDir = remaining.split("/").firstOrNull()
                if (subDir != null && subDir.isNotEmpty()) {
                    dirs.add(subDir)
                }
            }
        }

        // 返回相对路径（不包含 ReceiptTamer/ 前缀）
        // 例如：从 "ReceiptTamer/materials/20260331" 提取 "materials/20260331"
        val pathPrefix = "$BASE_DIR/"
        return dirs.sortedDescending().map { dir ->
            val fullPath = "$basePath/$dir"
            // 移除 ReceiptTamer/ 前缀，得到相对路径如 "materials/20260331"
            val relativePath = if (fullPath.startsWith(pathPrefix)) {
                fullPath.removePrefix(pathPrefix)
            } else {
                fullPath
            }
            mapOf(
                "name" to dir,
                "path" to relativePath
            )
        }
    }

    private fun listSubDirsTraditional(basePath: String): List<Map<String, Any?>> {
        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val targetDir = File(downloadDir, basePath)

        if (!targetDir.exists() || !targetDir.isDirectory) {
            return emptyList()
        }

        val subDirs = targetDir.listFiles()?.filter { it.isDirectory } ?: emptyList()
        val pathPrefix = "$BASE_DIR/"

        return subDirs
            .sortedByDescending { it.name }
            .map { dir ->
                val fullPath = "$basePath/${dir.name}"
                // 移除 ReceiptTamer/ 前缀，得到相对路径如 "materials/20260331"
                val relativePath = if (fullPath.startsWith(pathPrefix)) {
                    fullPath.removePrefix(pathPrefix)
                } else {
                    fullPath
                }
                mapOf(
                    "name" to dir.name,
                    "path" to relativePath
                )
            }
    }

    /**
     * 分享文件
     * 使用系统分享功能分享指定文件
     *
     * @param context Application context
     * @param fileUri 文件 URI（MediaStore URI 或 file:// URI）
     * @param fileName 文件名（用于显示）
     * @param mimeType 文件 MIME 类型
     * @return 是否成功启动分享
     */
    fun shareFile(context: Context, fileUri: String, fileName: String, mimeType: String): Boolean {
        return try {
            val uri = Uri.parse(fileUri)
            val intent = Intent(Intent.ACTION_SEND).apply {
                setType(mimeType)
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, fileName)
                // 使用 ClipData 设置文件名显示
                val clip = android.content.ClipData.newRawUri(fileName, uri)
                setClipData(clip)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val chooser = Intent.createChooser(intent, "分享文件").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (chooser.resolveActivity(context.packageManager) != null) {
                context.startActivity(chooser)
                LogHelper.i("FILE", "分享文件成功: $fileUri")
                true
            } else {
                LogHelper.w("FILE", "无法分享文件")
                false
            }
        } catch (e: Exception) {
            LogHelper.e("FILE", "分享文件失败: ${e.message}", e)
            false
        }
    }
}