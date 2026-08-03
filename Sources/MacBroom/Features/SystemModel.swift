import Foundation

@MainActor
final class SystemModel: ObservableObject {
    @Published private(set) var cpu = CPUReading()
    @Published private(set) var memory = MemoryReading()
    @Published private(set) var battery: BatteryReading?
    @Published private(set) var wifi: WiFiReading?
    @Published private(set) var host = HostReading()
    @Published private(set) var displays: [DeviceReading] = []
    @Published private(set) var usb: [DeviceReading] = []
    @Published private(set) var bluetooth: [DeviceReading] = []
    @Published private(set) var isLoadingDevices = false

    private var ticker: Task<Void, Never>?

    /// Live values refresh on a timer; the device lists shell out to
    /// `system_profiler` and are only rebuilt when asked.
    func start() {
        guard ticker == nil else { return }
        host = SystemMonitor.host()
        sampleLive()
        loadDevices()

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }
                self?.sampleLive()
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    private func sampleLive() {
        cpu = SystemMonitor.cpu()
        memory = SystemMonitor.memory()
        battery = SystemMonitor.battery()
        wifi = SystemMonitor.wifi()
        host.uptime = ProcessInfo.processInfo.systemUptime
        displays = SystemMonitor.displays()
    }

    func loadDevices() {
        guard !isLoadingDevices else { return }
        isLoadingDevices = true

        Task { [weak self] in
            let usbDevices = await Task.detached(priority: .utility) {
                SystemMonitor.usbDevices()
            }.value
            let bluetoothDevices = await Task.detached(priority: .utility) {
                SystemMonitor.bluetoothDevices()
            }.value

            guard let self else { return }
            self.usb = usbDevices
            self.bluetooth = bluetoothDevices
            self.isLoadingDevices = false
        }
    }

    func refresh() {
        host = SystemMonitor.host()
        sampleLive()
        loadDevices()
    }
}
