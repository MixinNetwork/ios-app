import UIKit
import Alamofire

class MessageAPI: BaseAPI {

    static let shared = MessageAPI()

    private enum url {
        
        static let attachments = "attachments"
        static func attachments(id: String) -> String {
            return "attachments/\(id)"
        }

        static let acknowledge = "messages/acknowledge"

        static func messageStatus(offset: Int64) -> String {
            return "messages/status/\(offset)"
        }

        static let acknowledgements = "acknowledgements"
    }

    func acknowledgements(ackMessages: [AckMessage]) -> APIResult<EmptyResponse> {
        let parameters = ackMessages.map({ ["message_id": $0.messageId, "status": $0.status] }).toParameters()
        return request(method: .post, url: url.acknowledgements, parameters: parameters, encoding: JSONArrayEncoding())
    }

    func messageStatus(offset: Int64) -> APIResult<[BlazeMessageData]> {
        return request(method: .get, url: url.messageStatus(offset: offset))
    }

    func requestAttachment() -> APIResult<AttachmentResponse> {
         return request(method: .post, url: url.attachments)
    }

    func getAttachment(id: String) -> APIResult<AttachmentResponse> {
        return request(method: .get, url: url.attachments(id: id))
    }
}
