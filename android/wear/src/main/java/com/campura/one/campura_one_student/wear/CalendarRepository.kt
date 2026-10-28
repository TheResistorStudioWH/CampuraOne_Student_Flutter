package com.campura.one.campura_one_student.wear

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.Instant

internal data class ApiResponse(val status: Int, val body: String)
internal fun interface ApiTransport {
    suspend fun send(path: String, method: String, fields: Map<String, String>, token: String?): ApiResponse
}

internal class NetworkTransport(private val baseUrl: String = "https://campura.one") : ApiTransport {
    override suspend fun send(path: String, method: String, fields: Map<String, String>, token: String?): ApiResponse =
        withContext(Dispatchers.IO) {
            val query = fields.entries.joinToString("&") {
                "${URLEncoder.encode(it.key, StandardCharsets.UTF_8)}=${URLEncoder.encode(it.value, StandardCharsets.UTF_8)}"
            }
            val address = baseUrl + path + if (method == "GET" && query.isNotEmpty()) "?$query" else ""
            val connection = (URL(address).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 12000
                readTimeout = 15000
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Cache-Control", "no-cache")
                if (token != null) setRequestProperty("Authorization", "Bearer $token")
                if (method == "POST") {
                    doOutput = true
                    setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
                    outputStream.use { it.write(query.toByteArray(StandardCharsets.UTF_8)) }
                }
            }
            try {
                val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream
                ApiResponse(connection.responseCode, stream?.bufferedReader()?.use { it.readText() } ?: "")
            } finally { connection.disconnect() }
        }
}

internal class CalendarApi(
    private val transport: ApiTransport,
    private val userName: String,
    private val password: String,
) {
    private data class Identity(val token: String, val studentId: Int, val school: Int, val compound: Int, val department: Int, val classId: Int)
    private val authLock = Mutex()
    private var identity: Identity? = null

    suspend fun fetch(kind: CalendarKind): String {
        var current = authenticated()
        var response = download(kind, current)
        if (unauthorized(response)) {
            authLock.withLock { if (identity?.token == current.token) identity = null }
            current = authenticated()
            response = download(kind, current)
        }
        if (unauthorized(response)) throw CalendarFailure.Authentication
        val data = envelope(response)
        val content = data.optString("content").ifEmpty { data.optString("schoolCalendar") }
        IcsCalendar.parse(content, kind)
        return content
    }

    private suspend fun authenticated(): Identity = authLock.withLock {
        identity?.let { return@withLock it }
        if (userName.isBlank() || password.isBlank()) throw CalendarFailure.Authentication
        for (attempt in 0..1) {
            val login = envelope(transport.send(
                "/api/auth/user/student/login.php", "POST",
                mapOf("userName" to userName, "password" to password), null,
            ))
            val token = login.optString("token")
            val studentId = login.optJSONObject("user")?.optInt("studentID") ?: 0
            if (token.isBlank() || studentId <= 0) throw CalendarFailure.Authentication
            val profileResponse = transport.send("/api/download/student_profile.php", "GET", emptyMap(), token)
            if (unauthorized(profileResponse)) {
                if (attempt == 1) throw CalendarFailure.Authentication
                continue
            }
            val profile = envelope(profileResponse)
            val result = Identity(
                token, studentId, profile.optInt("schoolID"), profile.optInt("compoundID"),
                profile.optInt("departmentID"), profile.optInt("classID"),
            )
            if (profile.optInt("studentID") != studentId ||
                listOf(result.school, result.compound, result.department, result.classId).any { it <= 0 }
            ) throw CalendarFailure.InvalidData
            identity = result
            return@withLock result
        }
        throw CalendarFailure.Authentication
    }

    private suspend fun download(kind: CalendarKind, identity: Identity): ApiResponse {
        val fields = mutableMapOf("schoolID" to identity.school.toString())
        if (kind == CalendarKind.COURSES) {
            fields["compoundID"] = identity.compound.toString()
            fields["departmentID"] = identity.department.toString()
            fields["classID"] = identity.classId.toString()
        }
        return transport.send(
            if (kind == CalendarKind.COURSES) "/api/download/course_table.php" else "/api/download/school_calendar.php",
            "GET", fields, identity.token,
        )
    }

    private fun unauthorized(response: ApiResponse): Boolean = response.status == 401 ||
        runCatching { JSONObject(response.body).optInt("code") == 401 }.getOrDefault(false)

    private fun envelope(response: ApiResponse): JSONObject {
        if (unauthorized(response)) throw CalendarFailure.Authentication
        if (response.status !in 200..299) throw CalendarFailure.Unavailable
        val json = runCatching { JSONObject(response.body) }.getOrElse { throw CalendarFailure.InvalidData }
        if (json.optInt("code") != 200) throw CalendarFailure.Unavailable
        return json.optJSONObject("data") ?: throw CalendarFailure.InvalidData
    }
}

internal sealed class CalendarFailure(message: String) : Exception(message) {
    data object Authentication : CalendarFailure("暂时无法获取账户信息，请重试")
    data object Unavailable : CalendarFailure("暂时无法获取安排，请稍后重试")
    data object InvalidData : CalendarFailure("无法读取返回的日程，请重试")
}

internal data class CachedCalendar(val content: String, val fetchedAt: Instant)

internal class CalendarCache(private val directory: File, private val account: String) {
    fun read(kind: CalendarKind): CachedCalendar? = runCatching {
        val json = JSONObject(File(directory, "${kind.name.lowercase()}.json").readText())
        if (json.optInt("schema") != 1 || json.optString("account") != account || json.optString("kind") != kind.name) return null
        val content = json.getString("content")
        IcsCalendar.parse(content, kind)
        CachedCalendar(content, Instant.parse(json.getString("fetchedAt")))
    }.getOrNull()

    fun write(kind: CalendarKind, content: String, fetchedAt: Instant) {
        directory.mkdirs()
        val file = File(directory, "${kind.name.lowercase()}.json")
        val temporary = File(directory, "${kind.name.lowercase()}.tmp")
        temporary.writeText(JSONObject().put("schema", 1).put("account", account)
            .put("kind", kind.name).put("content", content).put("fetchedAt", fetchedAt.toString()).toString())
        if (!temporary.renameTo(file)) {
            file.writeText(temporary.readText())
            temporary.delete()
        }
    }
}

internal data class CalendarState(
    val entries: List<CalendarEntry> = emptyList(),
    val loading: Boolean = false,
    val error: String? = null,
    val updatedAt: Instant? = null,
)

internal class CalendarStore(context: Context) {
    private val api = CalendarApi(NetworkTransport(), BuildConfig.WATCH_ACCOUNT, BuildConfig.WATCH_PASSWORD)
    private val cache = CalendarCache(File(context.filesDir, "calendars"), BuildConfig.WATCH_ACCOUNT)
    var courses by androidx.compose.runtime.mutableStateOf(CalendarState())
        private set
    var school by androidx.compose.runtime.mutableStateOf(CalendarState())
        private set
    private var started = false
    private var refreshing = false
    private var lastRefresh: Instant? = null

    fun state(kind: CalendarKind): CalendarState = if (kind == CalendarKind.COURSES) courses else school
    private fun update(kind: CalendarKind, state: CalendarState) {
        if (kind == CalendarKind.COURSES) courses = state else school = state
    }

    suspend fun start() {
        if (started) return
        started = true
        for (kind in CalendarKind.entries) {
            val saved = withContext(Dispatchers.IO) { cache.read(kind) } ?: continue
            update(kind, CalendarState(IcsCalendar.parse(saved.content, kind), updatedAt = saved.fetchedAt))
        }
        refresh()
    }

    suspend fun refreshIfNeeded() {
        if (lastRefresh == null || Instant.now().isAfter(lastRefresh!!.plusSeconds(300))) refresh()
    }

    suspend fun refresh() {
        if (refreshing) return
        refreshing = true
        try {
            coroutineScope {
                CalendarKind.entries.map { kind -> async { refreshOne(kind) } }.forEach { it.await() }
            }
        } finally {
            refreshing = false
            lastRefresh = Instant.now()
        }
    }

    private suspend fun refreshOne(kind: CalendarKind) {
        update(kind, state(kind).copy(loading = true, error = null))
        try {
            val content = api.fetch(kind)
            val entries = IcsCalendar.parse(content, kind)
            val now = Instant.now()
            update(kind, CalendarState(entries, updatedAt = now))
            withContext(Dispatchers.IO) { runCatching { cache.write(kind, content, now) } }
        } catch (error: Exception) {
            val message = (error as? CalendarFailure)?.message ?: "暂时无法连接，请稍后重试"
            update(kind, state(kind).copy(loading = false, error = message))
        }
    }
}
