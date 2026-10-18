package com.tally.calculator

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val TIMEOUT_MS = 20_000L
private const val ACTION_SENT = "dev.nightjar.SMS_SENT"
private const val EXTRA_INDEX = "index"

/// Sends the alert text directly through SmsManager. No default SMS role, no
/// SMS database access, and no phone numbers in logs (SPEC 32).
class SmsSender(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "dev.nightjar/sms"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "sendAlerts") {
            result.notImplemented()
            return
        }
        val phones = call.argument<List<String>>("phones").orEmpty()
        val message = call.argument<String>("message").orEmpty()
        if (phones.isEmpty()) {
            result.success(mapOf("results" to emptyList<Map<String, Any?>>()))
            return
        }
        if (!hasSendPermission()) {
            result.success(
                mapOf(
                    "results" to phones.map {
                        mapOf("status" to "permission_denied")
                    },
                ),
            )
            return
        }
        SendSession(context, phones, message, result).send()
    }

    private fun hasSendPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED
}

private class SendSession(
    private val context: Context,
    private val phones: List<String>,
    private val message: String,
    private val result: MethodChannel.Result,
) {
    private val handler = Handler(Looper.getMainLooper())
    private val statuses = arrayOfNulls<String>(phones.size)
    private val reasons = arrayOfNulls<String>(phones.size)
    private var replied = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(receiverContext: Context?, intent: Intent?) {
            val index = intent?.getIntExtra(EXTRA_INDEX, -1) ?: -1
            if (index !in phones.indices) {
                return
            }
            val sent = resultCode == Activity.RESULT_OK
            statuses[index] = if (sent) "sent" else "failed"
            if (!sent) {
                reasons[index] = "send_failed"
            }
            if (allSettled()) {
                finish()
            }
        }
    }

    fun send() {
        ContextCompat.registerReceiver(
            context,
            receiver,
            IntentFilter(ACTION_SENT),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        handler.postDelayed({ finish() }, TIMEOUT_MS)

        val manager = try {
            SmsManager.getDefault()
        } catch (error: Throwable) {
            null
        }
        if (manager == null) {
            failAll("no_sms_manager")
            return
        }
        phones.forEachIndexed { index, phone ->
            try {
                val parts = manager.divideMessage(message)
                val sentIntents = ArrayList<PendingIntent>(parts.size)
                for (part in parts.indices) {
                    sentIntents.add(
                        PendingIntent.getBroadcast(
                            context,
                            index * 10 + part,
                            Intent(ACTION_SENT)
                                .setPackage(context.packageName)
                                .putExtra(EXTRA_INDEX, index),
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                        ),
                    )
                }
                manager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            } catch (error: SecurityException) {
                statuses[index] = "permission_denied"
            } catch (error: IllegalArgumentException) {
                statuses[index] = "failed"
                reasons[index] = "invalid_number"
            } catch (error: Throwable) {
                statuses[index] = "failed"
                reasons[index] = "generic_failure"
            }
        }
        if (allSettled()) {
            finish()
        }
    }

    private fun allSettled(): Boolean = statuses.all { it != null }

    private fun failAll(reason: String) {
        for (index in phones.indices) {
            if (statuses[index] == null) {
                statuses[index] = "failed"
                reasons[index] = reason
            }
        }
        finish()
    }

    private fun finish() {
        if (replied) {
            return
        }
        replied = true
        handler.removeCallbacksAndMessages(null)
        runCatching { context.unregisterReceiver(receiver) }
        val results = phones.indices.map { index ->
            val entry = mutableMapOf<String, Any?>("status" to (statuses[index] ?: "failed"))
            reasons[index]?.let { entry["reason"] = it }
            entry
        }
        result.success(mapOf("results" to results))
    }
}
