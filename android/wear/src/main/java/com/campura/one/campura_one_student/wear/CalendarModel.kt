package com.campura.one.campura_one_student.wear

import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

enum class CalendarKind(val title: String) { COURSES("课表"), SCHOOL("校历") }
enum class CalendarMode(val title: String) { LIST("列表"), DAY("日"), WEEK("周总览"), MONTH("月") }

data class CalendarEntry(
    val id: String,
    val title: String,
    val start: ZonedDateTime,
    val end: ZonedDateTime,
    val allDay: Boolean,
    val location: String? = null,
    val notes: String? = null,
    val rule: String? = null,
) {
    fun occursOn(day: LocalDate): Boolean {
        val beginning = day.atStartOfDay(start.zone).toInstant()
        val next = day.plusDays(1).atStartOfDay(start.zone).toInstant()
        return start.toInstant() < next && end.toInstant() > beginning
    }

    fun occurrenceOn(day: LocalDate): CalendarEntry? {
        if (occursOn(day)) return this
        val rawRule = rule ?: return null
        val values = rawRule.split(';').mapNotNull {
            val pair = it.split('=', limit = 2)
            if (pair.size == 2) pair[0].uppercase(Locale.ROOT) to pair[1].uppercase(Locale.ROOT) else null
        }.toMap()
        val first = start.toLocalDate()
        if (day.isBefore(first)) return null
        val until = values["UNTIL"]?.let { IcsCalendar.parseDate(it, emptyMap())?.toLocalDate() }
        if (until != null && day.isAfter(until)) return null
        val interval = (values["INTERVAL"]?.toLongOrNull() ?: 1L).coerceAtLeast(1)
        val matches = when (values["FREQ"]) {
            "DAILY" -> java.time.temporal.ChronoUnit.DAYS.between(first, day) % interval == 0L
            "WEEKLY" -> {
                val byDay = values["BYDAY"]?.split(',')?.mapNotNull { dayCode(it.takeLast(2)) }
                    ?: listOf(first.dayOfWeek)
                val firstWeek = first.with(DayOfWeek.MONDAY)
                val dayWeek = day.with(DayOfWeek.MONDAY)
                byDay.contains(day.dayOfWeek) &&
                    java.time.temporal.ChronoUnit.WEEKS.between(firstWeek, dayWeek) % interval == 0L
            }
            else -> false
        }
        if (!matches) return null
        val movedStart = ZonedDateTime.of(day, start.toLocalTime(), start.zone)
        val movedEnd = movedStart.plus(Duration.between(start, end))
        return copy(id = "$id-${day}", start = movedStart, end = movedEnd, rule = null)
    }

    private fun dayCode(value: String): DayOfWeek? = when (value) {
        "MO" -> DayOfWeek.MONDAY; "TU" -> DayOfWeek.TUESDAY; "WE" -> DayOfWeek.WEDNESDAY
        "TH" -> DayOfWeek.THURSDAY; "FR" -> DayOfWeek.FRIDAY; "SA" -> DayOfWeek.SATURDAY
        "SU" -> DayOfWeek.SUNDAY; else -> null
    }
}

object IcsCalendar {
    private val date = DateTimeFormatter.BASIC_ISO_DATE
    private val dateTime = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss", Locale.ROOT)
    private val marker = Regex("(?i)(?:\\[|【)\\s*(?:演示|demo)\\s*(?:\\]|】)\\s*")

    fun clean(text: String): String = text.replace(marker, "").trim()
    fun cleanNotes(text: String?): String? {
        if (text == null || (text.contains("虚构示例课表") && text.contains("项目演示"))) return null
        return clean(text).ifEmpty { null }
    }

    fun parse(content: String, kind: CalendarKind, zone: ZoneId = ZoneId.systemDefault()): List<CalendarEntry> {
        val trimmed = content.trim()
        require(trimmed.isEmpty() || (trimmed.startsWith("BEGIN:VCALENDAR") && trimmed.endsWith("END:VCALENDAR"))) {
            "Invalid calendar"
        }
        if (trimmed.isEmpty()) return emptyList()
        val unfolded = mutableListOf<String>()
        for (line in content.replace("\r\n", "\n").replace('\r', '\n').split('\n')) {
            if ((line.startsWith(' ') || line.startsWith('\t')) && unfolded.isNotEmpty()) {
                unfolded[unfolded.lastIndex] += line.drop(1)
            } else if (line.isNotBlank()) unfolded += line
        }
        val events = mutableListOf<CalendarEntry>()
        var properties: MutableMap<String, Pair<Map<String, String>, String>>? = null
        for (line in unfolded) {
            if (line == "BEGIN:VEVENT") {
                properties = mutableMapOf()
            } else if (line == "END:VEVENT") {
                properties?.let { makeEvent(it, kind, zone)?.let(events::add) }
                properties = null
            } else if (properties != null) {
                val colon = line.indexOf(':')
                if (colon < 0) continue
                val parts = line.substring(0, colon).split(';')
                val params = parts.drop(1).mapNotNull {
                    val pair = it.split('=', limit = 2)
                    if (pair.size == 2) pair[0].uppercase(Locale.ROOT) to pair[1].trim('"') else null
                }.toMap()
                properties[parts[0].uppercase(Locale.ROOT)] = params to line.substring(colon + 1)
            }
        }
        return events.sortedBy { it.start.toInstant() }
    }

    private fun makeEvent(
        values: Map<String, Pair<Map<String, String>, String>>,
        kind: CalendarKind,
        zone: ZoneId,
    ): CalendarEntry? {
        val startRaw = values["DTSTART"] ?: return null
        val start = parseDate(startRaw.second, startRaw.first, zone) ?: return null
        val allDay = startRaw.first["VALUE"]?.equals("DATE", true) == true || startRaw.second.length == 8
        val end = values["DTEND"]?.let { parseDate(it.second, it.first, zone) }
            ?: if (allDay) start.plusDays(1) else start.plusHours(1)
        val title = clean(unescape(values["SUMMARY"]?.second ?: if (kind == CalendarKind.SCHOOL) "校历事项" else ""))
        if (title.isEmpty()) return null
        return CalendarEntry(
            id = unescape(values["UID"]?.second ?: "${start.toInstant()}-$title"),
            title = title,
            start = start,
            end = end,
            allDay = allDay,
            location = values["LOCATION"]?.second?.let { clean(unescape(it)) }?.ifEmpty { null },
            notes = cleanNotes(values["DESCRIPTION"]?.second?.let(::unescape)),
            rule = values["RRULE"]?.second,
        )
    }

    internal fun parseDate(raw: String, parameters: Map<String, String>, defaultZone: ZoneId = ZoneId.systemDefault()): ZonedDateTime? = try {
        val zone = parameters["TZID"]?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: defaultZone
        when {
            raw.length == 8 -> LocalDate.parse(raw, date).atStartOfDay(zone)
            raw.endsWith('Z') -> Instant.from(dateTime.withZone(ZoneId.of("UTC")).parse(raw.dropLast(1))).atZone(zone)
            else -> LocalDateTime.parse(raw, dateTime).atZone(zone)
        }
    } catch (_: Exception) { null }

    private fun unescape(value: String): String = value.replace("\\n", "\n").replace("\\N", "\n")
        .replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")

    fun eventsOn(entries: List<CalendarEntry>, day: LocalDate): List<CalendarEntry> =
        entries.mapNotNull { it.occurrenceOn(day) }.sortedWith(compareBy<CalendarEntry> { !it.allDay }.thenBy { it.start.toInstant() })

    fun agenda(entries: List<CalendarEntry>, around: LocalDate): List<CalendarEntry> {
        if (entries.none { it.rule != null }) return entries
        val window = (0..407).flatMap { offset -> eventsOn(entries, around.minusDays(42).plusDays(offset.toLong())) }
        return window.distinctBy { it.id }.sortedBy { it.start.toInstant() }
    }

    fun week(day: LocalDate): List<LocalDate> {
        val monday = day.with(DayOfWeek.MONDAY)
        return (0..6).map { monday.plusDays(it.toLong()) }
    }

    fun month(day: LocalDate): List<LocalDate?> {
        val first = day.withDayOfMonth(1)
        val leading = first.dayOfWeek.value - 1
        val length = first.lengthOfMonth()
        val size = ((leading + length + 6) / 7) * 7
        return (0 until size).map { index -> if (index in leading until leading + length) first.plusDays((index - leading).toLong()) else null }
    }
}
