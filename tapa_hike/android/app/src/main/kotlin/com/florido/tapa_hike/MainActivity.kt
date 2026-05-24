package com.florido.tapa_hike

import android.os.Bundle
import androidx.activity.EdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Android 15 (SDK 35) puts apps in edge-to-edge mode by default and
    // deprecates Window.setStatusBarColor / setNavigationBarColor / etc.
    // EdgeToEdge.enable(this) is the official compatibility shim: it opts
    // into the modern WindowInsetsController APIs the engine then uses,
    // which silences the Play Console deprecation warnings.
    override fun onCreate(savedInstanceState: Bundle?) {
        EdgeToEdge.enable(this)
        super.onCreate(savedInstanceState)
    }
}
