import Foundation

public enum ExtensionName: String {
    
    case jpeg = "jpg"
    case mp4
    case html
    case ogg
    case gif
    
    public var withDot: String {
        return "." + rawValue
    }
    
}
