import AppKit
import CoreWLAN
import Darwin
import Foundation
import IOKit
import IOKit.ps

// MARK: - Snapshots

struct CPUReading {
    var userPercent: Double = 0
    var systemPercent: Double = 0
    var idlePercent: Double = 100
    var loadAverage: [Double] = []

    var busyPercent: Double { max(0, min(100, 100 - idlePercent)) }
}

struct MemoryReading {
    var total: Int64 = 0
    var app: Int64 = 0
    var wired: Int64 = 0
    var compressed: Int64 = 0
    var cached: Int64 = 0
    var swapUsed: Int64 = 0

    /// What Activity Monitor calls "Memory Used".
    var used: Int64 { app + wired + compressed }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    /// Swap and compression are the honest signals that RAM is tight; a high
    /// "used" number on its own is normal and healthy on macOS.
    var pressure: Pressure {
        if swapUsed > 2_000_000_000 || usedFraction > 0.92 { return .high }
        if swapUsed > 200_000_000 || usedFraction > 0.80 { return .medium }
        return .low
    }

    enum Pressure { case low, medium, high }
}

struct BatteryReading {
    var percentage: Int = 0
    var isCharging = false
    var isPluggedIn = false
    var minutesRemaining: Int?
    var cycleCount: Int?
    var healthPercent: Int?
    var condition: String?
}

struct WiFiReading {
    var interfaceName: String?
    var ssid: String?
    var rssi: Int?
    var noise: Int?
    var transmitRateMbps: Double?
    var channel: Int?
    var ipAddress: String?
    var isPowered = false

    /// RSSI in dBm mapped to four bars, the way every OS shows it.
    var bars: Int {
        guard let rssi else { return 0 }
        switch rssi {
        case (-60)...: return 4
        case (-70)..<(-60): return 3
        case (-80)..<(-70): return 2
        default: return 1
        }
    }
}

struct HostReading {
    var model: String = ""
    var chip: String = ""
    var cores: String = ""
    var osVersion: String = ""
    var uptime: TimeInterval = 0
    var hostName: String = ""
}

struct DeviceReading: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let kind: Kind

    enum Kind: String { case usb, bluetooth, display }
}

// MARK: - Monitor

enum SystemMonitor {
    // MARK: CPU

    /// Ticks from the previous sample; CPU load is only meaningful as a delta.
    private nonisolated(unsafe) static var previousTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private static let ticksLock = NSLock()

    static func cpu() -> CPUReading {
        var reading = CPUReading()

        // HOST_CPU_LOAD_INFO_COUNT is a C macro the Swift importer drops, so the
        // element count is derived from the struct instead.
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let user = UInt64(info.cpu_ticks.0)
            let system = UInt64(info.cpu_ticks.1)
            let idle = UInt64(info.cpu_ticks.2)
            let nice = UInt64(info.cpu_ticks.3)

            ticksLock.lock()
            let previous = previousTicks
            previousTicks = (user, system, idle, nice)
            ticksLock.unlock()

            if let previous {
                let dUser = Double(user &- previous.user) + Double(nice &- previous.nice)
                let dSystem = Double(system &- previous.system)
                let dIdle = Double(idle &- previous.idle)
                let total = dUser + dSystem + dIdle
                if total > 0 {
                    reading.userPercent = dUser / total * 100
                    reading.systemPercent = dSystem / total * 100
                    reading.idlePercent = dIdle / total * 100
                }
            }
        }

        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 { reading.loadAverage = loads }
        return reading
    }

    // MARK: Memory

    static func memory() -> MemoryReading {
        var reading = MemoryReading()
        reading.total = Int64(ProcessInfo.processInfo.physicalMemory)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let page = Int64(vm_kernel_page_size)
            let purgeable = Int64(stats.purgeable_count)
            let external = Int64(stats.external_page_count)
            reading.wired = Int64(stats.wire_count) * page
            reading.compressed = Int64(stats.compressor_page_count) * page
            reading.app = max(0, (Int64(stats.internal_page_count) - purgeable) * page)
            reading.cached = (external + purgeable) * page
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            reading.swapUsed = Int64(swap.xsu_used)
        }
        return reading
    }

    // MARK: Battery

    static func battery() -> BatteryReading? {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
            let first = sources.first,
            let description = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue()
                as? [String: Any]
        else { return nil }

        var reading = BatteryReading()
        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
        reading.percentage = max > 0 ? Int(Double(current) / Double(max) * 100) : 0
        reading.isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        reading.isPluggedIn =
            (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        reading.condition = description["BatteryHealth"] as? String

        let remaining =
            reading.isCharging
            ? description[kIOPSTimeToFullChargeKey] as? Int
            : description[kIOPSTimeToEmptyKey] as? Int
        if let remaining, remaining > 0 { reading.minutesRemaining = remaining }

        // Cycle count and true health live in the IO registry, not in IOPS.
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        if service != 0 {
            defer { IOObjectRelease(service) }
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
                == KERN_SUCCESS,
                let values = properties?.takeRetainedValue() as? [String: Any]
            {
                reading.cycleCount = values["CycleCount"] as? Int
                if let design = values["DesignCapacity"] as? Int, design > 0,
                    let raw = (values["AppleRawMaxCapacity"] ?? values["NominalChargeCapacity"])
                        as? Int
                {
                    reading.healthPercent = Int(Double(raw) / Double(design) * 100)
                }
            }
        }
        return reading
    }

    // MARK: Wi-Fi

    static func wifi() -> WiFiReading? {
        guard let interface = CWWiFiClient.shared().interface() else { return nil }

        var reading = WiFiReading()
        reading.interfaceName = interface.interfaceName
        reading.isPowered = interface.powerOn()
        // macOS 14+ hides the SSID unless the app has Location access; the rest of
        // the numbers stay available, so a nil name is shown as "—" not an error.
        reading.ssid = interface.ssid()
        reading.rssi = interface.rssiValue() == 0 ? nil : interface.rssiValue()
        reading.noise = interface.noiseMeasurement() == 0 ? nil : interface.noiseMeasurement()
        reading.transmitRateMbps = interface.transmitRate() == 0 ? nil : interface.transmitRate()
        reading.channel = interface.wlanChannel()?.channelNumber
        reading.ipAddress = interface.interfaceName.flatMap(ipv4Address(of:))
        return reading
    }

    static func ipv4Address(of interfaceName: String) -> String? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard
                let name = current.pointee.ifa_name.map({ String(cString: $0) }),
                name == interfaceName,
                let address = current.pointee.ifa_addr,
                address.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                address, socklen_t(address.pointee.sa_len),
                &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST
            ) == 0 {
                return String(cString: host)
            }
        }
        return nil
    }

    // MARK: Host

    static func host() -> HostReading {
        var reading = HostReading()
        reading.model = sysctlString("hw.model")
        reading.chip = sysctlString("machdep.cpu.brand_string")
        let performance = sysctlInt("hw.perflevel0.logicalcpu")
        let efficiency = sysctlInt("hw.perflevel1.logicalcpu")
        let logical = sysctlInt("hw.logicalcpu")
        reading.cores =
            (performance > 0 && efficiency > 0)
            ? "\(logical) (\(performance)P + \(efficiency)E)"
            : "\(logical)"
        reading.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        reading.uptime = ProcessInfo.processInfo.systemUptime
        reading.hostName = Host.current().localizedName ?? ""
        return reading
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }

    private static func sysctlInt(_ name: String) -> Int {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return 0 }
        return value
    }

    // MARK: Attached devices

    /// Displays come from AppKit; USB and Bluetooth from `system_profiler`, which
    /// takes a second or two and so is only refreshed on demand.
    static func displays() -> [DeviceReading] {
        NSScreen.screens.enumerated().map { index, screen in
            let size = screen.frame.size
            let scale = screen.backingScaleFactor
            let hz = screen.maximumFramesPerSecond
            return DeviceReading(
                id: "display-\(index)",
                name: screen.localizedName,
                detail: "\(Int(size.width * scale))×\(Int(size.height * scale)) · \(hz) Hz",
                kind: .display
            )
        }
    }

    static func usbDevices() -> [DeviceReading] {
        profilerItems(dataType: "SPUSBDataType", kind: .usb) { item in
            let speed = item["device_speed"] as? String
            let maker = item["manufacturer"] as? String
            return [maker, speed?.replacingOccurrences(of: "_speed", with: "")]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }

    static func bluetoothDevices() -> [DeviceReading] {
        profilerItems(dataType: "SPBluetoothDataType", kind: .bluetooth) { item in
            let type = item["device_minorType"] as? String
            let battery = item["device_batteryLevelMain"] as? String
            return [type, battery].compactMap { $0 }.joined(separator: " · ")
        }
    }

    private static func profilerItems(
        dataType: String,
        kind: DeviceReading.Kind,
        detail: ([String: Any]) -> String
    ) -> [DeviceReading] {
        let output = Shell.run("/usr/sbin/system_profiler", ["-json", dataType], timeout: 25)
        guard
            let data = output.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let top = root[dataType] as? [[String: Any]]
        else { return [] }

        var found: [DeviceReading] = []
        var seen = Set<String>()

        /// The profiler nests hubs and controllers, so walk `_items` recursively.
        func walk(_ items: [[String: Any]], depth: Int) {
            guard depth < 6 else { return }
            for item in items {
                if let name = item["_name"] as? String, !name.isEmpty {
                    let connected = item["device_connected"] as? String
                    let isDisconnected = connected?.lowercased().contains("not connected") == true
                    if !isDisconnected {
                        let id = "\(kind.rawValue)-\(name)-\(found.count)"
                        if !seen.contains(name) {
                            seen.insert(name)
                            found.append(
                                DeviceReading(id: id, name: name, detail: detail(item), kind: kind)
                            )
                        }
                    }
                }
                for key in ["_items", "device_connected", "device_not_connected"] {
                    if let nested = item[key] as? [[String: Any]] { walk(nested, depth: depth + 1) }
                }
            }
        }

        walk(top, depth: 0)
        return found
    }
}
