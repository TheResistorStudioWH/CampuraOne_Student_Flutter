package com.campura.one.campura_one_student

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "campura.one/calendar",
        ).setMethodCallHandler { call, result ->
            if (call.method != "insertEvent") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val title = call.argument<String>("title")
            val start = call.argument<Long>("startMillis")
            val end = call.argument<Long>("endMillis")
            if (title == null || start == null || end == null || end <= start) {
                result.error("INVALID_EVENT", "Invalid calendar event", null)
                return@setMethodCallHandler
            }
            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, title)
                putExtra(CalendarContract.Events.EVENT_LOCATION, call.argument<String>("location"))
                putExtra(CalendarContract.Events.DESCRIPTION, call.argument<String>("description"))
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
            }
            try {
                startActivity(intent)
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("NO_CALENDAR_APP", "No calendar app can insert events", null)
            }
        }
    }
}
