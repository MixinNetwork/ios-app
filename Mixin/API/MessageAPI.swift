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
    }

    func messageStatus(offset: Int64) -> Result<[BlazeMessageData]> {
        return request(method: .get, url: url.messageStatus(offset: offset))
    }

    func requestAttachment() -> Result<AttachmentResponse> {
         return request(method: .post, url: url.attachments)
    }

    func getAttachment(id: String) -> Result<AttachmentResponse> {
        return request(method: .get, url: url.attachments(id: id))
    }
}
