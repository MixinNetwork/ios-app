import Foundation

public struct Device {
    
    public static let current = Device()
    
    public let id: String = {
        if let data = AppGroupKeychain.deviceID, let id = String(data: data, encoding: .utf8) {
            return id
        } else {
            let id = UUID().uuidString.lowercased()
            if let data = id.data(using: .utf8) {
                AppGroupKeychain.deviceID = data
            }
            return id
        }
    }()
    
    public let machineName: String = {
        var name = [CTL_HW, HW_MACHINE]
        var size: Int = 2
        sysctl(&name, 2, nil, &size, nil, 0)
        
        var hw_machine = [CChar](repeating: 0, count: size)
        sysctl(&name, 2, &hw_machine, &size, nil, 0)
        
        var result = String(cString: hw_machine)
        if ["x86_64", "i386", "arm64"].contains(result), let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            result = model
        }
        return result
    }()
    
    private init() {
        
    }
    
}
