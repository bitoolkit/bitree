package dev.so1ve.bitree

import android.content.Context
import android.content.res.Configuration
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

internal object BuildingColors {
    private data class Palette(val light: IntArray, val dark: IntArray)
    private data class Rule(
        val name: String,
        val area: String?,
        val pattern: Regex,
        val palette: Palette,
    )
    private data class Match(val start: Int, val end: Int, val rule: Rule)
    private data class Table(val neutral: Palette, val rules: List<Rule>)

    private var table: Table? = null
    private val customColors = mutableMapOf<Boolean, Map<String, IntArray>>()
    private const val PREFERENCES = "widget_appearance"
    private fun colorsKey(dark: Boolean) = if (dark) "darkCourseColors" else "lightCourseColors"
    private val otherCampuses = Regex("中关村|西山|珠海|雄安|怀来")
    private val spacing = Regex("[\\s\\u00A0\\u3000·._\\-—–（）()\\[\\]【】]")

    fun savePalette(context: Context, dark: Boolean, colors: Map<String, List<Number>>) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            .putString(colorsKey(dark), JSONObject(colors).toString()).apply()
        customColors[dark] = colors.mapValues { (_, values) ->
            values.map { it.toInt() }.toIntArray()
        }
    }

    private fun readPalette(context: Context, dark: Boolean): Map<String, IntArray> {
        return customColors[dark] ?: run {
            try {
                val saved = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                    .getString(colorsKey(dark), "{}") ?: "{}"
                val json = JSONObject(saved)
                json.keys().asSequence().associateWith { area ->
                    val values = json.getJSONArray(area)
                    require(values.length() == 2)
                    IntArray(2) { values.getLong(it).toInt() }
                }
            } catch (error: Exception) {
                Log.w("BITree", "无法读取桌面组件的课程配色", error)
                emptyMap()
            }.also { customColors[dark] = it }
        }
    }

    fun widgetBackground(context: Context): Int {
        val fallback = context.getColor(R.color.widget_surface)
        if (!isDark(context)) return fallback
        return readPalette(context, true)["surface"]?.firstOrNull() ?: fallback
    }

    private fun isDark(context: Context): Boolean =
        context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

    fun forCourse(context: Context, room: String, campus: String): IntArray {
        val data = table ?: read(context).also { table = it }
        val normalized = room.map { char ->
            if (char.code in 0xFF01..0xFF5E) (char.code - 0xFEE0).toChar() else char
        }.joinToString("").uppercase(java.util.Locale.ROOT).replace(spacing, "")
        val matches = if (otherCampuses.containsMatchIn("$campus $room")) emptyList() else {
            data.rules.flatMap { rule ->
                rule.pattern.findAll(normalized).map { match ->
                    Match(match.range.first, match.range.last + 1, rule)
                }.toList()
            }
        }
        val buildings = matches.filter { match ->
            matches.none { other ->
                other.start <= match.start && other.end >= match.end &&
                    other.end - other.start > match.end - match.start
            }
        }.map { it.rule }.distinctBy { it.name }
        val building = buildings.singleOrNull()
        val palette = building?.palette ?: data.neutral
        WidgetColors.course(context, building?.area)?.let { return it }
        val dark = isDark(context)
        return readPalette(context, dark)[building?.area ?: "neutral"]
            ?: if (dark) palette.dark else palette.light
    }

    private fun read(context: Context): Table {
        val json = context.assets.open("building_palette.json").bufferedReader().use {
            JSONObject(it.readText())
        }
        fun colors(array: JSONArray) = IntArray(array.length()) { array.getLong(it).toInt() }
        fun palette(row: JSONObject) = Palette(
            colors(row.getJSONArray("light")), colors(row.getJSONArray("dark")),
        )
        val rows = json.getJSONArray("buildings")
        return Table(
            palette(json.getJSONObject("neutral")),
            (0 until rows.length()).map { index ->
                val row = rows.getJSONObject(index)
                Rule(
                    row.getString("name"),
                    row.optString("area").takeIf { it.isNotEmpty() },
                    Regex(row.getString("pattern")),
                    palette(row),
                )
            },
        )
    }
}
