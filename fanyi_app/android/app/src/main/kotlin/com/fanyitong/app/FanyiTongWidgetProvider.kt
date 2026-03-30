package com.fanyitong.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class FanyiTongWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, FanyiTongWidgetProvider::class.java)
        val ids = manager.getAppWidgetIds(component)
        ids.forEach { updateAppWidget(context, manager, it) }
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, FanyiTongWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            ids.forEach { updateAppWidget(context, manager, it) }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.fanyi_tong_widget)

            views.setOnClickPendingIntent(
                R.id.widgetPasteButton,
                launchPendingIntent(context, AppLaunchActions.PASTE_TRANSLATE),
            )
            views.setOnClickPendingIntent(
                R.id.widgetVoiceButton,
                launchPendingIntent(context, AppLaunchActions.VOICE_TRANSLATE),
            )
            views.setOnClickPendingIntent(
                R.id.widgetKeyboardButton,
                launchPendingIntent(context, AppLaunchActions.OPEN_KEYBOARD),
            )
            views.setOnClickPendingIntent(
                R.id.widgetOpenAppButton,
                launchPendingIntent(context, AppLaunchActions.OPEN_TRANSLATE),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun launchPendingIntent(context: Context, action: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra(MainActivity.EXTRA_LAUNCH_ACTION, action)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            return PendingIntent.getActivity(
                context,
                action.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
