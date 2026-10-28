package com.campura.one.campura_one_student.wear

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files
import java.time.Instant

class CalendarRepositoryTest {
    private val emptyCalendar = "BEGIN:VCALENDAR\nEND:VCALENDAR"

    @Test fun authenticationScopeAndUnauthorizedRetry() = runBlocking {
        var logins = 0
        var courseCalls = 0
        val transport = ApiTransport { path, _, fields, token ->
            when {
                path.endsWith("login.php") -> {
                    logins++
                    assertEquals("demo_student", fields["userName"])
                    ApiResponse(200, """{"code":200,"data":{"token":"token-$logins","user":{"studentID":4}}}""")
                }
                path.endsWith("student_profile.php") -> {
                    assertNotNull(token)
                    ApiResponse(200, """{"code":200,"data":{"studentID":4,"schoolID":7,"compoundID":8,"departmentID":9,"classID":10}}""")
                }
                path.endsWith("course_table.php") -> {
                    courseCalls++
                    assertEquals("7", fields["schoolID"])
                    assertEquals("10", fields["classID"])
                    if (courseCalls == 1) ApiResponse(401, """{"code":401}""")
                    else ApiResponse(200, """{"code":200,"data":{"content":"BEGIN:VCALENDAR\nEND:VCALENDAR"}}""")
                }
                else -> error(path)
            }
        }
        val api = CalendarApi(transport, "demo_student", "test-password")
        assertEquals(emptyCalendar, api.fetch(CalendarKind.COURSES))
        assertEquals(2, logins)
        assertEquals(2, courseCalls)
    }

    @Test fun cacheKeepsLastGoodCalendarAndIgnoresOtherAccounts() {
        val directory = Files.createTempDirectory("campura-watch-test").toFile()
        try {
            val cache = CalendarCache(directory, "demo_student")
            cache.write(CalendarKind.SCHOOL, emptyCalendar, Instant.parse("2026-10-28T00:00:00Z"))
            assertEquals(emptyCalendar, cache.read(CalendarKind.SCHOOL)?.content)
            assertNull(CalendarCache(directory, "another").read(CalendarKind.SCHOOL))
            assertNull(cache.read(CalendarKind.COURSES))
        } finally { directory.deleteRecursively() }
    }

    @Test fun profileUnauthorizedReauthenticatesOnce() = runBlocking {
        var logins = 0
        var profiles = 0
        val transport = ApiTransport { path, _, _, _ ->
            when {
                path.endsWith("login.php") -> {
                    logins++
                    ApiResponse(200, """{"code":200,"data":{"token":"token-$logins","user":{"studentID":4}}}""")
                }
                path.endsWith("student_profile.php") -> {
                    profiles++
                    if (profiles == 1) ApiResponse(401, """{"code":401}""")
                    else ApiResponse(200, """{"code":200,"data":{"studentID":4,"schoolID":7,"compoundID":8,"departmentID":9,"classID":10}}""")
                }
                path.endsWith("school_calendar.php") -> ApiResponse(200, """{"code":200,"data":{"content":"BEGIN:VCALENDAR\nEND:VCALENDAR"}}""")
                else -> error(path)
            }
        }
        assertEquals(emptyCalendar, CalendarApi(transport, "test-user", "test-password").fetch(CalendarKind.SCHOOL))
        assertEquals(2, logins)
        assertEquals(2, profiles)
    }

    @Test fun secondUnauthorizedResponseStopsAfterOneRetry() = runBlocking {
        var calls = 0
        val transport = ApiTransport { path, _, _, _ ->
            when {
                path.endsWith("login.php") -> ApiResponse(200, """{"code":200,"data":{"token":"token","user":{"studentID":4}}}""")
                path.endsWith("student_profile.php") -> ApiResponse(200, """{"code":200,"data":{"studentID":4,"schoolID":7,"compoundID":8,"departmentID":9,"classID":10}}""")
                else -> { calls++; ApiResponse(401, """{"code":401}""") }
            }
        }
        try {
            CalendarApi(transport, "demo_student", "test-password").fetch(CalendarKind.SCHOOL)
            fail("Expected authentication failure")
        } catch (_: CalendarFailure.Authentication) {
            assertEquals(2, calls)
        }
    }
}
