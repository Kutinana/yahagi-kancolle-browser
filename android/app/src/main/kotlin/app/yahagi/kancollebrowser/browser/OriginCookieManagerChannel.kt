package app.yahagi.kancollebrowser.browser

import android.webkit.CookieManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.URI

internal interface OriginCookieStore {
    fun getCookieHeader(origin: String): String?

    fun setExpiredCookie(origin: String, cookie: String)

    fun flush()
}

private class AndroidOriginCookieStore : OriginCookieStore {
    private val cookieManager = CookieManager.getInstance()

    override fun getCookieHeader(origin: String): String? = cookieManager.getCookie(origin)

    override fun setExpiredCookie(origin: String, cookie: String) {
        cookieManager.setCookie(origin, cookie)
    }

    override fun flush() {
        cookieManager.flush()
    }
}

internal class OriginCookieManagerChannel(
    private val store: OriginCookieStore = AndroidOriginCookieStore(),
) : MethodChannel.MethodCallHandler {
    companion object {
        const val METHOD_CHANNEL_NAME = "app.yahagi.kancollebrowser/origin_cookies"
        private const val CLEAR_METHOD = "clearCookiesForOrigin"
        private const val OOI_ORIGIN = "https://ooi.moe"
        private val COOKIE_NAME_PATTERN = Regex("^[A-Za-z0-9._-]{1,128}$")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != CLEAR_METHOD) {
            result.notImplemented()
            return
        }

        val arguments = call.arguments as? Map<*, *>
        if (
            arguments == null ||
            arguments.size != 1 ||
            arguments.keys.singleOrNull() != "origin" ||
            arguments["origin"] !is String
        ) {
            result.error("invalid_argument", "Expected one origin argument.", null)
            return
        }

        val origin = arguments["origin"] as String
        if (!isExactOoiOrigin(origin)) {
            result.error("invalid_origin", "Only the OOI origin may be cleared.", null)
            return
        }

        try {
            val cookieNames = store.getCookieHeader(OOI_ORIGIN)
                .orEmpty()
                .split(';')
                .mapNotNull(::parseCookieName)
                .distinct()

            for (name in cookieNames) {
                store.setExpiredCookie(OOI_ORIGIN, expiredCookie(name))
                store.setExpiredCookie(OOI_ORIGIN, expiredCookie(name, domain = "ooi.moe"))
            }
            store.flush()
            result.success(null)
        } catch (_: RuntimeException) {
            result.error("cookie_clear_failed", "Unable to clear the OOI login session.", null)
        }
    }

    private fun isExactOoiOrigin(value: String): Boolean = try {
        val uri = URI(value)
        uri.scheme == "https" &&
            uri.host == "ooi.moe" &&
            (uri.port == -1 || uri.port == 443) &&
            uri.rawUserInfo == null &&
            uri.rawPath.isNullOrEmpty() &&
            uri.rawQuery == null &&
            uri.rawFragment == null &&
            value == OOI_ORIGIN
    } catch (_: Exception) {
        false
    }

    private fun parseCookieName(part: String): String? {
        val separator = part.indexOf('=')
        if (separator <= 0) return null
        val name = part.substring(0, separator).trim()
        return name.takeIf(COOKIE_NAME_PATTERN::matches)
    }

    private fun expiredCookie(name: String, domain: String? = null): String = buildString {
        append(name)
        append("=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT")
        if (domain != null) append("; Domain=").append(domain)
        append("; Secure; HttpOnly; SameSite=Lax")
    }
}
