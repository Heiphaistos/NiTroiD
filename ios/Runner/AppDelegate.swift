import AVFoundation
import AudioToolbox
import CFNetwork
import CoreHaptics
import CoreMotion
import CoreTelephony
import Flutter
import LocalAuthentication
import MachO
import Metal
import Network
import UIKit
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar: FlutterPluginRegistrar? = engineBridge.pluginRegistry.registrar(forPlugin: "NitroidNative")
    if let registrar = registrar {
      NitroidNative.register(with: registrar)
    }
  }
}

// MARK: - Pont natif iOS (même contrat que MainActivity.kt sur Android)

final class NitroidNative: NSObject, FlutterPlugin {
  private let sensors = SensorStream()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NitroidNative()
    let channel = FlutterMethodChannel(name: "nitroid/native", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    FlutterEventChannel(name: "nitroid/sensors", binaryMessenger: registrar.messenger()).setStreamHandler(instance.sensors)
    UIDevice.current.isBatteryMonitoringEnabled = true
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getInfo":
      let category = args["category"] as? String ?? "system"
      if category == "network" {
        // NWPathMonitor est asynchrone : on attend le premier chemin hors du thread principal.
        DispatchQueue.global(qos: .userInitiated).async {
          let value = Info.network()
          DispatchQueue.main.async { result(value) }
        }
      } else {
        result(Info.category(category))
      }
    case "getDashboard": result(Info.dashboard())
    case "getLive": result(Info.live())
    case "listSensors": result(Info.sensors())
    case "securityChecks": result(SecurityChecks.all())
    case "openSettings": result(Actions.openSettings(args["action"] as? String ?? "app"))
    case "torch": result(Actions.torch(args["on"] as? Bool ?? false))
    case "vibrate": result(Actions.vibrate(ms: args["ms"] as? Int ?? 200))
    case "tone":
      AudioServicesPlaySystemSound(1057)
      result(true)
    case "permissions": result([String: Bool]())
    case "appInfo":
      let info = Bundle.main.infoDictionary ?? [:]
      result([
        "version": info["CFBundleShortVersionString"] as? String ?? "",
        "build": info["CFBundleVersion"] as? String ?? "",
        "abis": ["arm64"],
      ])
    case "openUrl":
      guard let raw = args["url"] as? String, raw.hasPrefix("https://"), let url = URL(string: raw) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
      result(true)
    default: result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - Outils communs

typealias Section = [String: Any]

final class SectionBuilder {
  private(set) var rows: [[String]] = []

  func add(_ key: String, _ value: Any?) {
    guard let value = value else { return }
    let text: String
    switch value {
    case let b as Bool: text = b ? "oui" : "non"
    default: text = "\(value)"
    }
    if !text.isEmpty { rows.append([key, text]) }
  }
}

func section(_ title: String, _ build: (SectionBuilder) -> Void) -> Section? {
  let b = SectionBuilder()
  build(b)
  return b.rows.isEmpty ? nil : ["title": title, "items": b.rows]
}

func formatBytes(_ v: UInt64) -> String {
  ByteCountFormatter.string(fromByteCount: Int64(v), countStyle: .memory)
}

func formatDuration(_ seconds: TimeInterval) -> String {
  let s = Int(seconds)
  let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
  return d > 0 ? "\(d)j \(h)h \(m)min" : "\(h)h \(m)min"
}

enum Hardware {
  /// Convertit un champ C de `utsname` (tableau de CChar terminé par 0) en String.
  static func cString<T>(_ field: T) -> String {
    withUnsafeBytes(of: field) { raw in String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self) }
  }

  static var kernelRelease: String {
    var u = utsname()
    uname(&u)
    return cString(u.release)
  }

  static var kernelVersion: String {
    var u = utsname()
    uname(&u)
    return cString(u.version)
  }

  static var machine: String {
    #if targetEnvironment(simulator)
    return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
    #else
    var u = utsname()
    uname(&u)
    return cString(u.machine)
    #endif
  }

  /// Identifiant → (nom commercial, puce). Les modèles inconnus gardent leur identifiant.
  static let models: [String: (String, String)] = [
    "iPhone12,1": ("iPhone 11", "A13 Bionic"), "iPhone12,3": ("iPhone 11 Pro", "A13 Bionic"),
    "iPhone12,5": ("iPhone 11 Pro Max", "A13 Bionic"), "iPhone12,8": ("iPhone SE (2e gén.)", "A13 Bionic"),
    "iPhone13,1": ("iPhone 12 mini", "A14 Bionic"), "iPhone13,2": ("iPhone 12", "A14 Bionic"),
    "iPhone13,3": ("iPhone 12 Pro", "A14 Bionic"), "iPhone13,4": ("iPhone 12 Pro Max", "A14 Bionic"),
    "iPhone14,4": ("iPhone 13 mini", "A15 Bionic"), "iPhone14,5": ("iPhone 13", "A15 Bionic"),
    "iPhone14,2": ("iPhone 13 Pro", "A15 Bionic"), "iPhone14,3": ("iPhone 13 Pro Max", "A15 Bionic"),
    "iPhone14,6": ("iPhone SE (3e gén.)", "A15 Bionic"), "iPhone14,7": ("iPhone 14", "A15 Bionic"),
    "iPhone14,8": ("iPhone 14 Plus", "A15 Bionic"), "iPhone15,2": ("iPhone 14 Pro", "A16 Bionic"),
    "iPhone15,3": ("iPhone 14 Pro Max", "A16 Bionic"), "iPhone15,4": ("iPhone 15", "A16 Bionic"),
    "iPhone15,5": ("iPhone 15 Plus", "A16 Bionic"), "iPhone16,1": ("iPhone 15 Pro", "A17 Pro"),
    "iPhone16,2": ("iPhone 15 Pro Max", "A17 Pro"), "iPhone17,3": ("iPhone 16", "A18"),
    "iPhone17,4": ("iPhone 16 Plus", "A18"), "iPhone17,1": ("iPhone 16 Pro", "A18 Pro"),
    "iPhone17,2": ("iPhone 16 Pro Max", "A18 Pro"), "iPhone17,5": ("iPhone 16e", "A18"),
  ]

  static var marketingName: String { models[machine]?.0 ?? machine }
  static var chip: String? { models[machine]?.1 }

  static func vmStats() -> (free: UInt64, active: UInt64, inactive: UInt64, wired: UInt64, compressed: UInt64)? {
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &stats) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
      }
    }
    guard kr == KERN_SUCCESS else { return nil }
    let page = UInt64(getpagesize())
    return (UInt64(stats.free_count) * page, UInt64(stats.active_count) * page,
            UInt64(stats.inactive_count) * page, UInt64(stats.wire_count) * page,
            UInt64(stats.compressor_page_count) * page)
  }

  static func bootTime() -> Date? {
    var tv = timeval()
    var size = MemoryLayout<timeval>.stride
    var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
    guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec))
  }

  static func debuggerAttached() -> Bool {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return false }
    return (info.kp_proc.p_flag & P_TRACED) != 0
  }

  static func storage() -> (total: UInt64, free: UInt64, important: UInt64)? {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    guard let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) else { return nil }
    return (UInt64(v.volumeTotalCapacity ?? 0), UInt64(v.volumeAvailableCapacity ?? 0), UInt64(v.volumeAvailableCapacityForImportantUsage ?? 0))
  }

  static var thermal: String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: return "Normal"
    case .fair: return "Chauffe légère"
    case .serious: return "Chauffe sévère (bridage)"
    case .critical: return "Critique"
    @unknown default: return "Inconnu"
    }
  }
}

// MARK: - Informations

enum Info {
  static func category(_ category: String) -> [Section] {
    switch category {
    case "system": return system()
    case "cpu": return cpu()
    case "battery": return battery()
    case "memory": return memory()
    case "storage": return storage()
    case "display": return display()
    case "cameras": return cameras()
    case "features": return features()
    default: return []
    }
  }

  static func system() -> [Section] {
    let device = UIDevice.current
    let p = ProcessInfo.processInfo
    return [
      section("Appareil") { s in
        s.add("Fabricant", "Apple")
        s.add("Modèle", Hardware.marketingName)
        s.add("Identifiant", Hardware.machine)
        s.add("Type", device.model)
        s.add("Nom", device.name)
        s.add("Puce", Hardware.chip)
        s.add("Identifiant fournisseur (IDFV)", device.identifierForVendor?.uuidString)
      },
      section("Système") { s in
        s.add("Version", "\(device.systemName) \(device.systemVersion)")
        s.add("Build", p.operatingSystemVersionString)
        s.add("Noyau Darwin", Hardware.kernelRelease)
        s.add("Détail du noyau", Hardware.kernelVersion)
        s.add("Allumé depuis", formatDuration(p.systemUptime))
        if let boot = Hardware.bootTime() {
          s.add("Démarré le", DateFormatter.localizedString(from: boot, dateStyle: .short, timeStyle: .short))
        }
        s.add("Mode économie d’énergie", p.isLowPowerModeEnabled)
        s.add("Langue", Locale.current.identifier)
        s.add("Fuseau horaire", TimeZone.current.identifier)
      },
    ].compactMap { $0 }
  }

  static func cpu() -> [Section] {
    let p = ProcessInfo.processInfo
    return [
      section("Processeur") { s in
        s.add("Puce", Hardware.chip ?? Hardware.machine)
        s.add("Cœurs", p.processorCount)
        s.add("Cœurs actifs", p.activeProcessorCount)
        #if arch(arm64)
        s.add("Architecture", "arm64")
        #else
        s.add("Architecture", "x86_64 (simulateur)")
        #endif
      },
      section("Graphismes") { s in
        if let gpu = MTLCreateSystemDefaultDevice() {
          s.add("GPU", gpu.name)
          s.add("Mémoire GPU recommandée", formatBytes(UInt64(gpu.recommendedMaxWorkingSetSize)))
          s.add("Ray tracing matériel", gpu.supportsRaytracing)
          var families: [(MTLGPUFamily, String)] = [(.apple8, "Apple 8"), (.apple7, "Apple 7"), (.apple6, "Apple 6")]
          if #available(iOS 17.0, *) { families.insert((.apple9, "Apple 9"), at: 0) }
          s.add("Famille Metal", families.first { gpu.supportsFamily($0.0) }?.1)
        }
      },
    ].compactMap { $0 }
  }

  static func battery() -> [Section] {
    let d = UIDevice.current
    return [
      section("Batterie") { s in
        if d.batteryLevel >= 0 { s.add("Niveau", "\(Int(d.batteryLevel * 100)) %") }
        s.add("État", batteryState(d.batteryState))
        s.add("Mode économie d’énergie", ProcessInfo.processInfo.isLowPowerModeEnabled)
        s.add("Santé, cycles, capacité", "Non exposés aux apps par iOS : Réglages › Batterie › État de la batterie")
      },
    ].compactMap { $0 }
  }

  static func batteryState(_ state: UIDevice.BatteryState) -> String {
    switch state {
    case .charging: return "En charge"
    case .full: return "Pleine"
    case .unplugged: return "Sur batterie"
    default: return "Inconnu"
    }
  }

  static func memory() -> [Section] {
    let total = ProcessInfo.processInfo.physicalMemory
    return [
      section("Mémoire vive") { s in
        s.add("Totale", formatBytes(total))
        if let vm = Hardware.vmStats() {
          s.add("Libre", formatBytes(vm.free))
          s.add("Active", formatBytes(vm.active))
          s.add("Inactive (récupérable)", formatBytes(vm.inactive))
          s.add("Câblée (noyau)", formatBytes(vm.wired))
          s.add("Compressée", formatBytes(vm.compressed))
        }
        s.add("Disponible pour NiTroiD", formatBytes(UInt64(os_proc_available_memory())))
      },
    ].compactMap { $0 }
  }

  static func storage() -> [Section] {
    guard let st = Hardware.storage() else { return [] }
    return [
      section("Stockage") { s in
        s.add("Capacité", formatBytes(st.total))
        s.add("Libre", formatBytes(st.free))
        s.add("Libre (fichiers importants)", formatBytes(st.important))
        s.add("Utilisé", formatBytes(st.total - st.free))
        s.add("Chiffrement", "Toujours actif (Data Protection)")
      },
    ].compactMap { $0 }
  }

  static func display() -> [Section] {
    let screen = UIScreen.main
    return [
      section("Écran") { s in
        s.add("Résolution", "\(Int(screen.nativeBounds.width)) × \(Int(screen.nativeBounds.height)) px")
        s.add("Échelle", "@\(Int(screen.nativeScale))x")
        s.add("Fréquence max", "\(screen.maximumFramesPerSecond) Hz")
        s.add("Luminosité", "\(Int(screen.brightness * 100)) %")
        if #available(iOS 16.0, *) {
          s.add("Marge EDR (HDR)", String(format: "%.1f×", screen.potentialEDRHeadroom))
        }
        s.add("Mode sombre", screen.traitCollection.userInterfaceStyle == .dark)
        s.add("Gamme de couleurs", screen.traitCollection.displayGamut == .P3 ? "Display P3" : "sRGB")
      },
    ].compactMap { $0 }
  }

  static func cameras() -> [Section] {
    var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera, .builtInTrueDepthCamera]
    if #available(iOS 15.4, *) { types.append(.builtInLiDARDepthCamera) }
    let devices = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: nil, position: .unspecified).devices
    return devices.compactMap { d in
      section("\(d.localizedName) (\(d.position == .front ? "avant" : "arrière"))") { s in
        let dims = d.formats.map { CMVideoFormatDescriptionGetDimensions($0.formatDescription) }
        if let best = dims.max(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }) {
          s.add("Définition vidéo max", "\(best.width) × \(best.height)")
        }
        let fps = d.formats.flatMap { $0.videoSupportedFrameRateRanges.map { $0.maxFrameRate } }.max()
        if let fps = fps { s.add("Images/s max", Int(fps)) }
        s.add("Champ de vision", String(format: "%.0f°", d.activeFormat.videoFieldOfView))
        s.add("Zoom", String(format: "×%.0f à ×%.0f", d.minAvailableVideoZoomFactor, d.maxAvailableVideoZoomFactor))
        s.add("Flash", d.hasFlash)
        s.add("Torche", d.hasTorch)
      }
    }
  }

  static func features() -> [Section] {
    let motion = CMMotionManager()
    let bio = LAContext()
    _ = bio.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    return [
      section("Capteurs & fonctions") { s in
        s.add("Accéléromètre", motion.isAccelerometerAvailable)
        s.add("Gyroscope", motion.isGyroAvailable)
        s.add("Magnétomètre", motion.isMagnetometerAvailable)
        s.add("Baromètre", CMAltimeter.isRelativeAltitudeAvailable())
        s.add("Podomètre", CMPedometer.isStepCountingAvailable())
        s.add("Retour haptique (Taptic Engine)", CHHapticEngine.capabilitiesForHardware().supportsHaptics)
        s.add("Biométrie", biometryLabel(bio.biometryType))
        s.add("Multitâche", UIDevice.current.isMultitaskingSupported)
      },
    ].compactMap { $0 }
  }

  static func biometryLabel(_ type: LABiometryType) -> String {
    if type == .faceID { return "Face ID" }
    if type == .touchID { return "Touch ID" }
    if type == .none { return "Aucune" }
    return "Optic ID"
  }

  static func network() -> [Section] {
    var out: [Section] = []
    let monitor = NWPathMonitor()
    let sem = DispatchSemaphore(value: 0)
    var current: NWPath?
    monitor.pathUpdateHandler = { path in
      if current == nil {
        current = path
        sem.signal()
      }
    }
    monitor.start(queue: DispatchQueue(label: "nitroid.path"))
    _ = sem.wait(timeout: .now() + 1.5)
    monitor.cancel()
    if let path = current, let sec = section("Connexion active", { s in
      s.add("État", path.status == .satisfied ? "Connecté" : "Hors ligne")
      let kinds: [(NWInterface.InterfaceType, String)] = [(.wifi, "Wi-Fi"), (.cellular, "Mobile"), (.wiredEthernet, "Ethernet"), (.other, "Autre / VPN")]
      s.add("Type", kinds.filter { path.usesInterfaceType($0.0) }.map { $0.1 }.joined(separator: " + "))
      s.add("Coûteuse (données mobiles)", path.isExpensive)
      s.add("Mode données réduites", path.isConstrained)
      s.add("IPv4", path.supportsIPv4)
      s.add("IPv6", path.supportsIPv6)
      s.add("DNS", path.supportsDNS)
      s.add("Interfaces", path.availableInterfaces.map { $0.name }.joined(separator: ", "))
    }) { out.append(sec) }

    let tel = CTTelephonyNetworkInfo()
    if let techs = tel.serviceCurrentRadioAccessTechnology, !techs.isEmpty, let sec = section("Réseau mobile", { s in
      for (i, tech) in techs.values.enumerated() {
        s.add("Ligne \(i + 1)", tech.replacingOccurrences(of: "CTRadioAccessTechnology", with: ""))
      }
    }) { out.append(sec) }

    if let sec = section("Interfaces réseau", { s in
      var ifaddr: UnsafeMutablePointer<ifaddrs>?
      guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return }
      defer { freeifaddrs(ifaddr) }
      var byName: [String: [String]] = [:]
      for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        guard let addr = ptr.pointee.ifa_addr, (Int32(ptr.pointee.ifa_flags) & IFF_UP) != 0 else { continue }
        let family = addr.pointee.sa_family
        guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
        let name = String(cString: ptr.pointee.ifa_name)
        byName[name, default: []].append(String(cString: host).components(separatedBy: "%").first ?? "")
      }
      for name in byName.keys.sorted() { s.add(name, byName[name]!.joined(separator: ", ")) }
    }) { out.append(sec) }
    return out
  }

  static func dashboard() -> [String: Any?] {
    let d = UIDevice.current
    let st = Hardware.storage()
    let vm = Hardware.vmStats()
    return [
      "manufacturer": "Apple",
      "model": Hardware.marketingName,
      "os": "\(d.systemName) \(d.systemVersion)",
      "soc": Hardware.chip,
      "ramTotal": ProcessInfo.processInfo.physicalMemory,
      "ramAvail": vm.map { $0.free + $0.inactive },
      "storageTotal": st?.total,
      "storageFree": st?.important,
      "batteryLevel": d.batteryLevel >= 0 ? Int(d.batteryLevel * 100) : nil,
      "charging": d.batteryState == .charging || d.batteryState == .full,
    ]
  }

  static func live() -> [String: Any?] {
    let d = UIDevice.current
    let vm = Hardware.vmStats()
    return [
      "batteryLevel": d.batteryLevel >= 0 ? Int(d.batteryLevel * 100) : nil,
      "charging": d.batteryState == .charging || d.batteryState == .full,
      "ramTotal": ProcessInfo.processInfo.physicalMemory,
      "ramAvail": vm.map { $0.free + $0.inactive },
      "thermalStatus": Hardware.thermal,
      "thermalZones": [[String: Any]](),
    ]
  }

  /// Types alignés sur les constantes Android (1 accéléro, 2 magnéto, 4 gyro, 6 pression).
  static func sensors() -> [[String: Any]] {
    let m = CMMotionManager()
    var list: [[String: Any]] = []
    if m.isAccelerometerAvailable { list.append(["name": "Accéléromètre", "vendor": "Apple", "type": 1, "kind": "Accéléromètre", "unit": "m/s²", "live": true]) }
    if m.isGyroAvailable { list.append(["name": "Gyroscope", "vendor": "Apple", "type": 4, "kind": "Gyroscope", "unit": "rad/s", "live": true]) }
    if m.isMagnetometerAvailable { list.append(["name": "Magnétomètre", "vendor": "Apple", "type": 2, "kind": "Magnétomètre", "unit": "µT", "live": true]) }
    if CMAltimeter.isRelativeAltitudeAvailable() { list.append(["name": "Baromètre", "vendor": "Apple", "type": 6, "kind": "Baromètre", "unit": "hPa", "live": true]) }
    list.append(["name": "Capteur de proximité", "vendor": "Apple", "type": 8, "kind": "Proximité", "live": false])
    list.append(["name": "Capteur de luminosité ambiante", "vendor": "Apple", "type": 5, "kind": "Luminosité (réservé à iOS)", "live": false])
    return list
  }
}

// MARK: - Sécurité

enum SecurityChecks {
  static func check(_ id: String, _ title: String, _ status: String, _ detail: String, _ action: String? = nil) -> [String: Any?] {
    ["id": id, "title": title, "status": status, "detail": detail, "action": action]
  }

  static let jailbreakPaths = [
    "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app", "/Applications/Filza.app",
    "/Library/MobileSubstrate/MobileSubstrate.dylib", "/bin/bash", "/usr/sbin/sshd", "/etc/apt",
    "/private/var/lib/apt/", "/var/jb", "/var/binpack", "/usr/lib/TweakInject", "/.bootstrapped",
  ]

  static func jailbreakIndicators() -> [String] {
    #if targetEnvironment(simulator)
    return []
    #else
    var found = jailbreakPaths.filter { FileManager.default.fileExists(atPath: $0) }
    let probe = "/private/nitroid_jb_probe.txt"
    if (try? "x".write(toFile: probe, atomically: true, encoding: .utf8)) != nil {
      found.append("écriture hors du bac à sable")
      try? FileManager.default.removeItem(atPath: probe)
    }
    for scheme in ["cydia://", "sileo://", "zbra://", "filza://"] {
      if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) { found.append(scheme) }
    }
    let suspicious = ["MobileSubstrate", "libhooker", "SubstrateLoader", "TweakInject", "FridaGadget", "frida", "Cephei"]
    for i in 0..<_dyld_image_count() {
      if let name = _dyld_get_image_name(i).map({ String(cString: $0) }), let hit = suspicious.first(where: { name.contains($0) }) {
        found.append("bibliothèque injectée \(hit)")
      }
    }
    return found
    #endif
  }

  static func all() -> [[String: Any?]] {
    var out: [[String: Any?]] = []
    let jb = jailbreakIndicators()
    out.append(jb.isEmpty
      ? check("root", "Jailbreak", "ok", "Aucune trace de jailbreak")
      : check("root", "Appareil jailbreaké", "bad", "Indices : \(jb.joined(separator: ", ")). Les protections d’iOS sont désactivées."))

    let ctx = LAContext()
    let passcode = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    out.append(passcode
      ? check("lock", "Code de verrouillage", "ok", "Code configuré : les données sont chiffrées au repos")
      : check("lock", "Code de verrouillage", "bad", "Aucun code : vos données ne sont pas protégées.", "App-prefs:"))

    let bio = LAContext()
    let hasBio = bio.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    out.append(check("bio", "Biométrie", hasBio ? "ok" : "info", hasBio ? "\(Info.biometryLabel(bio.biometryType)) configuré" : "Aucune biométrie configurée"))

    let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    let version = UIDevice.current.systemVersion
    if major < 17 {
      out.append(check("patch", "Version d’iOS", "warn", "iOS \(version) ne reçoit plus tous les correctifs. Mettez à jour si possible.", "App-prefs:"))
    } else {
      out.append(check("patch", "Version d’iOS", "ok", "iOS \(version) — vérifiez Réglages › Général › Mise à jour logicielle"))
    }

    if let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] {
      let scoped = settings["__SCOPED__"] as? [String: Any] ?? [:]
      let vpn = scoped.keys.contains { key in ["tap", "tun", "ppp", "ipsec", "utun"].contains { key.hasPrefix($0) } }
      if let proxy = settings[kCFNetworkProxiesHTTPProxy as String] as? String, !proxy.isEmpty {
        out.append(check("proxy", "Proxy réseau", "warn", "Trafic redirigé via \(proxy). Vérifiez qu’il est légitime (profil de configuration ?)."))
      } else if vpn {
        out.append(check("proxy", "VPN actif", "info", "Votre trafic passe par un VPN."))
      } else {
        out.append(check("proxy", "VPN / proxy", "ok", "Connexion directe"))
      }
    }

    if Hardware.debuggerAttached() {
      out.append(check("debug", "Débogueur attaché", "warn", "Un débogueur est connecté à NiTroiD."))
    }
    out.append(check("profiles", "Profils de configuration", "info",
                     "iOS ne laisse pas les apps lister les profils : vérifiez Réglages › Général › VPN et gestion de l’appareil.", "App-prefs:"))
    return out
  }
}

// MARK: - Actions

enum Actions {
  static func openSettings(_ action: String) -> Bool {
    var target: String
    switch action {
    case "app": target = UIApplication.openSettingsURLString
    case "notifications":
      if #available(iOS 16.0, *) { target = UIApplication.openNotificationSettingsURLString } else { target = UIApplication.openSettingsURLString }
    default: target = action
    }
    guard let url = URL(string: target) else { return false }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }

  static func torch(_ on: Bool) -> Bool {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return false }
    do {
      try device.lockForConfiguration()
      device.torchMode = on ? .on : .off
      device.unlockForConfiguration()
      return true
    } catch {
      return false
    }
  }

  static func vibrate(ms: Int) -> Bool {
    if ms < 150 {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    } else if ms < 1000 {
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    } else {
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    return true
  }
}

// MARK: - Capteurs en direct

final class SensorStream: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()
  private let altimeter = CMAltimeter()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    let type = (arguments as? [String: Any])?["type"] as? Int ?? 1
    let interval = 1.0 / 15.0
    switch type {
    case 1:
      guard motion.isAccelerometerAvailable else { break }
      motion.accelerometerUpdateInterval = interval
      motion.startAccelerometerUpdates(to: .main) { data, _ in
        guard let a = data?.acceleration else { return }
        events([a.x * 9.81, a.y * 9.81, a.z * 9.81])
      }
      return nil
    case 4:
      guard motion.isGyroAvailable else { break }
      motion.gyroUpdateInterval = interval
      motion.startGyroUpdates(to: .main) { data, _ in
        guard let r = data?.rotationRate else { return }
        events([r.x, r.y, r.z])
      }
      return nil
    case 2:
      guard motion.isMagnetometerAvailable else { break }
      motion.magnetometerUpdateInterval = interval
      motion.startMagnetometerUpdates(to: .main) { data, _ in
        guard let f = data?.magneticField else { return }
        events([f.x, f.y, f.z])
      }
      return nil
    case 6:
      guard CMAltimeter.isRelativeAltitudeAvailable() else { break }
      altimeter.startRelativeAltitudeUpdates(to: .main) { data, _ in
        guard let d = data else { return }
        events([d.pressure.doubleValue * 10, d.relativeAltitude.doubleValue])
      }
      return nil
    default:
      break
    }
    return FlutterError(code: "no_sensor", message: "Capteur indisponible", details: nil)
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopAccelerometerUpdates()
    motion.stopGyroUpdates()
    motion.stopMagnetometerUpdates()
    altimeter.stopRelativeAltitudeUpdates()
    return nil
  }
}
