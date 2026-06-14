package com.example.chronyx

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

open class ChronyxWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        Log.d("ChronyxWidgetProvider", "onReceive action: $action")

        if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val providers = listOf(
                ChronyxWidgetProvider::class.java,
                ChronyxImportantWidgetProvider::class.java,
                ChronyxProjectWidgetProvider::class.java,
                ChronyxStatsWidgetProvider::class.java,
                ChronyxFocusWidgetProvider::class.java,
                ChronyxTodosWidgetProvider::class.java,
                ChronyxTodoTodayWidgetProvider::class.java
            )
            for (provider in providers) {
                val componentName = ComponentName(context, provider)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
                for (appWidgetId in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.chronyx_widget)

            // Read options to determine size configuration
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
            
            // Sizing threshold:
            // Small: height < 110dp or width < 180dp
            // Medium: height < 220dp
            // Large: height >= 220dp
            val isSmall = minHeight < 110 || minWidth < 180

            // Read Config and State for this widget ID
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val stateKey = "flutter.widget_state_$appWidgetId"
            val stateJson = prefs.getString(stateKey, null)

            // Resolve widget type based on provider class name
            val component = appWidgetManager.getAppWidgetInfo(appWidgetId)?.provider
            val className = component?.className ?: ""
            
            var widgetType = "today"
            if (className.contains("ChronyxImportantWidgetProvider")) {
                widgetType = "todo_important"
            } else if (className.contains("ChronyxTodosWidgetProvider")) {
                widgetType = "todo"
            } else if (className.contains("ChronyxTodoTodayWidgetProvider")) {
                widgetType = "todo_today"
            } else if (className.contains("ChronyxProjectWidgetProvider")) {
                widgetType = "project"
            } else if (className.contains("ChronyxStatsWidgetProvider")) {
                widgetType = "stats"
            } else if (className.contains("ChronyxFocusWidgetProvider")) {
                widgetType = "focus"
            } else {
                if (stateJson != null) {
                    try {
                        val stateObj = JSONObject(stateJson)
                        widgetType = stateObj.optString("widgetType", "today")
                    } catch (e: Exception) {}
                }
            }

            var widgetTitle = "Chronyx Today"
            var widgetSubtitle = "No tasks"
            var pctProgress = 0
            var completedCount = 0
            var totalCount = 0

            // Parse state values
            if (stateJson != null) {
                try {
                    val stateObj = JSONObject(stateJson)
                    widgetTitle = stateObj.optString("title", "Chronyx Tasks")
                    completedCount = stateObj.optInt("completedCount", 0)
                    totalCount = stateObj.optInt("totalCount", 0)
                    pctProgress = stateObj.optInt("progressPercentage", 0)
                    widgetSubtitle = "$completedCount/$totalCount completed"
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            // Fallback default titles for known types
            if (stateJson == null || widgetTitle.isEmpty()) {
                widgetTitle = when (widgetType) {
                    "todo_important" -> "Important Tasks"
                    "todo" -> "All To-Dos"
                    "todo_today" -> "Today's To-Dos"
                    "project" -> "Project Roadmap"
                    "stats" -> "My Analytics"
                    "focus" -> "Focus Session"
                    else -> "Chronyx Today"
                }
            }

            views.setTextViewText(R.id.widget_title, widgetTitle)
            views.setTextViewText(R.id.widget_subtitle, widgetSubtitle)

            // Setup Header click (launches MainActivity)
            val headerIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.chronyx.ACTION_OPEN_APP"
                putExtra("widget_id", appWidgetId)
                putExtra("widget_type", widgetType)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val headerPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 1000,
                headerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, headerPendingIntent)

            // Setup manual sync/refresh button
            val syncIntent = Intent(context, ChronyxWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val syncPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId + 2000,
                syncIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_button, syncPendingIntent)

            // Setup Quick Add floating button click
            val addIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.chronyx.ACTION_QUICK_ADD"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val addPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 3000,
                addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, addPendingIntent)

            // Handle UI branching based on layout category (List, Stats, or Focus)
            if (widgetType == "stats") {
                // Hide List layout and Focus layouts
                views.setViewVisibility(R.id.widget_list, View.GONE)
                views.setViewVisibility(R.id.widget_empty_view, View.GONE)
                views.setViewVisibility(R.id.widget_progress_bar, View.GONE)
                views.setViewVisibility(R.id.widget_divider, View.GONE)
                views.setViewVisibility(R.id.widget_focus_layout, View.GONE)

                // Show Stats layout
                views.setViewVisibility(R.id.widget_stats_layout, View.VISIBLE)

                // Parse and populate statistics
                var deepWorkHrs = 0.0
                var weeklyStreak = 0
                var tasksCompleted = 0
                if (stateJson != null) {
                    try {
                        val stateObj = JSONObject(stateJson)
                        deepWorkHrs = stateObj.optDouble("deepWorkHours", 0.0)
                        weeklyStreak = stateObj.optInt("weeklyStreak", 0)
                        tasksCompleted = stateObj.optInt("tasksCompleted", 0)
                    } catch (e: Exception) {}
                }

                views.setTextViewText(R.id.widget_subtitle, "Weekly productivity")
                views.setTextViewText(R.id.widget_stat_deep_work_val, String.format("%.1f", deepWorkHrs))
                views.setTextViewText(R.id.widget_stat_streak_val, weeklyStreak.toString())
                views.setTextViewText(R.id.widget_stat_completed_val, tasksCompleted.toString())

            } else if (widgetType == "focus") {
                // Hide List layout and Stats layouts
                views.setViewVisibility(R.id.widget_list, View.GONE)
                views.setViewVisibility(R.id.widget_empty_view, View.GONE)
                views.setViewVisibility(R.id.widget_progress_bar, View.GONE)
                views.setViewVisibility(R.id.widget_divider, View.GONE)
                views.setViewVisibility(R.id.widget_stats_layout, View.GONE)

                // Show Focus layout
                views.setViewVisibility(R.id.widget_focus_layout, View.VISIBLE)

                var focusTask = "No Active Session"
                var status = "idle"
                var displayTime = "--:--"

                if (stateJson != null) {
                    try {
                        val stateObj = JSONObject(stateJson)
                        status = stateObj.optString("status", "idle")
                        focusTask = stateObj.optString("taskName", "Focus Session")
                        val elapsed = stateObj.optInt("elapsedSeconds", 0)
                        val remaining = stateObj.optInt("remainingSeconds", 0)
                        val sessionMode = stateObj.optString("sessionMode", "stopwatch")

                        val activeTimeSec = if (sessionMode == "stopwatch") elapsed else remaining
                        val mins = activeTimeSec / 60
                        val secs = activeTimeSec % 60
                        displayTime = String.format("%02d:%02d", mins, secs)
                    } catch (e: Exception) {}
                }

                views.setTextViewText(R.id.widget_subtitle, "Active Timer")
                views.setTextViewText(R.id.widget_focus_task_title, focusTask)
                views.setTextViewText(R.id.widget_focus_timer, displayTime)

                if (status == "idle") {
                    views.setViewVisibility(R.id.widget_focus_pause_btn, View.GONE)
                    views.setViewVisibility(R.id.widget_focus_resume_btn, View.GONE)
                    views.setViewVisibility(R.id.widget_focus_stop_btn, View.GONE)
                } else {
                    val isPaused = status == "paused"
                    if (isPaused) {
                        views.setViewVisibility(R.id.widget_focus_pause_btn, View.GONE)
                        views.setViewVisibility(R.id.widget_focus_resume_btn, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.widget_focus_pause_btn, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_focus_resume_btn, View.GONE)
                    }
                    views.setViewVisibility(R.id.widget_focus_stop_btn, View.VISIBLE)

                    // Bind control clicks to MainActivity triggers
                    val pauseIntent = Intent(context, MainActivity::class.java).apply {
                        action = "com.example.chronyx.ACTION_FOCUS_CONTROL"
                        putExtra("focus_action", "pause")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val pausePendingIntent = PendingIntent.getActivity(
                        context,
                        appWidgetId + 4000,
                        pauseIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_focus_pause_btn, pausePendingIntent)

                    val resumeIntent = Intent(context, MainActivity::class.java).apply {
                        action = "com.example.chronyx.ACTION_FOCUS_CONTROL"
                        putExtra("focus_action", "resume")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val resumePendingIntent = PendingIntent.getActivity(
                        context,
                        appWidgetId + 5000,
                        resumeIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_focus_resume_btn, resumePendingIntent)

                    val stopIntent = Intent(context, MainActivity::class.java).apply {
                        action = "com.example.chronyx.ACTION_FOCUS_CONTROL"
                        putExtra("focus_action", "stop")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val stopPendingIntent = PendingIntent.getActivity(
                        context,
                        appWidgetId + 6000,
                        stopIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_focus_stop_btn, stopPendingIntent)
                }

            } else {
                // List layouts: today, important, project, etc.
                views.setViewVisibility(R.id.widget_stats_layout, View.GONE)
                views.setViewVisibility(R.id.widget_focus_layout, View.GONE)

                // Dynamic progress visibility based on widget size
                if (isSmall) {
                    views.setViewVisibility(R.id.widget_progress_bar, View.GONE)
                    views.setViewVisibility(R.id.widget_divider, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_progress_bar, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_divider, View.VISIBLE)
                    views.setProgressBar(R.id.widget_progress_bar, 100, pctProgress, false)
                }

                if (totalCount == 0) {
                    views.setViewVisibility(R.id.widget_empty_view, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_list, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_empty_view, View.GONE)
                    views.setViewVisibility(R.id.widget_list, View.VISIBLE)
                }

                // Set up RemoteViews ListView Service Intent
                val listIntent = Intent(context, ChronyxWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.widget_list, listIntent)

                // Setup PendingIntent template for ListView item toggling
                val clickIntent = Intent(context, MainActivity::class.java).apply {
                    action = "com.example.chronyx.ACTION_TOGGLE_TASK"
                }
                val clickPendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    clickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_list, clickPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
