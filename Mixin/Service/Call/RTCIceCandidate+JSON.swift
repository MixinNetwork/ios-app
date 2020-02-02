import Foundation
import WebRTC

fileprivate enum CodingKeys: String {
    case sdp
    case sdpMid
    case sdpMLineIndex
}

extension RTCIceCandidate {
    
    fileprivate var jsonDict: [String: Any] {
        var dict: [String : Any] = [CodingKeys.sdp.rawValue: sdp,
                                    CodingKeys.sdpMLineIndex.rawValue: sdpMLineIndex]
        if let sdpMid = sdpMid {
            dict[CodingKeys.sdpMid.rawValue] = sdpMid
        }
        return dict
    }
    
}

extension Array where Element: RTCIceCandidate {
    
    var jsonString: String? {
        let jsonDictArray = map({ $0.jsonDict })
        if let data = try? JSONSerialization.data(withJSONObject: jsonDictArray, options: []) {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    init(jsonString: String) {
        guard let data = jsonString.data(using: .utf8), let jsons = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            self = []
            return
        }
        var result = Array<Element>()
        for json in jsons {
            guard let sdp = json[CodingKeys.sdp.rawValue] as? String, let sdpMLineIndex = json[CodingKeys.sdpMLineIndex.rawValue] as? Int32 else {
                continue
            }
            let sdpMid = json[CodingKeys.sdpMid.rawValue] as? String
            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid) as! Element
            result.append(candidate)
        }
        self = result
    }
    
}
