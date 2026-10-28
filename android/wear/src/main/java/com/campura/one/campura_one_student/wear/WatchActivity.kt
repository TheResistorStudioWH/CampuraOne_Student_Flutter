package com.campura.one.campura_one_student.wear

import android.os.Bundle
import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.focusable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.DatePicker
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.dynamicColorScheme
import androidx.wear.compose.foundation.rotary.RotaryScrollableDefaults
import androidx.wear.compose.foundation.rotary.rotaryScrollable
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

class WatchActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ViewState.restore(applicationContext)
        val store = CalendarStore(applicationContext)
        setContent {
            val scope = rememberCoroutineScope()
            val lifecycle = LocalLifecycleOwner.current
            LaunchedEffect(store) { store.start() }
            DisposableEffect(lifecycle, store) {
                val observer = LifecycleEventObserver { _, event ->
                    if (event == Lifecycle.Event.ON_RESUME) scope.launch { store.refreshIfNeeded() }
                }
                lifecycle.lifecycle.addObserver(observer)
                onDispose { lifecycle.lifecycle.removeObserver(observer) }
            }
            MaterialTheme(colorScheme = dynamicColorScheme(LocalContext.current) ?: ColorScheme()) {
                WatchRoot(store)
            }
        }
    }
}

@Composable
private fun WatchRoot(store: CalendarStore) {
    val nav = rememberSwipeDismissableNavController()
    AppScaffold {
        SwipeDismissableNavHost(navController = nav, startDestination = "home") {
            composable("home") { HomeScreen(store) { nav.navigate(it.name) } }
            for (kind in CalendarKind.entries) {
                composable(kind.name) {
                    CalendarScreen(kind, store,
                        onOptions = { nav.navigate("${kind.name}/options") },
                        onPicker = { nav.navigate("${kind.name}/picker") },
                        onDetail = { id -> nav.navigate("${kind.name}/event/${java.net.URLEncoder.encode(id, "UTF-8")}") },
                    )
                }
                composable("${kind.name}/options") { OptionsScreen(kind, store, { nav.popBackStack() }, { nav.navigate("${kind.name}/picker") }) }
                composable("${kind.name}/picker") { DatePickerScreen(kind) { nav.popBackStack() } }
                composable("${kind.name}/event/{id}") { entry ->
                    val id = java.net.URLDecoder.decode(entry.arguments?.getString("id") ?: "", "UTF-8")
                    val event = IcsCalendar.agenda(store.state(kind).entries, ViewState.selected[kind] ?: LocalDate.now()).find { it.id == id }
                    if (event == null) SimpleList { item { Text("事项已更新") } }
                    else EventDetail(event)
                }
            }
        }
    }
}

private object ViewState {
    var selected by mutableStateOf(mapOf(CalendarKind.COURSES to LocalDate.now(), CalendarKind.SCHOOL to LocalDate.now()))
    var mode by mutableStateOf(mapOf(CalendarKind.COURSES to CalendarMode.DAY, CalendarKind.SCHOOL to CalendarMode.LIST))
    fun restore(context: Context) {
        val preferences = context.getSharedPreferences("watch_views", Context.MODE_PRIVATE)
        mode = CalendarKind.entries.associateWith { kind ->
            CalendarMode.entries.find { it.name == preferences.getString(kind.name, null) }
                ?: if (kind == CalendarKind.COURSES) CalendarMode.DAY else CalendarMode.LIST
        }
    }
    fun changeMode(context: Context, kind: CalendarKind, choice: CalendarMode) {
        mode = mode.toMutableMap().apply { put(kind, choice) }
        context.getSharedPreferences("watch_views", Context.MODE_PRIVATE).edit().putString(kind.name, choice.name).apply()
    }
}

@Composable
private fun HomeScreen(store: CalendarStore, open: (CalendarKind) -> Unit) = SimpleList {
    item { Text("域校屿", style = MaterialTheme.typography.titleLarge, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) }
    for (kind in CalendarKind.entries) {
        item {
            val state = store.state(kind)
            val count = IcsCalendar.eventsOn(state.entries, LocalDate.now()).size
            Button(onClick = { open(kind) }, modifier = Modifier.fillMaxWidth(),
                icon = { Icon(if (kind == CalendarKind.COURSES) Icons.Filled.Schedule else Icons.Filled.CalendarMonth, null) },
                label = { Text(kind.title) },
                secondaryLabel = { Text(if (state.loading && state.entries.isEmpty()) "正在更新" else if (count == 0) "今天没有安排" else "今天 $count 项安排") },
            )
        }
    }
}

@Composable
private fun CalendarScreen(kind: CalendarKind, store: CalendarStore, onOptions: () -> Unit, onPicker: () -> Unit, onDetail: (String) -> Unit) {
    val state = store.state(kind)
    val context = LocalContext.current
    val selected = ViewState.selected[kind] ?: LocalDate.now()
    val mode = ViewState.mode[kind] ?: CalendarMode.DAY
    SimpleList(scrollKey = "$kind-$mode-$selected") {
        item { Text(kind.title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center) }
        item { Button(onClick = onOptions, modifier = Modifier.fillMaxWidth(), label = { Text("显示方式 · ${mode.title}") }) }
        if (state.entries.isEmpty() && state.loading) item { Text("正在更新${kind.title}") }
        else if (state.entries.isEmpty() && state.error != null) {
            item { Text(state.error) }
            item { val scope = rememberCoroutineScope(); Button(onClick = { scope.launch { store.refresh() } }, label = { Text("重试") }) }
        } else {
            if (state.error != null) item { Text("暂未更新 · 显示上次内容", color = MaterialTheme.colorScheme.onSurfaceVariant) }
            when (mode) {
                CalendarMode.LIST -> agendaItems(state.entries, selected, onPicker, onDetail)
                CalendarMode.DAY -> {
                    item { DateControls(selected, "日", onPicker, { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, selected.minusDays(1)) } }, { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, selected.plusDays(1)) } }) }
                    val events = IcsCalendar.eventsOn(state.entries, selected)
                    if (kind == CalendarKind.COURSES && events.any { !it.allDay }) {
                        for (event in events.filter { it.allDay }) item { EventButton(event, onDetail) }
                        item { DayTimeline(events, selected, onDetail) }
                    } else eventItems(events, onDetail)
                }
                CalendarMode.WEEK -> {
                    item { DateControls(selected, "周", onPicker, { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, selected.minusWeeks(1)) } }, { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, selected.plusWeeks(1)) } }) }
                    for (day in IcsCalendar.week(selected)) item {
                        val events = IcsCalendar.eventsOn(state.entries, day)
                        Button(onClick = { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, day) }; ViewState.changeMode(context, kind, CalendarMode.DAY) },
                            modifier = Modifier.fillMaxWidth(), label = { Text(dayLabel(day)) }, secondaryLabel = {
                                Column {
                                    Text(if (events.isEmpty()) "没有课程" else "${events.size} 节 · ${events.first().start.format(timeFormat)} 起")
                                    WeekTimeline(events, day)
                                }
                            })
                    }
                }
                CalendarMode.MONTH -> {
                    item { DateControls(selected, "月", onPicker, { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, selected.minusMonths(1)) } }, { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, selected.plusMonths(1)) } }) }
                    item { MonthGrid(kind, state.entries, selected) }
                }
            }
            if (selected != LocalDate.now() || mode == CalendarMode.LIST) item {
                Button(onClick = { ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, LocalDate.now()) } }, modifier = Modifier.fillMaxWidth(), label = { Text("今天") })
            }
        }
    }
}

private val timeFormat = DateTimeFormatter.ofPattern("HH:mm", Locale.CHINA)
private fun dayLabel(day: LocalDate): String = "${day.monthValue}月${day.dayOfMonth}日 ${day.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.CHINA)}"
internal fun eventRange(event: CalendarEntry): String {
    if (event.allDay) {
        val endDay = event.end.minusNanos(1).toLocalDate()
        val first = "${event.start.monthValue}月${event.start.dayOfMonth}日"
        val last = "${endDay.monthValue}月${endDay.dayOfMonth}日"
        return if (event.start.toLocalDate() == endDay) "$first · 全天" else "$first – $last · 全天"
    }
    return if (event.start.toLocalDate() == event.end.toLocalDate())
        "${event.start.format(timeFormat)}–${event.end.format(timeFormat)}"
    else "${dayLabel(event.start.toLocalDate())} ${event.start.format(timeFormat)} – ${dayLabel(event.end.toLocalDate())} ${event.end.format(timeFormat)}"
}

@Composable
private fun DateControls(day: LocalDate, unit: String, picker: () -> Unit, previous: () -> Unit, next: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Button(onClick = previous, modifier = Modifier.size(42.dp).semantics { contentDescription = if (unit == "月") "上个月" else if (unit == "周") "上一周" else "前一天" }, label = { Text("‹") })
        Text(if (unit == "月") "${day.year}/${day.monthValue}" else dayLabel(day),
            modifier = Modifier.weight(1f).clickable(onClick = picker).semantics { contentDescription = "选择日期，${day.year}年${day.monthValue}月${day.dayOfMonth}日" }, textAlign = TextAlign.Center,
            maxLines = 2, style = MaterialTheme.typography.labelMedium)
        Button(onClick = next, modifier = Modifier.size(42.dp).semantics { contentDescription = if (unit == "月") "下个月" else if (unit == "周") "下一周" else "后一天" }, label = { Text("›") })
    }
}

private fun LazyListScope.agendaItems(source: List<CalendarEntry>, selected: LocalDate, picker: () -> Unit, detail: (String) -> Unit) {
    item { Button(onClick = picker, modifier = Modifier.fillMaxWidth(),
        label = { Text("选择日期") }, secondaryLabel = { Text(dayLabel(selected)) }) }
    val events = IcsCalendar.agenda(source, selected)
    if (events.isEmpty()) item { Text("暂无安排") }
    var last: LocalDate? = null
    for (event in events) {
        val day = event.start.toLocalDate()
        if (day != last) item { Text(dayLabel(day), color = MaterialTheme.colorScheme.primary) }
        item { EventButton(event, detail) }
        last = day
    }
}

private fun LazyListScope.eventItems(events: List<CalendarEntry>, detail: (String) -> Unit) {
    if (events.isEmpty()) item { Text("这一天没有安排") }
    for (event in events) item { EventButton(event, detail) }
}

@Composable
private fun EventButton(event: CalendarEntry, detail: (String) -> Unit) {
    Button(onClick = { detail(event.id) }, modifier = Modifier.fillMaxWidth(), label = {
        Text(event.title, maxLines = 3, overflow = TextOverflow.Ellipsis)
    }, secondaryLabel = { Text(eventRange(event), maxLines = 2) })
}

internal data class TimelineSlot(val event: CalendarEntry, val lane: Int, val lanes: Int)

internal fun timelineSlots(events: List<CalendarEntry>): List<TimelineSlot> {
    val sorted = events.filter { !it.allDay }.sortedBy { it.start.toInstant() }
    val output = mutableListOf<TimelineSlot>()
    val group = mutableListOf<Pair<CalendarEntry, Int>>()
    val ends = mutableListOf<java.time.Instant>()
    var groupEnd: java.time.Instant? = null
    fun flush() {
        if (group.isNotEmpty()) output += group.map { TimelineSlot(it.first, it.second, ends.size) }
        group.clear(); ends.clear(); groupEnd = null
    }
    for (event in sorted) {
        if (groupEnd != null && !event.start.toInstant().isBefore(groupEnd)) flush()
        val lane = ends.indexOfFirst { !it.isAfter(event.start.toInstant()) }.let { if (it < 0) ends.size else it }
        if (lane == ends.size) ends += event.end.toInstant() else ends[lane] = event.end.toInstant()
        group += event to lane
        if (groupEnd == null || event.end.toInstant().isAfter(groupEnd)) groupEnd = event.end.toInstant()
    }
    flush()
    return output
}

@Composable
private fun DayTimeline(events: List<CalendarEntry>, selected: LocalDate, detail: (String) -> Unit) {
    val slots = timelineSlots(events)
    val first = min(8, slots.minOf { displayMinutes(it.event, selected).first / 60 })
    val last = max(20, slots.maxOf { ceil(displayMinutes(it.event, selected).second / 60.0).toInt() }).coerceAtMost(24)
    val row = 42.dp
    BoxWithConstraints(Modifier.fillMaxWidth().height(row * (last - first) + 12.dp)) {
        val area = maxWidth - 30.dp
        for (hour in first..last) {
            val y = row * (hour - first)
            Text("%02d".format(hour), fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.offset(y = y).width(25.dp))
            Box(Modifier.offset(x = 29.dp, y = y + 7.dp).width(area).height(1.dp).background(MaterialTheme.colorScheme.outlineVariant))
        }
        for (slot in slots) {
            val event = slot.event
            val (startMinute, endMinute) = displayMinutes(event, selected)
            val y = row * ((startMinute - first * 60) / 60f)
            val height = max(32f, (endMinute - startMinute) / 60f * 42f - 2f).dp
            val laneWidth = area / slot.lanes
            Column(Modifier.offset(x = 30.dp + laneWidth * slot.lane, y = y).width(laneWidth - 2.dp)
                .height(height).background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(6.dp))
                .clickable { detail(event.id) }.padding(4.dp)) {
                Text(event.title, fontSize = 11.sp, color = MaterialTheme.colorScheme.onPrimaryContainer,
                    maxLines = if (height > 60.dp) 3 else 1, overflow = TextOverflow.Ellipsis)
                Text(event.start.format(timeFormat), fontSize = 9.sp, color = MaterialTheme.colorScheme.onPrimaryContainer)
            }
        }
    }
}

internal fun displayMinutes(event: CalendarEntry, selected: LocalDate): Pair<Int, Int> {
    val start = if (event.start.toLocalDate().isBefore(selected)) 0 else event.start.hour * 60 + event.start.minute
    val end = if (event.end.toLocalDate().isAfter(selected)) 24 * 60 else event.end.hour * 60 + event.end.minute
    return start to end.coerceAtLeast(start + 1)
}

@Composable
private fun MonthGrid(kind: CalendarKind, entries: List<CalendarEntry>, selected: LocalDate) {
    val context = LocalContext.current
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row { for (name in listOf("一", "二", "三", "四", "五", "六", "日")) Text(name, modifier = Modifier.weight(1f), textAlign = TextAlign.Center, fontSize = 10.sp) }
        for (week in IcsCalendar.month(selected).chunked(7)) {
            Row {
                for (day in week) {
                    Box(modifier = Modifier.weight(1f).height(31.dp).then(if (day != null) Modifier.clickable {
                        ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, day) }
                        ViewState.changeMode(context, kind, CalendarMode.DAY)
                    }.semantics { contentDescription = "${day.monthValue}月${day.dayOfMonth}日，${IcsCalendar.eventsOn(entries, day).size}项安排" } else Modifier), contentAlignment = Alignment.Center) {
                        if (day != null) {
                            val count = IcsCalendar.eventsOn(entries, day).size
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("${day.dayOfMonth}", fontSize = 11.sp, color = if (day == LocalDate.now()) MaterialTheme.colorScheme.primary else Color.Unspecified)
                                if (count > 0) Box(Modifier.size(3.dp).background(MaterialTheme.colorScheme.tertiary, CircleShape))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WeekTimeline(events: List<CalendarEntry>, day: LocalDate) {
    val background = MaterialTheme.colorScheme.surfaceContainerHigh
    val foreground = MaterialTheme.colorScheme.primary
    Canvas(Modifier.fillMaxWidth().height(5.dp)) {
        drawRoundRect(background, cornerRadius = CornerRadius(size.height / 2))
        for (event in events.filter { !it.allDay }) {
            val (startMinute, endMinute) = displayMinutes(event, day)
            val start = ((startMinute - 360) / 960f).coerceIn(0f, 1f)
            val end = ((endMinute - 360) / 960f).coerceIn(0f, 1f)
            if (end > start) drawRoundRect(foreground, topLeft = Offset(size.width * start, 0f),
                size = Size(size.width * (end - start), size.height), cornerRadius = CornerRadius(size.height / 2))
        }
    }
}

@Composable
private fun OptionsScreen(kind: CalendarKind, store: CalendarStore, back: () -> Unit, picker: () -> Unit) {
    val context = LocalContext.current
    SimpleList {
        item { Text("显示选项", style = MaterialTheme.typography.titleMedium) }
        for (mode in CalendarMode.entries.filter { kind == CalendarKind.COURSES || it != CalendarMode.WEEK }) item {
            Button(onClick = { ViewState.changeMode(context, kind, mode); back() },
                modifier = Modifier.fillMaxWidth(), label = { Text(if (ViewState.mode[kind] == mode) "✓ ${mode.title}" else mode.title) })
        }
        item { Button(onClick = picker, modifier = Modifier.fillMaxWidth(), label = { Text("选择日期") }) }
        item { val scope = rememberCoroutineScope(); Button(onClick = { scope.launch { store.refresh() }; back() }, modifier = Modifier.fillMaxWidth(), label = { Text("刷新") }) }
        store.state(kind).updatedAt?.let { updated -> item { Text("更新于 ${DateTimeFormatter.ofPattern("M/d HH:mm").withZone(java.time.ZoneId.systemDefault()).format(updated)}") } }
    }
}

@Composable
private fun DatePickerScreen(kind: CalendarKind, back: () -> Unit) {
    DatePicker(initialDate = ViewState.selected[kind] ?: LocalDate.now(), onDatePicked = { date ->
        ViewState.selected = ViewState.selected.toMutableMap().apply { put(kind, date) }
        back()
    })
}

@Composable
private fun EventDetail(event: CalendarEntry) = SimpleList {
    item { Text(event.title, style = MaterialTheme.typography.titleMedium) }
    item { Text(dayLabel(event.start.toLocalDate())) }
    item { Text(eventRange(event)) }
    event.location?.let { item { Text(it) } }
    event.notes?.let { item { Text(it) } }
}

@Composable
private fun SimpleList(scrollKey: Any? = null, content: androidx.compose.foundation.lazy.LazyListScope.() -> Unit) {
    val state = rememberLazyListState()
    val focusRequester = remember { FocusRequester() }
    val lifecycle = LocalLifecycleOwner.current
    LaunchedEffect(Unit) { focusRequester.requestFocus() }
    LaunchedEffect(scrollKey) { if (scrollKey != null) state.scrollToItem(0) }
    DisposableEffect(lifecycle, focusRequester) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) focusRequester.requestFocus()
        }
        lifecycle.lifecycle.addObserver(observer)
        onDispose { lifecycle.lifecycle.removeObserver(observer) }
    }
    ScreenScaffold(scrollState = state) { padding ->
        LazyColumn(state = state, contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = padding.calculateTopPadding(), bottom = padding.calculateBottomPadding()),
            verticalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxSize()
                .rotaryScrollable(RotaryScrollableDefaults.behavior(state), focusRequester)
                .focusRequester(focusRequester).focusable(), content = content)
    }
}
