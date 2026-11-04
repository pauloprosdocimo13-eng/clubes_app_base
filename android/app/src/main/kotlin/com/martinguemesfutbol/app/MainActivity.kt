package com.martinguemesfutbol.app

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var shortcutChannel: MethodChannel? = null
    private var dartReady = false
    private var initialConsumed = false
    private var pendingLaunch: Map<String, String?>? = null
    private val imageWorker = Executors.newSingleThreadExecutor()
    private var requestingPin = false
    private val clubPattern = Regex("^[a-z0-9][a-z0-9_-]{1,39}$")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Los flavors de clubes Legacy no exponen esta integración.
        if (packageName != "com.prosdodigital.generico") return
        shortcutChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tusede/club_shortcuts")
        shortcutChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    dartReady = true
                    val launch = pendingLaunch ?: if (!initialConsumed) launchFrom(intent) else null
                    pendingLaunch = null
                    initialConsumed = true
                    result.success(launch)
                }
                "supported" -> result.success(supported())
                "pin" -> {
                    val id = call.argument<String>("clubId") ?: ""
                    val name = call.argument<String>("nombre")?.trim() ?: ""
                    if (!clubPattern.matches(id) || name.isBlank()) {
                        result.error("invalid", "Club inválido", null)
                    } else if (!supported()) {
                        result.success(mapOf("estado" to "no_disponible"))
                    } else if (requestingPin) {
                        result.error("busy", "Ya hay una solicitud en curso", null)
                    } else {
                        requestingPin = true
                        val logo = call.argument<String>("logoUrl") ?: ""
                        imageWorker.execute {
                            val bitmap = loadLogo(logo)
                            runOnUiThread {
                                try {
                                    if (isFinishing || isDestroyed) {
                                        result.error("closed", "Volvé a abrir el club", null)
                                    } else {
                                        result.success(pinClub(id, name, bitmap))
                                    }
                                } catch (_: Exception) {
                                    result.error("pin_failed", "No se pudo solicitar el acceso directo", null)
                                } finally { requestingPin = false }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val launch = launchFrom(intent) ?: return
        if (dartReady) shortcutChannel?.invokeMethod("launch", launch)
        else pendingLaunch = launch
    }

    private fun launchFrom(intent: Intent?): Map<String, String?>? {
        if (intent?.action == Intent.ACTION_MAIN) return mapOf("clubId" to null)
        val uri = intent?.data ?: return null
        if (intent.action != Intent.ACTION_VIEW || uri.scheme != "tusede" || uri.host != "club") return null
        val id = uri.pathSegments.singleOrNull()
        return mapOf("clubId" to id?.takeIf { clubPattern.matches(it) })
    }

    private fun supported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        getSystemService(ShortcutManager::class.java)?.isRequestPinShortcutSupported == true

    @android.annotation.TargetApi(Build.VERSION_CODES.O)
    private fun pinClub(id: String, name: String, bitmap: Bitmap?): Map<String, Any> {
        val manager = getSystemService(ShortcutManager::class.java)
        val shortcutIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.Builder().scheme("tusede").authority("club").appendPath(id).build()
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val shortcut = ShortcutInfo.Builder(this, "club_$id")
            .setShortLabel(name.take(40)).setLongLabel(name.take(100))
            .setIcon(if (bitmap != null) Icon.createWithBitmap(bitmap) else Icon.createWithResource(this, applicationInfo.icon))
            .setIntent(shortcutIntent).build()
        val estado = if (manager.pinnedShortcuts.any { it.id == shortcut.id }) {
            if (manager.updateShortcuts(listOf(shortcut))) "actualizado" else "no_disponible"
        } else {
            // true solo significa que el lanzador recibió la solicitud, no que el usuario la aceptó.
            if (manager.requestPinShortcut(shortcut, null)) "solicitado" else "no_disponible"
        }
        return mapOf("estado" to estado, "conEscudo" to (bitmap != null))
    }

    private fun loadLogo(raw: String): Bitmap? {
        var connection: HttpURLConnection? = null
        return try {
            val url = URL(raw)
            if (url.protocol != "https" || url.userInfo != null) return null
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.instanceFollowRedirects = false
            if (connection.responseCode != 200 || connection.contentLengthLong > 4 * 1024 * 1024) return null
            val bytes = connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                val deadline = System.nanoTime() + 8_000_000_000L
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (output.size() + count > 4 * 1024 * 1024 || System.nanoTime() > deadline) return null
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth !in 1..8192 || bounds.outHeight !in 1..8192) return null
            val options = BitmapFactory.Options().apply { inSampleSize = 1 }
            while (maxOf(bounds.outWidth, bounds.outHeight) / options.inSampleSize > 384) options.inSampleSize *= 2
            val source = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return null
            val icon = Bitmap.createBitmap(192, 192, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(icon)
            canvas.drawColor(Color.WHITE)
            val scale = 152f / maxOf(source.width, source.height)
            val w = source.width * scale; val h = source.height * scale
            canvas.drawBitmap(source, null, RectF((192-w)/2, (192-h)/2, (192+w)/2, (192+h)/2), Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
            source.recycle()
            icon
        } catch (_: Exception) { null }
        finally { connection?.disconnect() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        dartReady = false
        shortcutChannel?.setMethodCallHandler(null)
        shortcutChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        imageWorker.shutdownNow()
        super.onDestroy()
    }
}
