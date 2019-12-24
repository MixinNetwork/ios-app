import UIKit

public class ContactAPI: BaseAPI {

    public static let shared = ContactAPI()

    enum url {
        static let contacts = "friends"
    }

    public func syncContacts() {
        request(method: .get, url: url.contacts) { (result: APIResult<[UserResponse]>) in
            switch result {
            case let .success(contacts):
                UserDAO.shared.updateUsers(users: contacts, notifyContact: true)
            case .failure:
                break
            }
        }
    }

}


