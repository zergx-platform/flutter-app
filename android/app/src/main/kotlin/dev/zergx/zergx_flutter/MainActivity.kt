package dev.zergx.zergx_flutter

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channel = "dev.zergx.app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val src = call.argument<String>("src") ?: ""
                        val name = call.argument<String>("name") ?: "download.bin"
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        if (src.isEmpty()) {
                            result.error("bad_args", "src required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val where = saveToDownloads(File(src), name, mime)
                            result.success(where)
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Copies a downloaded temp file into the public Downloads collection.
     * API 29+: MediaStore.Downloads (no permission needed). Older: the
     * app-specific external Downloads dir (no permission needed either, but
     * not the shared folder).
     */
    private fun saveToDownloads(src: File, name: String, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert returned null")
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { it.copyTo(out) }
            } ?: throw IllegalStateException("openOutputStream failed")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }
        // Legacy (< Android 10): app-scoped external Downloads dir.
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("external files dir unavailable")
        dir.mkdirs()
        val dst = File(dir, name)
        FileInputStream(src).use { input -> FileOutputStream(dst).use { input.copyTo(it) } }
        return dst.absolutePath
    }
}
