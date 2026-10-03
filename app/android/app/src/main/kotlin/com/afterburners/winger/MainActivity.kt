package com.afterburners.winger

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Channel `winger/alerts`: direct SMS, direct call and vibration. */
class MainActivity : FlutterActivity() {
    private val needed = arrayOf(
        Manifest.permission.SEND_SMS,
        Manifest.permission.CALL_PHONE,
        Manifest.permission.RECORD_AUDIO,
        Manifest.permission.ACCESS_FINE_LOCATION,
    )

    private fun has(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val missing = needed.filter { !has(it) }
        if (missing.isNotEmpty()) requestPermissions(missing.toTypedArray(), 1)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "winger/alerts")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "sendSms" -> {
                            if (!has(Manifest.permission.SEND_SMS)) return@setMethodCallHandler result.success(false)
                            val to = call.argument<String>("to")!!
                            val body = call.argument<String>("body")!!
                            val sms = if (Build.VERSION.SDK_INT >= 31) getSystemService(SmsManager::class.java)
                                      else @Suppress("DEPRECATION") SmsManager.getDefault()
                            sms.sendMultipartTextMessage(to, null, sms.divideMessage(body), null, null)
                            result.success(true)
                        }
                        "call" -> {
                            val to = call.argument<String>("to")!!
                            val action = if (has(Manifest.permission.CALL_PHONE)) Intent.ACTION_CALL else Intent.ACTION_DIAL
                            startActivity(Intent(action, Uri.parse("tel:$to")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(action == Intent.ACTION_CALL)
                        }
                        "vibrate" -> {
                            val v = if (Build.VERSION.SDK_INT >= 31)
                                (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
                            else @Suppress("DEPRECATION") (getSystemService(VIBRATOR_SERVICE) as Vibrator)
                            v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 400, 200, 400), -1))
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
