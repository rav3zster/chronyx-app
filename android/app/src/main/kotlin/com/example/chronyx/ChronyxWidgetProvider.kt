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

class ChronyxWidgetProvider : AppWidgetProvider() {

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
            val componentName = ComponentName(context, ChronyxWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        } else if (action == "com.example.chronyx.ACTION_TOGGLE_TASK_BACKGROUND") {
            val taskId = intent.getStringExtra("task_id")
            val appWidgetId = intent.getIntExtra("widget_id", AppWidgetManager.INVALID_APPWIDGET_ID)
            
            if (taskId != null && appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                Log.d("ChronyxWidgetProvider", "Toggling task $taskId for widget $appWidgetId in background")
                
                // 1. Optimistic UI update: Modify SharedPreferences state instantly
                val nextStatus = toggleTaskInSharedPreferences(context, appWidgetId, taskId)
                
                // 2. Trigger instant widget UI reload
                val appWidgetManager = AppWidgetManager.getInstance(context)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
                updateAppWidget(context, appWidgetManager, appWidgetId)
                
                // 3. Sync to Supabase in a background thread
                if (nextStatus != null) {
                    SupabaseNetworkClient.toggleTaskStatus(context, taskId, nextStatus)
                    
                    // 4. If MainActivity is active, notify Flutter via MethodChannel
                    MainActivity.notifyTaskToggled(taskId)
                }
            }
        }
    }

    private fun toggleTaskInSharedPreferences(context: Context, appWidgetId: Int, taskId: String): String? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val stateKey = "flutter.widget_state_$appWidgetId"
        val stateJson = prefs.getString(stateKey, null) ?: return null

        try {
            val stateObj = JSONObject(stateJson)
            val tasksArray = stateObj.optJSONArray("tasks") ?: return null
            var nextStatus: String? = null
            var completedCount = 0

            for (i in 0 until tasksArray.length()) {
                val task = tasksArray.getJSONObject(i)
                if (task.optString("id") == taskId) {
                    val currentStatus = task.optString("status")
                    nextStatus = if (currentStatus == "completed") "pending" else "completed"
                    task.put("status", nextStatus)
                }
                if (task.optString("status") == "completed") {
                    completedCount++
                }
            }

            if (nextStatus != null) {
                stateObj.put("completedCount", completedCount)
                val totalCount = tasksArray.length()
                val pct = if (totalCount == 0) 0 else ((completedCount.toDouble() / totalCount.toDouble()) * 100).toInt()
                stateObj.put("progressPercentage", pct)

                // Save back to preferences
                prefs.edit().putString(stateKey, stateObj.toString()).commit()
                return nextStatus
            }
        } catch (e: Exception) {
            Log.e("ChronyxWidgetProvider", "Error toggling task in local cache", e)
        }
        return null
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
            val isMedium = minHeight in 110..219
            val isLarge = minHeight >= 220

            // Read Config and State for this widget ID
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val stateKey = "flutter.widget_state_$appWidgetId"
            val stateJson = prefs.getString(stateKey, null)

            var widgetTitle = "Chronyx Tasks"
            var widgetSubtitle = "No tasks"
            var pctProgress = 0
            var completedCount = 0
            var totalCount = 0
            var widgetType = "today"

            if (stateJson != null) {
                try {
                    val stateObj = JSONObject(stateJson)
                    widgetTitle = stateObj.optString("title", "Chronyx Tasks")
                    completedCount = stateObj.optInt("completedCount", 0)
                    totalCount = stateObj.optInt("totalCount", 0)
                    pctProgress = stateObj.optInt("progressPercentage", 0)
                    widgetType = stateObj.optString("widgetType", "today")
                    widgetSubtitle = "$completedCount/$totalCount completed"
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            views.setTextViewText(R.id.widget_title, widgetTitle)
            views.setTextViewText(R.id.widget_subtitle, widgetSubtitle)

            // Dynamic layout adjustments based on size
            if (isSmall) {
                // Hide progress bar in small widgets to save vertical space
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
            val intent = Intent(context, ChronyxWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, intent)

            // Setup PendingIntent template for ListView clicks (com.example.chronyx.ACTION_TOGGLE_TASK_BACKGROUND)
            val clickIntent = Intent(context, ChronyxWidgetProvider::class.java).apply {
                action = "com.example.chronyx.ACTION_TOGGLE_TASK_BACKGROUND"
            }
            val clickPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list, clickPendingIntent)

            // Setup PendingIntent for Header: Tapping open launches MainActivity to a specific route or general main
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

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
