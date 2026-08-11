package com.shareittoo.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        promoteSafePushActionLink(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        promoteSafePushActionLink(intent)
        super.onNewIntent(intent)
    }

    private fun promoteSafePushActionLink(intent: Intent?) {
        if (intent == null || intent.data != null) return
        val raw = intent.getStringExtra("actionUrl")?.trim().orEmpty()
        if (raw.isEmpty()) return
        val uri = Uri.parse(raw)
        if (isSafePushActionLink(uri)) intent.data = uri
    }

    private fun isSafePushActionLink(uri: Uri): Boolean {
        if (uri.userInfo != null) return false
        val scheme = uri.scheme?.lowercase() ?: return false
        val route: String
        val id: String
        when (scheme) {
            "https" -> {
                if (uri.port != -1 && uri.port != 443) return false
                if (uri.host?.lowercase() !in allowedWebHosts) return false
                val segments = uri.pathSegments.filter { it.isNotBlank() }
                val routeIndex = when {
                    segments.size >= 5 &&
                        segments[0].equals("api", ignoreCase = true) &&
                        segments[1].equals("v1", ignoreCase = true) &&
                        segments[2].equals("open", ignoreCase = true) -> 3
                    segments.size >= 3 &&
                        segments[0].equals("open", ignoreCase = true) -> 1
                    else -> return false
                }
                route = segments[routeIndex].lowercase()
                id = segments.getOrNull(routeIndex + 1).orEmpty()
            }
            "shareittoo" -> {
                route = uri.host?.lowercase().orEmpty()
                id = uri.pathSegments.firstOrNull { it.isNotBlank() }.orEmpty()
            }
            else -> return false
        }
        return route in allowedPushRoutes && safeIdentifier.matches(id)
    }

    companion object {
        private val allowedWebHosts = setOf(
            "shareittoo.com",
            "www.shareittoo.com",
            "staging.shareittoo.com",
        )
        private val allowedPushRoutes = setOf("booking", "chat", "payment")
        private val safeIdentifier = Regex("^[A-Za-z0-9_.:-]{1,120}$")
    }
}
