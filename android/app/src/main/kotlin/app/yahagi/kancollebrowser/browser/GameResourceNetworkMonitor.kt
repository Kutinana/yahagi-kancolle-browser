package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities

class GameResourceNetworkMonitor(context: Context) {
    private val connectivity =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var callback: ConnectivityManager.NetworkCallback? = null

    fun state(): GameResourceNetworkState {
        val network = connectivity.activeNetwork
            ?: return GameResourceNetworkState(connected = false, metered = false)
        val capabilities = connectivity.getNetworkCapabilities(network)
        val connected = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        return GameResourceNetworkState(
            connected = connected,
            metered = connectivity.isActiveNetworkMetered,
        )
    }

    fun start(onChanged: () -> Unit) {
        if (callback != null) return
        val listener = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = onChanged()
            override fun onLost(network: Network) = onChanged()
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) =
                onChanged()
        }
        callback = listener
        connectivity.registerDefaultNetworkCallback(listener)
    }

    fun dispose() {
        val listener = callback ?: return
        callback = null
        runCatching { connectivity.unregisterNetworkCallback(listener) }
    }
}
