import Darwin
import Foundation
import Observation

/// System-wide memory snapshot for the popover's overview card: total
/// physical RAM and the "used" portion, refreshed on a short timer.
///
/// Built on mach host statistics (`host_statistics64`), which need no
/// entitlements, so this works identically in the Developer ID and the
/// sandboxed App Store build. "Used" mirrors the memory-pressure view:
/// wired + compressed + active pages; free, purgeable and inactive pages
/// are reclaimable and not counted.
@Observable
@MainActor
final class SystemMemoryMonitor {
    private(set) var totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    private(set) var usedBytes: UInt64 = 0

    /// Fraction of physical memory in use (0...1), driving the progress bar.
    var usedFraction: Double {
        totalBytes > 0 ? min(Double(usedBytes) / Double(totalBytes), 1) : 0
    }

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            UInt32(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        )
        var pageSize: vm_size_t = 0
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return }
        usedBytes = (UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count))
            * UInt64(pageSize)
    }
}
