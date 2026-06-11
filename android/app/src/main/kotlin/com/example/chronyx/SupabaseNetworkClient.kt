package com.example.chronyx

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

object SupabaseNetworkClient {
    private const val TAG = "SupabaseNetworkClient"

    fun toggleTaskStatus(context: Context, taskId: String, newStatus: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val supabaseUrl = prefs.getString("flutter.widget_supabase_url", null)
        val anonKey = prefs.getString("flutter.widget_supabase_anon_key", null)
        val accessToken = prefs.getString("flutter.widget_access_token", null)

        if (supabaseUrl.isNullOrEmpty() || anonKey.isNullOrEmpty() || accessToken.isNullOrEmpty()) {
            Log.w(TAG, "Cannot sync task $taskId: Supabase credentials or session token missing in preferences")
            return
        }

        thread {
            try {
                // Determine completed_at ISO timestamp
                val completedAt = if (newStatus == "completed") {
                    val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
                    sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
                    sdf.format(java.util.Date())
                } else {
                    null
                }

                val url = URL("$supabaseUrl/rest/v1/project_tasks?id=eq.$taskId")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST" // POST with PATCH override
                conn.setRequestProperty("X-HTTP-Method-Override", "PATCH")
                conn.setRequestProperty("apikey", anonKey)
                conn.setRequestProperty("Authorization", "Bearer $accessToken")
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true

                val payload = JSONObject().apply {
                    put("status", newStatus)
                    put("completed_at", completedAt)
                }

                OutputStreamWriter(conn.outputStream).use { writer ->
                    writer.write(payload.toString())
                    writer.flush()
                }

                val responseCode = conn.responseCode
                Log.d(TAG, "Supabase sync task $taskId status $newStatus returned: $responseCode")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Error syncing task state to Supabase in background", e)
            }
        }
    }
}
