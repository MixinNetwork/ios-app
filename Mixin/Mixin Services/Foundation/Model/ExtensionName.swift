import Foundation

public enum ExtensionName: String {
    
    case jpeg = "jpg"
    case mp4
    case html
    case ogg
    case gif
    
    var withDot: String {
        return "." + rawValue
    }
    
}
