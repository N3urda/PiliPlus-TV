package com.example.piliplus

import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.speech.RecognizerIntent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Keeps optional TV features out of the existing JNI/media-session bridge. */
class TvBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var speechResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isTelevision" -> {
                val manager = activity.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                result.success(manager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                    activity.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
            }
            "recognizeSpeech" -> {
                if (speechResult != null) {
                    result.error("busy", "语音搜索正在进行", null)
                    return
                }
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
                    putExtra(RecognizerIntent.EXTRA_PROMPT, "说出视频、UP 主或番剧名称")
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                try {
                    speechResult = result
                    activity.startActivityForResult(intent, SPEECH_REQUEST)
                } catch (e: Exception) {
                    speechResult = null
                    result.error("unavailable", "此设备没有可用的语音服务，请使用手机输入或键盘", null)
                }
            }
            "installUpdate" -> {
                try {
                    val file = File(call.argument<String>("path") ?: "").canonicalFile
                    val directory = File(activity.cacheDir, "tv-updates").canonicalFile
                    require(file.parentFile == directory && file.isFile && file.extension == "apk")
                    val info = activity.packageManager.getPackageArchiveInfo(file.path, 0)
                    require(info?.packageName == activity.packageName) { "安装包与当前应用不匹配" }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !activity.packageManager.canRequestPackageInstalls()) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${activity.packageName}")))
                        result.success(false)
                        return
                    }
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.tvupdates", file)
                    activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    })
                    result.success(true)
                } catch (e: Exception) {
                    result.error("install_failed", e.message ?: "无法打开安装程序", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SPEECH_REQUEST) return
        val pending = speechResult ?: return
        speechResult = null
        pending.success(if (resultCode == Activity.RESULT_OK)
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null)
    }

    fun dispose() {
        speechResult?.success(null)
        speechResult = null
    }

    companion object { private const val SPEECH_REQUEST = 7401 }
}
