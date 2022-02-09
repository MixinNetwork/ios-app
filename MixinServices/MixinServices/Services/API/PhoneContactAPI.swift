import Alamofire
import MixinServices

public final class PhoneContactAPI: MixinAPI {
    
    enum Path {
        static let contacts = "/contacts"
    }
    
    public static func upload(contacts: [PhoneContact], completion: ((MixinAPI.Result<Empty>) -> Void)? = nil) {
        let parameters = contacts.map({ ["phone": $0.phoneNumber, "full_name": $0.fullName] })
        request(method: .post, path: Path.contacts, parameters: parameters) { (result) in
            completion?(result)
        }
    }
    
}
