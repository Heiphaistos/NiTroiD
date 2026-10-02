package com.heiphaistos.nitroid

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.ScanResult
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.TelephonyManager
import java.net.Inet4Address
import java.net.NetworkInterface

object NetInfo {
    fun sections(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        val cm = ctx.getSystemService(ConnectivityManager::class.java)
        val active = cm.activeNetwork
        val caps = active?.let { cm.getNetworkCapabilities(it) }
        val link = active?.let { cm.getLinkProperties(it) }
        s.section("Connexion active") {
            if (caps == null) {
                add("État", "Hors ligne")
            } else {
                add("Type", transports(caps))
                add("Internet validé", caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
                add("Facturée à l’usage", !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED))
                add("Débit descendant estimé", "${caps.linkDownstreamBandwidthKbps / 1000} Mbit/s")
                add("Débit montant estimé", "${caps.linkUpstreamBandwidthKbps / 1000} Mbit/s")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) add("Force du signal", caps.signalStrength.takeIf { it != Int.MIN_VALUE }?.let { "$it dBm" })
            }
            link?.let { l ->
                add("Interface", l.interfaceName)
                add("Adresses IP", l.linkAddresses.joinToString("\n") { it.toString() })
                add("Serveurs DNS", l.dnsServers.joinToString(", ") { it.hostAddress ?: "" })
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    add("DNS privé actif", l.isPrivateDnsActive)
                    add("Serveur DNS privé", l.privateDnsServerName)
                }
                add("Passerelle", l.routes.firstOrNull { it.isDefaultRoute }?.gateway?.hostAddress)
                add("Domaines", l.domains)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) add("MTU", l.mtu.takeIf { it > 0 })
                add("Proxy HTTP", l.httpProxy?.let { "${it.host}:${it.port}" })
            }
        }
        wifi(ctx, s)
        mobile(ctx, s)
        s.section("Interfaces réseau") {
            NetworkInterface.getNetworkInterfaces()?.toList()?.filter { it.isUp }?.forEach { ni ->
                val addrs = ni.inetAddresses.toList().joinToString(", ") { a -> (a.hostAddress ?: "").substringBefore('%') }
                add(ni.name, if (addrs.isEmpty()) "active" else addrs)
            }
        }
        return s.list
    }

    private fun transports(caps: NetworkCapabilities): String = listOfNotNull(
        "Wi-Fi".takeIf { caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) },
        "Mobile".takeIf { caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) },
        "Ethernet".takeIf { caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) },
        "Bluetooth".takeIf { caps.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) },
        "VPN".takeIf { caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) },
    ).joinToString(" + ").ifEmpty { "Autre" }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun wifi(ctx: Context, s: Sections) {
        val wm = ctx.applicationContext.getSystemService(WifiManager::class.java) ?: return
        s.section("Wi-Fi") {
            add("Activé", wm.isWifiEnabled)
            val info = wm.connectionInfo
            if (info != null && info.networkId != -1) {
                val ssid = info.ssid?.trim('"')
                add("Réseau (SSID)", if (ssid == null || ssid == WifiManager.UNKNOWN_SSID.trim('<', '>') || ssid.contains("unknown")) "masqué (autorisez la localisation)" else ssid)
                add("Point d’accès (BSSID)", info.bssid?.takeIf { it != "02:00:00:00:00:00" })
                add("Signal", "${info.rssi} dBm (${WifiManager.calculateSignalLevel(info.rssi, 5)}/4)")
                add("Fréquence", "${info.frequency} MHz (${band(info.frequency)}, canal ${channel(info.frequency)})")
                add("Vitesse de lien", "${info.linkSpeed} Mbit/s")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    add("Vitesse émission / réception", "${info.txLinkSpeedMbps} / ${info.rxLinkSpeedMbps} Mbit/s")
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) add("Norme", wifiStandard(info.wifiStandard))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add("Sécurité", securityType(info.currentSecurityType))
            }
            add("5 GHz pris en charge", wm.is5GHzBandSupported)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) add("6 GHz pris en charge", wm.is6GHzBandSupported)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) add("WPA3 pris en charge", wm.isWpa3SaeSupported)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) add("Wi-Fi 6 (802.11ax)", wm.isWifiStandardSupported(6))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) add("Wi-Fi 7 (802.11be)", wm.isWifiStandardSupported(8))
        }
    }

    @SuppressLint("MissingPermission")
    private fun mobile(ctx: Context, s: Sections) {
        if (!ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) return
        val tm = ctx.getSystemService(TelephonyManager::class.java) ?: return
        s.section("Réseau mobile") {
            add("Opérateur réseau", tm.networkOperatorName)
            add("Opérateur SIM", tm.simOperatorName)
            add("Pays", tm.networkCountryIso.uppercase())
            add("État de la SIM", when (tm.simState) {
                TelephonyManager.SIM_STATE_READY -> "Prête"
                TelephonyManager.SIM_STATE_ABSENT -> "Absente"
                TelephonyManager.SIM_STATE_PIN_REQUIRED -> "PIN requis"
                TelephonyManager.SIM_STATE_PUK_REQUIRED -> "PUK requis (bloquée)"
                TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "Verrouillée opérateur (simlock)"
                else -> "Inconnu"
            })
            add("Itinérance", tm.isNetworkRoaming)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) add("Emplacements SIM actifs", tm.activeModemCount)
            safe("Type de réseau") { networkType(tm.dataNetworkType) }
            safe("Données mobiles") { tm.isDataEnabled }
        }
    }

    private fun networkType(t: Int) = when (t) {
        TelephonyManager.NETWORK_TYPE_NR -> "5G (NR SA)"
        TelephonyManager.NETWORK_TYPE_LTE -> "4G (LTE)"
        TelephonyManager.NETWORK_TYPE_HSPAP, TelephonyManager.NETWORK_TYPE_HSPA, TelephonyManager.NETWORK_TYPE_HSDPA, TelephonyManager.NETWORK_TYPE_HSUPA -> "3G+ (HSPA)"
        TelephonyManager.NETWORK_TYPE_UMTS -> "3G (UMTS)"
        TelephonyManager.NETWORK_TYPE_EDGE -> "2G (EDGE)"
        TelephonyManager.NETWORK_TYPE_GPRS -> "2G (GPRS)"
        TelephonyManager.NETWORK_TYPE_IWLAN -> "Appels Wi-Fi (IWLAN)"
        TelephonyManager.NETWORK_TYPE_UNKNOWN -> "Inconnu"
        else -> "type $t"
    }

    fun band(freq: Int) = when {
        freq in 2400..2500 -> "2,4 GHz"
        freq in 4900..5900 -> "5 GHz"
        freq in 5925..7125 -> "6 GHz"
        freq > 50000 -> "60 GHz"
        else -> "$freq MHz"
    }

    fun channel(freq: Int) = when {
        freq == 2484 -> 14
        freq in 2412..2472 -> (freq - 2407) / 5
        freq in 5000..5900 -> (freq - 5000) / 5
        freq in 5955..7115 -> (freq - 5950) / 5
        else -> 0
    }

    private fun wifiStandard(std: Int) = when (std) {
        1 -> "802.11a/b/g (legacy)"
        4 -> "Wi-Fi 4 (802.11n)"
        5 -> "Wi-Fi 5 (802.11ac)"
        6 -> "Wi-Fi 6 (802.11ax)"
        7 -> "802.11ad (WiGig)"
        8 -> "Wi-Fi 7 (802.11be)"
        else -> "inconnue"
    }

    private fun securityType(t: Int) = when (t) {
        0 -> "OUVERT (non chiffré)"
        1 -> "WEP (obsolète)"
        2 -> "WPA/WPA2-Personnel"
        3 -> "WPA-Entreprise"
        4 -> "WPA3-Personnel (SAE)"
        5 -> "WPA3-Entreprise 192 bits"
        6 -> "OWE (ouvert chiffré)"
        9 -> "WPA3-Entreprise"
        else -> "type $t"
    }

    fun capabilitiesToSecurity(caps: String) = when {
        caps.contains("SAE") -> "WPA3"
        caps.contains("WPA2") || caps.contains("RSN") -> "WPA2"
        caps.contains("WPA") -> "WPA"
        caps.contains("WEP") -> "WEP"
        caps.contains("OWE") -> "OWE"
        else -> "Ouvert"
    }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    fun wifiScan(ctx: Context): List<Map<String, Any?>> {
        if (ctx.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return emptyList()
        val wm = ctx.applicationContext.getSystemService(WifiManager::class.java) ?: return emptyList()
        try {
            wm.startScan()
            Thread.sleep(2500)
        } catch (_: Throwable) {
        }
        return wm.scanResults.map { r: ScanResult ->
            mapOf(
                "ssid" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) r.wifiSsid?.toString()?.trim('"') else r.SSID),
                "bssid" to r.BSSID,
                "level" to r.level,
                "frequency" to r.frequency,
                "channel" to channel(r.frequency),
                "band" to band(r.frequency),
                "security" to capabilitiesToSecurity(r.capabilities ?: ""),
                "standard" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) r.wifiStandard else null,
            )
        }
    }

    fun ipv4(): String? = NetworkInterface.getNetworkInterfaces()?.toList()?.flatMap { it.inetAddresses.toList() }
        ?.firstOrNull { !it.isLoopbackAddress && it is Inet4Address }?.hostAddress
}
