package dev.so1ve.bitree

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WidgetAgendaTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val agendaFile: File get() = File(context.filesDir, "agenda.json")

    @Before
    fun setUp() {
        agendaFile.delete()
        File(context.filesDir, "schedule.json").delete()
    }

    @After
    fun tearDown() {
        agendaFile.delete()
    }

    @Test
    fun readsVersionedAgendaAndExcludesDoneAndDeletedEntries() {
        val entries = JSONArray()
            .put(deadline("待完成"))
            .put(deadline("已完成").put("done", true))
            .put(deadline("已删除").put("deleted", true))
        agendaFile.writeText(
            JSONObject().put("schemaVersion", 2).put("entries", entries).toString(),
        )

        val content = readWidgetContent(context)

        assertEquals(listOf("待完成"), content.entries.map { it.title })
        assertEquals(WidgetEntryKind.DEADLINE, content.entries.single().kind)
        assertEquals(true, content.entries.single().allDay)
    }

    @Test
    fun legacyAgendaRequestsOpeningTheAppForMigration() {
        agendaFile.writeText(JSONArray().put(deadline("旧版日程")).toString())

        assertEquals(
            context.getString(R.string.widget_read_error),
            readWidgetContent(context).emptyMessage,
        )
    }

    @Test
    fun emptyVersionedAgendaShowsEmptyStateInsteadOfReadError() {
        agendaFile.writeText(
            JSONObject().put("schemaVersion", 2).put("entries", JSONArray()).toString(),
        )

        val content = readWidgetContent(context)

        assertEquals(emptyList<WidgetEntry>(), content.entries)
        val today = Calendar.getInstance(TimeZone.getTimeZone("Asia/Shanghai"))
        val expected = if (today.get(Calendar.HOUR_OF_DAY) >= 21) {
            R.string.widget_tomorrow_empty
        } else {
            R.string.widget_today_empty
        }
        assertEquals(context.getString(expected), content.emptyMessage)
    }

    @Test
    fun invalidAgendaStillReportsReadError() {
        agendaFile.writeText("{\"schemaVersion\":2,\"entries\":null}")

        assertEquals(
            context.getString(R.string.widget_read_error),
            readWidgetContent(context).emptyMessage,
        )
    }

    @Test
    fun endedAgendaEntriesStayHiddenAndCoursesStillDriveNextUpdate() {
        val now = timestamp("2026-11-09T12:00:00.000Z")
        val courses = JSONArray()
            .put(course("已下课", 1))
            .put(course("下午课", 6))
        val term = JSONObject()
            .put("firstMonday", "2026-11-09")
            .put("courses", courses)
        File(context.filesDir, "schedule.json").writeText(
            JSONObject().put("schemaVersion", 2).put("selectedTerm", "term")
                .put("semesters", JSONObject().put("term", term)).toString(),
        )
        agendaFile.writeText(
            JSONObject().put("schemaVersion", 2)
                .put("entries", JSONArray().put(timed("已结束日程", "event")))
                .toString(),
        )

        val content = readWidgetContent(context, now)

        assertEquals(listOf("下午课"), content.entries.map { it.title })
        assertEquals(timestamp("2026-11-09T14:05:00.000Z"), content.nextUpdate)
        assertTrue(content.nextUpdate > now)
    }

    private fun timed(title: String, kind: String): JSONObject = JSONObject()
        .put("id", title)
        .put("title", title)
        .put("kind", kind)
        .put("startsAt", "2026-11-09T09:00:00.000Z")
        .put("endsAt", "2026-11-09T11:00:00.000Z")
        .put("allDay", false)
        .put("location", "")
        .put("done", false)
        .put("deleted", false)

    private fun course(name: String, section: Int): JSONObject = JSONObject()
        .put("name", name)
        .put("room", "")
        .put("campus", "")
        .put("weekday", 1)
        .put("startSection", section)
        .put("endSection", section)
        .put("weeks", JSONArray().put(1))

    private fun timestamp(value: String): Long =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT)
            .apply { timeZone = TimeZone.getTimeZone("Asia/Shanghai") }
            .parse(value)!!.time

    private fun deadline(title: String): JSONObject {
        val zone = TimeZone.getTimeZone("Asia/Shanghai")
        val today = Calendar.getInstance(zone).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT)
            .apply { timeZone = zone }
            .format(today.time)
        return JSONObject()
            .put("id", title)
            .put("title", title)
            .put("kind", "deadline")
            .put("startsAt", timestamp)
            .put("endsAt", JSONObject.NULL)
            .put("allDay", true)
            .put("location", "")
            .put("notes", "")
            .put("done", false)
            .put("deleted", false)
            .put("local", true)
    }
}
