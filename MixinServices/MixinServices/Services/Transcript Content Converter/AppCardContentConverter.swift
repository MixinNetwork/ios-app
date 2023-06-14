import Foundation

public enum AppCardContentConverter {
    
    // Due to historical reasons, we are using different serialization between local and outsend ones
    
    public static func generalAppCard(from localAppCard: String?) -> String? {
        localAppCard?.base64Decoded()
    }
    
    public static func localAppCard(from generalAppCard: String?) -> String? {
        generalAppCard?.base64Encoded()
    }
    
}
