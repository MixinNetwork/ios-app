import Foundation
import WebRTC

extension RTCSessionDescription {
    
    private enum CodingKeys: String {
        case sdp, type
    }
    
    var jsonString: String? {
        let json: [String : Any] = [CodingKeys.sdp.rawValue: sdp,
                                    CodingKeys.type.rawValue: RTCSessionDescription.string(for: type)]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: []) {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    convenience init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        guard let sdp = json[CodingKeys.sdp.rawValue] as? String, let typeValue = json[CodingKeys.type.rawValue] as? String else {
            return nil
        }
        self.init(type: RTCSessionDescription.type(for: typeValue), sdp: sdp)
    }
    
}
