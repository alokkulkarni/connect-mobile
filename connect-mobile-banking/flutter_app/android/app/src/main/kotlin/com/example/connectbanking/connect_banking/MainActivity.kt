package com.example.connectbanking.connect_banking

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

// The app's one activity. It adds the native call (ConnectCallPlugin) to the Flutter engine.
class MainActivity : FlutterActivity() {
    private var call: ConnectCallPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        call = ConnectCallPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        call?.dispose()
        call = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
