import Foundation

public enum AppCardContentConverter {
    
    // Due to historical reasons, we are using different serialization between database and transcript
    
    public static func transcriptAppCard(from localAppCard: String?) -> String? {
        localAppCard?.base64Decoded()
    }
    
    public static func localAppCard(from transcriptAppCard: String?) -> String? {
        transcriptAppCard?.base64Encoded()
    }
    
}
