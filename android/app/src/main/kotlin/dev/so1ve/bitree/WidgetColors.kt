package dev.so1ve.bitree

import android.content.Context
import android.content.res.Configuration
import android.os.Build

/** Widget surfaces follow Android; courses opt into the system palette separately. */
internal object WidgetColors {
    private const val PREFERENCES = "widget_appearance"
    private const val USE_SYSTEM_PALETTE = "useSystemPalette"

    fun saveUseSystemPalette(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            .putBoolean(USE_SYSTEM_PALETTE, enabled).apply()
    }

    fun background(context: Context): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getColor(R.color.widget_system_surface)
        } else {
            BuildingColors.widgetBackground(context)
        }

    fun text(context: Context): Int = context.getColor(
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) R.color.widget_system_text
        else R.color.widget_text,
    )

    fun muted(context: Context): Int = context.getColor(
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) R.color.widget_system_muted
        else R.color.widget_muted,
    )

    fun accent(context: Context): Int = context.getColor(
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) R.color.widget_system_accent
        else R.color.widget_accent,
    )

    /** Preserve campus grouping with three system accent families and tonal variations. */
    fun course(context: Context, area: String?): IntArray? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        if (!context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .getBoolean(USE_SYSTEM_PALETTE, false)) return null
        val dark = context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        val colors = if (dark) {
            when (area) {
                "northTeaching" -> intArrayOf(
                    android.R.color.system_accent1_700, android.R.color.system_accent1_100,
                )
                "wencui" -> intArrayOf(
                    android.R.color.system_accent2_700, android.R.color.system_accent2_100,
                )
                "southScience" -> intArrayOf(
                    android.R.color.system_accent3_700, android.R.color.system_accent3_100,
                )
                "eastFacilities" -> intArrayOf(
                    android.R.color.system_accent1_800, android.R.color.system_accent1_100,
                )
                "southEngineering" -> intArrayOf(
                    android.R.color.system_accent3_800, android.R.color.system_accent3_100,
                )
                else -> intArrayOf(
                    android.R.color.system_neutral2_700, android.R.color.system_neutral2_100,
                )
            }
        } else {
            when (area) {
                "northTeaching" -> intArrayOf(
                    android.R.color.system_accent1_100, android.R.color.system_accent1_900,
                )
                "wencui" -> intArrayOf(
                    android.R.color.system_accent2_100, android.R.color.system_accent2_900,
                )
                "southScience" -> intArrayOf(
                    android.R.color.system_accent3_100, android.R.color.system_accent3_900,
                )
                "eastFacilities" -> intArrayOf(
                    android.R.color.system_accent1_50, android.R.color.system_accent1_900,
                )
                "southEngineering" -> intArrayOf(
                    android.R.color.system_accent3_50, android.R.color.system_accent3_900,
                )
                else -> intArrayOf(
                    android.R.color.system_neutral2_100, android.R.color.system_neutral2_900,
                )
            }
        }
        return colors.map { context.getColor(it) }.toIntArray()
    }
}
