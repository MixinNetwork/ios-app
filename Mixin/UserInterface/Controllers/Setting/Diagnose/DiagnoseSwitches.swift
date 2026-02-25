import Foundation

enum DiagnoseSwitches {
    
    static var isWebViewInspectable = {
#if DEBUG
        true
#else
        false
#endif
    }()
    
}
