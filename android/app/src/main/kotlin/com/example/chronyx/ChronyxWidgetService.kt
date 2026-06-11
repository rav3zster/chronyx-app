package com.example.chronyx

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.text.SpannableString
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class ChronyxWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ChronyxRemoteViewsFactory(applicationContext, intent)
    }
}

class ChronyxRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val appWidgetId = intent.getIntExtra(
        AppWidgetManager.EXTRA_APPWIDGET_ID,
        AppWidgetManager.INVALID_APPWIDGET_ID
    )
    private var tasksList = mutableListOf<TaskItem>()

    data class TaskItem(
        val id: String,
        val title: String,
        val estimatedMinutes: Int?,
        val status: String,
        val priority: String
    )

    override fun onCreate() {
        loadTasksFromPrefs()
    }

    override fun onDataSetChanged() {
        loadTasksFromPrefs()
    }

    override fun onDestroy() {
        tasksList.clear()
    }

    override fun getCount(): Int {
        return tasksList.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.chronyx_widget_item)
        if (position >= tasksList.size) return views

        val task = tasksList[position]
        val isCompleted = task.status == "completed"

        // Strikethrough for completed tasks
        if (isCompleted) {
            val spannable = SpannableString(task.title).apply {
                setSpan(StrikethroughSpan(), 0, length, 0)
            }
            views.setTextViewText(R.id.task_title, spannable)
            views.setTextColor(R.id.task_title, 0xFF8B96B8.toInt()) // textSecondaryDark
            views.setImageViewResource(R.id.task_checkbox, R.drawable.widget_checkbox_checked)
        } else {
            views.setTextViewText(R.id.task_title, task.title)
            views.setTextColor(R.id.task_title, 0xFFF1F4FF.toInt()) // textPrimaryDark
            views.setImageViewResource(R.id.task_checkbox, R.drawable.widget_checkbox_unchecked)
        }

        // Priority Dots styling (High: Red, Medium: Yellow, Low: Gray/Hidden)
        when (task.priority) {
            "high" -> {
                views.setViewVisibility(R.id.task_priority_dot, View.VISIBLE)
                views.setInt(R.id.task_priority_dot, "setColorFilter", Color.parseColor("#FF5370")) // red
            }
            "medium" -> {
                views.setViewVisibility(R.id.task_priority_dot, View.VISIBLE)
                views.setInt(R.id.task_priority_dot, "setColorFilter", Color.parseColor("#F59E0B")) // warning orange/yellow
            }
            else -> {
                // For low priority, show subtle cyan or hide it. Let's hide it for a cleaner UI, or show subtle dark border.
                views.setViewVisibility(R.id.task_priority_dot, View.GONE)
            }
        }

        // Estimated minutes label
        if (task.estimatedMinutes != null && task.estimatedMinutes > 0) {
            views.setTextViewText(R.id.task_duration, "${task.estimatedMinutes}m")
            views.setViewVisibility(R.id.task_duration, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_duration, View.GONE)
        }

        // Setup fillInIntent to pass widget_id and task_id to the pending intent template in ChronyxWidgetProvider
        val fillInIntent = Intent().apply {
            putExtra("task_id", task.id)
            putExtra("widget_id", appWidgetId)
        }
        views.setOnClickFillInIntent(R.id.task_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun loadTasksFromPrefs() {
        tasksList.clear()
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val stateKey = "flutter.widget_state_$appWidgetId"
        val stateJson = prefs.getString(stateKey, null)

        if (stateJson != null) {
            try {
                val stateObj = JSONObject(stateJson)
                val array = stateObj.optJSONArray("tasks")
                if (array != null) {
                    for (i in 0 until array.length()) {
                        val obj = array.getJSONObject(i)
                        val id = obj.optString("id")
                        val title = obj.optString("title")
                        val estMin = if (obj.has("estimatedMinutes") && !obj.isNull("estimatedMinutes")) {
                            obj.optInt("estimatedMinutes")
                        } else {
                            null
                        }
                        val status = obj.optString("status", "pending")
                        val priority = obj.optString("priority", "low")
                        tasksList.add(TaskItem(id, title, estMin, status, priority))
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
