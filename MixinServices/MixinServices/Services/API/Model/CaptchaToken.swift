import Foundation

public enum CaptchaToken {
    
    case reCaptcha(String)
    case hCaptcha(String)
    case gtCaptcha([String: String])
    
    func asVerificationParameters() -> [String: String] {
        switch self {
        case .reCaptcha(let value):
            return ["g_recaptcha_response": value]
        case .hCaptcha(let value):
            return ["hcaptcha_response": value]
        case .gtCaptcha(let result):
            let requiredKeys = [
                "lot_number",
                "captcha_output",
                "pass_token",
                "gen_time",
            ]
            var values: [String: String] = [:]
            for key in requiredKeys {
                guard let value = result[key] else {
                    continue
                }
                values["gt4_" + key] = value
            }
            return values
        }
    }
    
}
