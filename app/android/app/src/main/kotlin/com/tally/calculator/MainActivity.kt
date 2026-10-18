package com.tally.calculator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // This channel only exists so the trigger pipeline can send SMS
        // without the default SMS role (SPEC 32).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SmsSender.CHANNEL)
            .setMethodCallHandler(SmsSender(applicationContext))
    }
}
