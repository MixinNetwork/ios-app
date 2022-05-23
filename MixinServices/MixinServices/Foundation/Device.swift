import Foundation

public struct Machine {
    
    public static let current = Machine()
    
    public let name: String
    
    init() {
        var name = [CTL_HW, HW_MACHINE]
        var size: Int = 2
        sysctl(&name, 2, nil, &size, nil, 0)
        
        var hw_machine = [CChar](repeating: 0, count: size)
        sysctl(&name, 2, &hw_machine, &size, nil, 0)
        
        var result = String(cString: hw_machine)
        if ["x86_64", "i386", "arm64"].contains(result), let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            result = model
        }
        self.name = result
    }
    
}
