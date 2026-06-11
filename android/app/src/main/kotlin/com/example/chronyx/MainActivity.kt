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

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "chronyx/ringtones"
    private val WIDGET_CHANNEL = "com.example.chronyx/widget"
    private val PICK_RINGTONE_REQUEST = 1001

    private var pendingResult: Result? = null
    private var pendingTaskIdToToggle: String? = null
    private var pendingLaunchWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID
    private var pendingLaunchWidgetType: String? = null

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
                    val intent = Intent(this@MainActivity, ChronyxWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    }
                    this@MainActivity.sendBroadcast(intent)
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
                        "widgetType" to pendingLaunchWidgetType
                    )
                    pendingTaskIdToToggle = null
                    pendingLaunchWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
                    pendingLaunchWidgetType = null
                    result.success(data)
                }
                "getActiveWidgetIds" -> {
                    val manager = AppWidgetManager.getInstance(this@MainActivity)
                    val componentName = ComponentName(this@MainActivity, ChronyxWidgetProvider::class.java)
                    val ids = manager.getAppWidgetIds(componentName)
                    result.success(ids.toList())
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
