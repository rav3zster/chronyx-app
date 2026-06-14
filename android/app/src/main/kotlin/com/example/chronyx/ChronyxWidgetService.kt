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
        val priority: String,
        val dueDate: String?
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

        // Priority Dots styling (High/Critical: Red, Medium: Yellow, Low: Hidden)
        when (task.priority) {
            "high", "critical" -> {
                views.setViewVisibility(R.id.task_priority_dot, View.VISIBLE)
                views.setInt(R.id.task_priority_dot, "setColorFilter", Color.parseColor("#FF5370")) // red
            }
            "medium" -> {
                views.setViewVisibility(R.id.task_priority_dot, View.VISIBLE)
                views.setInt(R.id.task_priority_dot, "setColorFilter", Color.parseColor("#F59E0B")) // warning orange/yellow
            }
            else -> {
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

        // Formatted due date label
        var formattedDueDate: String? = null
        var isOverdue = false
        if (task.dueDate != null) {
            try {
                val dateStr = if (task.dueDate.length >= 10) task.dueDate.substring(0, 10) else task.dueDate
                val parts = dateStr.split("-")
                if (parts.size == 3) {
                    val year = parts[0].toInt()
                    val month = parts[1].toInt()
                    val day = parts[2].toInt()

                    val calendar = java.util.Calendar.getInstance()
                    val todayYear = calendar.get(java.util.Calendar.YEAR)
                    val todayMonth = calendar.get(java.util.Calendar.MONTH) + 1
                    val todayDay = calendar.get(java.util.Calendar.DAY_OF_MONTH)

                    val targetCal = java.util.Calendar.getInstance().apply {
                        set(year, month - 1, day, 0, 0, 0)
                        set(java.util.Calendar.MILLISECOND, 0)
                    }
                    val todayCal = java.util.Calendar.getInstance().apply {
                        set(todayYear, todayMonth - 1, todayDay, 0, 0, 0)
                        set(java.util.Calendar.MILLISECOND, 0)
                    }

                    val diffDays = ((targetCal.timeInMillis - todayCal.timeInMillis) / (24 * 60 * 60 * 1000)).toInt()

                    formattedDueDate = when (diffDays) {
                        0 -> "Today"
                        1 -> "Tomorrow"
                        -1 -> "Yesterday"
                        else -> {
                            if (diffDays < -1) {
                                isOverdue = true
                                "Overdue"
                            } else {
                                val months = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
                                if (month in 1..12) "${months[month - 1]} $day" else dateStr
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        if (formattedDueDate != null) {
            views.setTextViewText(R.id.task_due_date, formattedDueDate)
            views.setViewVisibility(R.id.task_due_date, View.VISIBLE)
            if (isOverdue && !isCompleted) {
                views.setTextColor(R.id.task_due_date, Color.parseColor("#FF5370")) // red for overdue
            } else {
                views.setTextColor(R.id.task_due_date, Color.parseColor("#8B96B8")) // standard gray
            }
        } else {
            views.setViewVisibility(R.id.task_due_date, View.GONE)
        }

        // Show/hide sub-item metadata row container
        val hasDuration = task.estimatedMinutes != null && task.estimatedMinutes > 0
        val hasDueDate = formattedDueDate != null
        if (hasDuration || hasDueDate) {
            views.setViewVisibility(R.id.task_meta_container, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.task_meta_container, View.GONE)
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
                        val dueDate = if (obj.has("dueDate") && !obj.isNull("dueDate")) {
                            obj.optString("dueDate")
                        } else {
                            null
                        }
                        tasksList.add(TaskItem(id, title, estMin, status, priority, dueDate))
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
