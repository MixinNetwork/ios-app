import Foundation

public enum CaptchaToken {
    
    case reCaptcha(String)
    case hCaptcha(String)
    
    var keyValuePair: (String, String) {
        switch self {
        case .reCaptcha(let value):
            ("g_recaptcha_response", value)
        case .hCaptcha(let value):
            ("hcaptcha_response", value)
        }
    }
    
}
