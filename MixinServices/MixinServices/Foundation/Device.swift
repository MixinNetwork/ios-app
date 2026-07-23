import Foundation

public struct Device {
    
    public static let current = Device()
    
    public let id: String
    public let machineName: String
    public let bezelCornerRadius: CGFloat?
    
    private init() {
        let deviceID = {
            if let data = AppGroupKeychain.deviceID,
               let id = String(data: data, encoding: .utf8)
            {
                return id
            } else {
                let id = UUID().uuidString.lowercased()
                if let data = id.data(using: .utf8) {
                    AppGroupKeychain.deviceID = data
                }
                return id
            }
        }()
        let machineName = {
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
        let bezelCornerRadius: CGFloat? = switch machineName {
        case "iPhone10,3", "iPhone10,6", "iPhone11,2", "iPhone11,4",
            "iPhone11,6", "iPhone12,3", "iPhone12,5":
            39
        case "iPhone11,8", "iPhone12,1":
            41.5
        case "iPhone13,1", "iPhone14,4":
            44
        case "iPhone13,2", "iPhone13,3", "iPhone14,2", "iPhone14,5",
            "iPhone14,7", "iPhone17,5", "iPhone18,5":
            47.33
        case "iPhone13,4", "iPhone14,3", "iPhone14,8":
            53.33
        case "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5",
            "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4":
            55
        case "iPhone17,1", "iPhone17,2", "iPhone18,1", "iPhone18,2",
            "iPhone18,3", "iPhone18,4":
            62
        default:
            nil
        }
        
        self.id = deviceID
        self.machineName = machineName
        self.bezelCornerRadius = bezelCornerRadius
    }
    
}
