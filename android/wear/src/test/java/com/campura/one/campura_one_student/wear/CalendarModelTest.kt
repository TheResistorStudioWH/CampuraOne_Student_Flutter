package com.campura.one.campura_one_student.wear

import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class CalendarModelTest {
    private val zone = ZoneId.of("Asia/Shanghai")

    @Test fun parsesFoldedTextUtcTimeAndWeeklyCourse() {
        val ics = """
            BEGIN:VCALENDAR
            BEGIN:VEVENT
            UID:course-1
            SUMMARY:[演示]数据结
             构
            DTSTART:20261026T010000Z
            DTEND:20261026T023000Z
            RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261130
            LOCATION:[demo]一号楼
            DESCRIPTION:虚构示例课表，项目演示
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()
        val course = IcsCalendar.parse(ics, CalendarKind.COURSES, zone).single()
        assertEquals("数据结构", course.title)
        assertEquals("一号楼", course.location)
        assertNull(course.notes)
        assertEquals(9, course.start.withZoneSameInstant(zone).hour)
        val wednesday = IcsCalendar.eventsOn(listOf(course), LocalDate.of(2026, 10, 28)).single()
        assertEquals(LocalDate.of(2026, 10, 28), wednesday.start.toLocalDate())
        assertEquals(90, java.time.Duration.between(wednesday.start, wednesday.end).toMinutes())
        assertTrue(IcsCalendar.eventsOn(listOf(course), LocalDate.of(2026, 10, 29)).isEmpty())
        assertTrue(IcsCalendar.eventsOn(listOf(course), LocalDate.of(2026, 12, 2)).isEmpty())
    }

    @Test fun calendarEndIsExclusiveAndListHasOneMultiDayEntry() {
        val ics = """
            BEGIN:VCALENDAR
            BEGIN:VEVENT
            UID:holiday
            SUMMARY:假期
            DTSTART;VALUE=DATE:20261001
            DTEND;VALUE=DATE:20261004
            END:VEVENT
            END:VCALENDAR
        """.trimIndent()
        val item = IcsCalendar.parse(ics, CalendarKind.SCHOOL, zone).single()
        assertEquals("10月1日 – 10月3日 · 全天", eventRange(item))
        assertEquals(1, IcsCalendar.eventsOn(listOf(item), LocalDate.of(2026, 10, 3)).size)
        assertTrue(IcsCalendar.eventsOn(listOf(item), LocalDate.of(2026, 10, 4)).isEmpty())
        assertEquals(1, IcsCalendar.agenda(listOf(item), LocalDate.of(2026, 10, 3)).size)
    }

    @Test fun weekAndMonthCrossBoundaries() {
        assertEquals(LocalDate.of(2026, 10, 26), IcsCalendar.week(LocalDate.of(2026, 11, 1)).first())
        val month = IcsCalendar.month(LocalDate.of(2026, 11, 1))
        assertEquals(6, month.indexOf(LocalDate.of(2026, 11, 1)))
        assertEquals(42, month.size)
    }

    @Test fun dailyRecurrenceAndTextCleanup() {
        val item = CalendarEntry("x", IcsCalendar.clean("[演示]数学"),
            java.time.ZonedDateTime.of(2026, 10, 26, 8, 0, 0, 0, zone),
            java.time.ZonedDateTime.of(2026, 10, 26, 9, 0, 0, 0, zone), false, rule = "FREQ=DAILY;INTERVAL=2")
        assertEquals("数学", item.title)
        assertNotNull(item.occurrenceOn(LocalDate.of(2026, 10, 28)))
        assertNull(item.occurrenceOn(LocalDate.of(2026, 10, 27)))
    }

    @Test fun overlappingCoursesShareLanesThenReset() {
        fun course(id: String, start: Int, end: Int): CalendarEntry = CalendarEntry(
            id, id, java.time.ZonedDateTime.of(2026, 10, 28, start, 0, 0, 0, zone),
            java.time.ZonedDateTime.of(2026, 10, 28, end, 0, 0, 0, zone), false,
        )
        val slots = timelineSlots(listOf(course("A", 8, 10), course("B", 9, 11), course("C", 13, 14)))
        assertEquals(listOf(2, 2, 1), slots.map { it.lanes })
        assertEquals(listOf(0, 1, 0), slots.map { it.lane })
    }

    @Test fun overnightCourseClipsToEachDisplayedDay() {
        val event = CalendarEntry("overnight", "晚间课程",
            java.time.ZonedDateTime.of(2026, 10, 28, 23, 0, 0, 0, zone),
            java.time.ZonedDateTime.of(2026, 10, 29, 1, 0, 0, 0, zone), false)
        assertEquals(23 * 60 to 24 * 60, displayMinutes(event, LocalDate.of(2026, 10, 28)))
        assertEquals(0 to 60, displayMinutes(event, LocalDate.of(2026, 10, 29)))
    }
}
