package com.campura.one.campura_one_student

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import androidx.core.content.FileProvider
import java.io.File
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
            if (call.method == "shareCalendar") {
                val contents = call.argument<String>("ics")
                if (contents == null || !contents.startsWith("BEGIN:VCALENDAR") || contents.length > 1_000_000) {
                    result.error("INVALID_CALENDAR", "Invalid calendar file", null)
                    return@setMethodCallHandler
                }
                try {
                    val directory = File(cacheDir, "calendars").apply { mkdirs() }
                    val name = (call.argument<String>("name") ?: "campura").replace(Regex("[^\\p{L}\\p{N}_-]"), "_")
                    val file = File(directory, "$name.ics").apply { writeText(contents, Charsets.UTF_8) }
                    val uri = FileProvider.getUriForFile(this, "$packageName.calendar-files", file)
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/calendar"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = android.content.ClipData.newRawUri("calendar", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(intent, "导出课表"))
                    result.success(null)
                } catch (_: Exception) {
                    result.error("CALENDAR_EXPORT_FAILED", "Cannot share calendar", null)
                }
                return@setMethodCallHandler
            }
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
