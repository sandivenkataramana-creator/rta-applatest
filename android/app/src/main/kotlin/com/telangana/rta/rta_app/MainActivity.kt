package com.telangana.rta.rta_app

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.telangana.rta.rta_app/pdf_viewer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val rawBytes = call.argument<Any>("bytes")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"

                    val bytes: ByteArray? = when (rawBytes) {
                        is ByteArray -> rawBytes
                        is List<*> -> (rawBytes as List<*>).mapNotNull { (it as? Number)?.toByte() }.toByteArray()
                        else -> null
                    }

                    if (bytes != null && fileName != null) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val isImage = mimeType.startsWith("image/")
                                val collection = if (isImage) {
                                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                                } else {
                                    MediaStore.Downloads.EXTERNAL_CONTENT_URI
                                }

                                val relativePath = if (isImage) {
                                    Environment.DIRECTORY_PICTURES + "/TGRTA"
                                } else {
                                    Environment.DIRECTORY_DOWNLOADS
                                }

                                val contentValues = ContentValues().apply {
                                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                                }

                                val resolver = context.contentResolver
                                val uri = resolver.insert(collection, contentValues)
                                if (uri != null) {
                                    resolver.openOutputStream(uri)?.use { outputStream ->
                                        outputStream.write(bytes)
                                        outputStream.flush()
                                    }

                                    contentValues.clear()
                                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                    resolver.update(uri, contentValues, null, null)

                                    MediaScannerConnection.scanFile(context, arrayOf(uri.toString()), arrayOf(mimeType), null)
                                    result.success(true)
                                    return@setMethodCallHandler
                                }
                            }

                            // Legacy / Fallback public storage
                            val targetDir = if (mimeType.startsWith("image/")) {
                                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                            } else {
                                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                            }

                            if (!targetDir.exists()) {
                                targetDir.mkdirs()
                            }
                            val finalFile = File(targetDir, fileName)
                            FileOutputStream(finalFile).use { outputStream ->
                                outputStream.write(bytes)
                                outputStream.flush()
                            }

                            MediaScannerConnection.scanFile(context, arrayOf(finalFile.absolutePath), arrayOf(mimeType), null)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Bytes or fileName is null", null)
                    }
                }
                "openPdfFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val authority = "${context.packageName}.fileprovider"
                            val uri: Uri = FileProvider.getUriForFile(context, authority, file)

                            val mimeType = when {
                                filePath.endsWith(".png", ignoreCase = true) -> "image/png"
                                filePath.endsWith(".jpg", ignoreCase = true) || filePath.endsWith(".jpeg", ignoreCase = true) -> "image/jpeg"
                                filePath.endsWith(".svg", ignoreCase = true) -> "image/svg+xml"
                                filePath.endsWith(".pdf", ignoreCase = true) -> "application/pdf"
                                else -> "*/*"
                            }

                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mimeType)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INTENT_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
