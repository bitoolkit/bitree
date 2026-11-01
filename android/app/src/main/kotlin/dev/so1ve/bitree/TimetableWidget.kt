package dev.so1ve.bitree

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.TextPaint
import android.view.View
import android.widget.RemoteViews
import androidx.core.widget.RemoteViewsCompat

open class TimetableWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateAll(context)
    }

    override fun onDisabled(context: Context) {
        updateAll(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> updateAll(context)
        }
    }

    companion object {
        private const val REFRESH = "dev.so1ve.bitree.widget.REFRESH"
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val providers = listOf(
                TimetableWidget::class.java to 1,
                WideTimetableWidget::class.java to 2,
            )
            val widgets = providers.flatMap { (provider, columns) ->
                manager.getAppWidgetIds(ComponentName(context, provider))
                    .map { id -> id to columns }
            }
            val alarm = context.getSystemService(AlarmManager::class.java)
            val refresh = PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, TimetableWidget::class.java).setAction(REFRESH),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (widgets.isEmpty()) {
                alarm.cancel(refresh)
                return
            }

            val content = readWidgetContent(context)
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            widgets.forEach { (id, columns) ->
                val views = RemoteViews(context.packageName, R.layout.timetable_widget)
                views.setInt(
                    R.id.widget_content, "setBackgroundColor", WidgetColors.background(context),
                )
                views.setTextColor(R.id.widget_date, WidgetColors.text(context))
                views.setTextColor(R.id.widget_empty, WidgetColors.muted(context))
                views.setTextColor(R.id.widget_message, WidgetColors.accent(context))
                views.setTextViewText(R.id.widget_date, content.heading)
                views.setTextViewText(R.id.widget_empty, content.emptyMessage)
                views.setEmptyView(R.id.widget_courses, R.id.widget_empty)
                views.setOnClickPendingIntent(R.id.widget_root, open)
                // Collection views consume taps; forward them to the same app launch.
                views.setPendingIntentTemplate(R.id.widget_courses, open)

                views.setViewVisibility(
                    R.id.widget_message,
                    if (content.entries.isEmpty()) View.GONE else View.VISIBLE,
                )
                if (content.entries.isNotEmpty()) {
                    views.setTextViewText(
                        R.id.widget_message,
                        context.getString(R.string.widget_entry_count, content.entries.size),
                    )
                }

                val widthPx = widgetWidthPx(context, manager, id)
                val items = entryItems(context, content.entries, widthPx, columns)

                RemoteViewsCompat.setRemoteAdapter(
                    context, views, id, R.id.widget_courses, items,
                )
                manager.updateAppWidget(id, views)
            }

            // Inexact, non-wakeup alarms update visible data without an alarm permission.
            alarm.set(AlarmManager.RTC, content.nextUpdate, refresh)
        }

        private fun widgetWidthPx(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
        ): Float {
            val widthDp = manager.getAppWidgetOptions(id)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)

            return if (widthDp > 0) {
                widthDp * context.resources.displayMetrics.density
            } else {
                manager.getAppWidgetInfo(id).minWidth.toFloat()
            }
        }

        private fun entryItems(
            context: Context,
            entries: List<WidgetEntry>,
            widthPx: Float,
            columns: Int,
        ): RemoteViewsCompat.RemoteCollectionItems {
            val resources = context.resources
            val outerPadding = resources.getDimension(R.dimen.widget_padding)
            val columnSpacing = resources.getDimension(R.dimen.widget_column_spacing)
            val cardPadding = resources.getDimension(R.dimen.widget_course_padding)
            val contentWidth = widthPx - 2 * outerPadding
            val columnWidth = (contentWidth - (columns - 1) * columnSpacing) / columns
            val textWidth = columnWidth - 2 * cardPadding
            val paint = TextPaint().apply {
                textSize = resources.getDimension(R.dimen.widget_course_details_size)
            }

            val items = RemoteViewsCompat.RemoteCollectionItems.Builder()
                .setViewTypeCount(1)
            entries.chunked(columns).forEachIndexed { index, entriesInRow ->
                val row = RemoteViews(context.packageName, R.layout.widget_row)
                row.removeAllViews(R.id.widget_first_column)
                row.removeAllViews(R.id.widget_second_column)
                val secondColumn = if (columns == 2) View.VISIBLE else View.GONE
                row.setViewVisibility(R.id.widget_second_column, secondColumn)
                row.setViewVisibility(R.id.widget_column_gap, secondColumn)
                entriesInRow.forEachIndexed { column, entry ->
                    val details = "${entry.startTimeLabel} ${entry.location}".trimEnd()
                    val label = if (paint.measureText(details) <= textWidth) {
                        details
                    } else {
                        entry.startTimeLabel
                    }
                    row.addView(
                        if (column == 0) R.id.widget_first_column else R.id.widget_second_column,
                        entryView(context, entry, label),
                    )
                }
                row.setOnClickFillInIntent(R.id.widget_row, Intent())
                items.addItem(index.toLong(), row)
            }

            return items.build()
        }

        private fun entryView(
            context: Context,
            entry: WidgetEntry,
            details: String,
        ): RemoteViews {
            val colors = when (entry.kind) {
                WidgetEntryKind.COURSE -> BuildingColors.forCourse(context, entry.location, entry.campus)
                WidgetEntryKind.EXAM -> intArrayOf(
                    context.getColor(R.color.widget_course_copper),
                    context.getColor(R.color.widget_course_copper_text),
                )
                WidgetEntryKind.DEADLINE -> intArrayOf(
                    context.getColor(R.color.widget_course_yellow),
                    context.getColor(R.color.widget_course_yellow_text),
                )
                WidgetEntryKind.EVENT -> intArrayOf(
                    context.getColor(R.color.widget_course_teal),
                    context.getColor(R.color.widget_course_teal_text),
                )
            }
            return RemoteViews(context.packageName, R.layout.widget_course).apply {
                setInt(R.id.widget_course_content, "setBackgroundColor", colors[0])
                setTextViewText(R.id.widget_course_name, entry.titleLabel)
                setTextViewText(R.id.widget_course_details, details)
                setTextColor(R.id.widget_course_name, colors[1])
                setTextColor(R.id.widget_course_details, colors[1])
                setContentDescription(
                    R.id.widget_course,
                    listOf(entry.kind.label, entry.title, entry.timeLabel, entry.location)
                        .filter { it.isNotEmpty() }.joinToString("，"),
                )
            }
        }
    }
}

class WideTimetableWidget : TimetableWidget()
