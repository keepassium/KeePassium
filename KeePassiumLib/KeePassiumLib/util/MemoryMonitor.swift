//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public enum MemoryMonitor {
    public static let autoFillMemoryLimit = 120_000_000

    public static let autoFillMemoryWarningThresholdMiB: Float = bytesToMiB(24_000_000)

    private static let mib = Float(1024 * 1024)

    public static func bytesToMiB(_ byteCount: Int) -> Float {
        return Float(byteCount) / mib
    }

    public static func getMemoryFootprint() -> Int {
        let TASK_VM_INFO_COUNT = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(
            MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
        var taskInfo = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT
        let kernelResult = withUnsafeMutablePointer(to: &taskInfo) { taskInfoPtr in
            taskInfoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard kernelResult == KERN_SUCCESS,
              count >= TASK_VM_INFO_REV1_COUNT
        else { return 0 }

        let memoryFootprint = Int(taskInfo.phys_footprint)
        return memoryFootprint
    }

    public static func getMemoryFootprintMiB() -> Float {
        return bytesToMiB(getMemoryFootprint())
    }

    public static func estimateAutoFillMemoryRemaining() -> Int {
        assert(!AppGroup.isMainApp, "The result is not valid for the main app")
        #if targetEnvironment(macCatalyst)
        return autoFillMemoryLimit - getMemoryFootprint()
        #else
        return os_proc_available_memory()
        #endif
    }

    public static func estimateAutoFillMemoryRemainingMiB() -> Float {
        return bytesToMiB(estimateAutoFillMemoryRemaining())
    }
}
