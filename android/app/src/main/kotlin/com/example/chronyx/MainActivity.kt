package com.example.chronyx

import android.content.ComponentName
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject

import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.util.Log

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "chronyx/ringtones"
    private val WIDGET_CHANNEL = "com.example.chronyx/widget"
    private val PICK_RINGTONE_REQUEST = 1001

    private var pendingResult: Result? = null
    private var pendingTaskIdToToggle: String? = null
    private var pendingLaunchWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID
    private var pendingLaunchWidgetType: String? = null
    private var pendingLaunchWidgetAction: String? = null
    private var pendingLaunchFocusAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        activeInstance = this
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        if (activeInstance == this) {
            activeInstance = null
        }
        super.onDestroy()
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        Log.d("MainActivity", "handleIntent action: $action")
        
        if (action == "com.example.chronyx.ACTION_TOGGLE_TASK") {
            val taskId = intent.getStringExtra("task_id")
            if (taskId != null) {
                pendingTaskIdToToggle = taskId
                flutterEngine?.let { engine ->
                    MethodChannel(engine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
                        .invokeMethod("toggleTask", taskId)
                }
            }
        } else if (action == "com.example.chronyx.ACTION_OPEN_APP") {
            pendingLaunchWidgetId = intent.getIntExtra("widget_id", AppWidgetManager.INVALID_APPWIDGET_ID)
            pendingLaunchWidgetType = intent.getStringExtra("widget_type")
            
            flutterEngine?.let { engine ->
                val data = mapOf(
                    "widgetId" to if (pendingLaunchWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) null else pendingLaunchWidgetId,
                    "widgetType" to pendingLaunchWidgetType
                )
                MethodChannel(engine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
                    .invokeMethod("widgetLaunch", data)
            }
        } else if (action == "com.example.chronyx.ACTION_QUICK_ADD") {
            pendingLaunchWidgetAction = "quick_add"
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
                    .invokeMethod("quickAdd", null)
            }
        } else if (action == "com.example.chronyx.ACTION_FOCUS_CONTROL") {
            val focusAction = intent.getStringExtra("focus_action")
            if (focusAction != null) {
                pendingLaunchFocusAction = focusAction
                flutterEngine?.let { engine ->
                    MethodChannel(engine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
                        .invokeMethod("focusControl", focusAction)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRingtones" -> {
                    val ringtones = getRingtones()
                    result.success(ringtones)
                }
                "getNotificationTones" -> {
                    val tones = getNotificationTones()
                    result.success(tones)
                }
                "getAlarmSounds" -> {
                    val sounds = getAlarmSounds()
                    result.success(sounds)
                }
                "pickRingtone" -> {
                    pendingResult = result
                    pickRingtone()
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
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
                        val intent = Intent(this@MainActivity, provider).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        }
                        this@MainActivity.sendBroadcast(intent)
                    }
                    result.success(true)
                }
                "getLaunchIntent" -> {
                    val taskId = pendingTaskIdToToggle
                    pendingTaskIdToToggle = null
                    result.success(taskId)
                }
                "getLaunchData" -> {
                    val data = mapOf(
                        "taskId" to pendingTaskIdToToggle,
                        "widgetId" to if (pendingLaunchWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) null else pendingLaunchWidgetId,
                        "widgetType" to pendingLaunchWidgetType,
                        "action" to pendingLaunchWidgetAction,
                        "focusAction" to pendingLaunchFocusAction
                    )
                    pendingTaskIdToToggle = null
                    pendingLaunchWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
                    pendingLaunchWidgetType = null
                    pendingLaunchWidgetAction = null
                    pendingLaunchFocusAction = null
                    result.success(data)
                }
                "getActiveWidgetIds" -> {
                    val manager = AppWidgetManager.getInstance(this@MainActivity)
                    val resultList = mutableListOf<Map<String, Any>>()
                    
                    val todayIds = manager.getAppWidgetIds(ComponentName(this@MainActivity, ChronyxWidgetProvider::class.java))
                    for (id in todayIds) {
                        resultList.add(mapOf("id" to id, "type" to "today"))
                    }
                    
                    val importantIds = manager.getAppWidgetIds(ComponentName(this@MainActivity, ChronyxImportantWidgetProvider::class.java))
                    for (id in importantIds) {
                        resultList.add(mapOf("id" to id, "type" to "todo_important"))
                    }

                    val todosIds = manager.getAppWidgetIds(ComponentName(this@MainActivity, ChronyxTodosWidgetProvider::class.java))
                    for (id in todosIds) {
                        resultList.add(mapOf("id" to id, "type" to "todo"))
                    }

                    val todoTodayIds = manager.getAppWidgetIds(ComponentName(this@MainActivity, ChronyxTodoTodayWidgetProvider::class.java))
                    for (id in todoTodayIds) {
                        resultList.add(mapOf("id" to id, "type" to "todo_today"))
                    }

                    val projectIds = manager.getAppWidgetIds(ComponentName(this@MainActivity, ChronyxProjectWidgetProvider::class.java))
                    for (id in projectIds) {
                        resultList.add(mapOf("id" to id, "type" to "project"))
                    }

                    val statsIds = manager.getAppWidgetIds(ComponentName(this@MainActivity, ChronyxStatsWidgetProvider::class.java))
                    for (id in statsIds) {
                        resultList.add(mapOf("id" to id, "type" to "stats"))
                    }

                    val focusIds = manager.getAppWidgetIds(ComponentName(this@MainActivity, ChronyxFocusWidgetProvider::class.java))
                    for (id in focusIds) {
                        resultList.add(mapOf("id" to id, "type" to "focus"))
                    }

                    result.success(resultList)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private var activeInstance: MainActivity? = null

        fun notifyTaskToggled(taskId: String) {
            activeInstance?.let { activity ->
                activity.runOnUiThread {
                    activity.flutterEngine?.let { engine ->
                        MethodChannel(engine.dartExecutor.binaryMessenger, activity.WIDGET_CHANNEL)
                            .invokeMethod("toggleTask", taskId)
                    }
                }
            }
        }
    }

    private fun getRingtones(): List<Map<String, Any>> {
        val manager = RingtoneManager(this)
        manager.setType(RingtoneManager.TYPE_RINGTONE)
        val result = mutableListOf<Map<String, Any>>()
        val cursor = manager.cursor
        while (cursor.moveToNext()) {
            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = cursor.getString(RingtoneManager.URI_COLUMN_INDEX) + "/" +
                    cursor.getString(RingtoneManager.ID_COLUMN_INDEX)
            val item = mapOf(
                "title" to title,
                "uri" to uri,
                "isAlarm" to false
            )
            result.add(item)
        }
        cursor.close()
        return result
    }

    private fun getNotificationTones(): List<Map<String, Any>> {
        val manager = RingtoneManager(this)
        manager.setType(RingtoneManager.TYPE_NOTIFICATION)
        val result = mutableListOf<Map<String, Any>>()
        val cursor = manager.cursor
        while (cursor.moveToNext()) {
            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = cursor.getString(RingtoneManager.URI_COLUMN_INDEX) + "/" +
                    cursor.getString(RingtoneManager.ID_COLUMN_INDEX)
            val item = mapOf(
                "title" to title,
                "uri" to uri
            )
            result.add(item)
        }
        cursor.close()
        return result
    }

    private fun getAlarmSounds(): List<Map<String, Any>> {
        val manager = RingtoneManager(this)
        manager.setType(RingtoneManager.TYPE_ALARM)
        val result = mutableListOf<Map<String, Any>>()
        val cursor = manager.cursor
        while (cursor.moveToNext()) {
            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = cursor.getString(RingtoneManager.URI_COLUMN_INDEX) + "/" +
                    cursor.getString(RingtoneManager.ID_COLUMN_INDEX)
            val item = mapOf(
                "title" to title,
                "uri" to uri,
                "isAlarm" to true
            )
            result.add(item)
        }
        cursor.close()
        return result
    }

    private fun pickRingtone() {
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Notification Sound")
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        intent.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Settings.System.DEFAULT_NOTIFICATION_URI)
        startActivityForResult(intent, PICK_RINGTONE_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_RINGTONE_REQUEST && resultCode == RESULT_OK) {
            val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            pendingResult?.success(uri?.toString() ?: "")
        } else if (requestCode == PICK_RINGTONE_REQUEST) {
            pendingResult?.success("")
        }
    }
}
