package com.shareittoo.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPushActionLink: String? = null
    private lateinit var pushActionLinkChannel: MethodChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingPushActionLink = safePushActionLink(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val actionLink = safePushActionLink(intent)
        if (actionLink != null) {
            // Keep the link until Dart explicitly consumes it. Android can deliver
            // the notification intent before the Flutter isolate is fully resumed,
            // so the immediate channel event is an optimization, not the only path.
            pendingPushActionLink = actionLink
            deliverPushActionLink(actionLink)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pushActionLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pushActionLinkChannelName,
        )
        pushActionLinkChannel.setMethodCallHandler { call, result ->
            if (call.method != "takeInitialActionLink") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val pending = pendingPushActionLink
            pendingPushActionLink = null
            result.success(pending)
        }
    }

    private fun deliverPushActionLink(actionLink: String) {
        if (::pushActionLinkChannel.isInitialized) {
            pushActionLinkChannel.invokeMethod("pushActionLink", actionLink)
        } else {
            pendingPushActionLink = actionLink
        }
    }

    private fun safePushActionLink(intent: Intent?): String? {
        if (intent == null) return null
        val raw = intent.getStringExtra("actionUrl")?.trim().orEmpty()
        if (raw.isEmpty()) return null
        val uri = Uri.parse(raw)
        return if (isSafePushActionLink(uri)) uri.toString() else null
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
        private const val pushActionLinkChannelName =
            "com.shareittoo.app/push_action_links"
        private val allowedWebHosts = setOf(
            "shareittoo.com",
            "www.shareittoo.com",
            "staging.shareittoo.com",
        )
        private val allowedPushRoutes = setOf("booking", "chat", "payment")
        private val safeIdentifier = Regex("^[A-Za-z0-9_.:-]{1,120}$")
    }
}
