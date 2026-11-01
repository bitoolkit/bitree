package dev.so1ve.bitree

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var themeChannel: MethodChannel? = null

    override fun onResume() {
        super.onResume()
        // Wallpaper colours may have changed while the app was in the background.
        themeChannel?.invokeMethod("changed", null)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        TimetableWidget.updateAll(this)
        themeChannel?.invokeMethod("changed", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        themeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "dev.so1ve.bitree/theme",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getSystemPalette") {
                    result.success(SystemPalette.read(this))
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.so1ve.bitree/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    call.argument<Map<String, List<Number>>>("lightCourseColors")?.let {
                        BuildingColors.savePalette(this, false, it)
                    }
                    call.argument<Map<String, List<Number>>>("darkCourseColors")?.let {
                        BuildingColors.savePalette(this, true, it)
                    }
                    call.argument<Boolean>("useSystemPalette")?.let {
                        WidgetColors.saveUseSystemPalette(this, it)
                    }
                    TimetableWidget.updateAll(this)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        themeChannel?.setMethodCallHandler(null)
        themeChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
