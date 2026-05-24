package com.florido.tapa_hike

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Android 15 (SDK 35) puts apps in edge-to-edge mode by default and
    // deprecates Window.setStatusBarColor / setNavigationBarColor / etc.
    //
    // We use WindowCompat (in androidx.core, always on the classpath via
    // the Flutter embedding) instead of androidx.activity.EdgeToEdge —
    // same effect for our purposes (opt into edge-to-edge so the engine
    // uses the modern WindowInsetsController APIs) but with no extra
    // dependency to fight with on Windows/Kotlin-K2.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
