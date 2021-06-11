import UIKit
import Alamofire

public class MessageAPI: MixinAPI {
    
    private enum Path {
        
        static let attachments = "/attachments"
        static func attachments(id: String) -> String {
            return "/attachments/\(id)"
        }
        
        static let acknowledge = "/messages/acknowledge"
        
        static func messageStatus(offset: Int64) -> String {
            return "/messages/status/\(offset)"
        }
        
        static let acknowledgements = "/acknowledgements"
    }
    
    public static func acknowledgements(ackMessages: [AckMessage]) -> MixinAPI.Result<Empty> {
        let parameters = ackMessages.map({ ["message_id": $0.messageId, "status": $0.status] })
        return request(method: .post, path: Path.acknowledgements, parameters: parameters)
    }
    
    public static func messageStatus(offset: Int64) -> MixinAPI.Result<[BlazeMessageData]> {
        return request(method: .get, path: Path.messageStatus(offset: offset))
    }
    
    public static func requestAttachment() -> MixinAPI.Result<AttachmentResponse> {
        return request(method: .post, path: Path.attachments)
    }
    
    public static func requestAttachment(queue: DispatchQueue, completion: @escaping (MixinAPI.Result<AttachmentResponse>) -> Void) -> Request? {
        request(method: .post, path: Path.attachments, queue: queue, completion: completion)
    }
    
    public static func getAttachment(id: String) -> MixinAPI.Result<AttachmentResponse> {
        return request(method: .get, path: Path.attachments(id: id))
    }
    
}
