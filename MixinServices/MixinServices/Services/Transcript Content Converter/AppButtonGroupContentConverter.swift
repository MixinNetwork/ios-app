import Foundation

public enum AppButtonGroupContentConverter {
    
    // Due to historical reasons, we are using different serialization between local and outsend ones
    
    public static func generalAppButtonGroup(from localAppButtonGroup: String?) -> String? {
        localAppButtonGroup?.base64Decoded()
    }
    
    public static func localAppButtonGroup(from generalAppButtonGroup: String?) -> String? {
        generalAppButtonGroup?.base64Encoded()
    }
    
}
