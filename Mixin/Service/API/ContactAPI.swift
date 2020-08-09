import MixinServices

final class ContactAPI: MixinAPI {
    
    enum Path {
        static let contacts = "/friends"
    }
    
    static func syncContacts() {
        request(method: .get, path: Path.contacts) { (result: MixinAPI.Result<[UserResponse]>) in
            switch result {
            case let .success(contacts):
                UserDAO.shared.updateUsers(users: contacts, notifyContact: true)
            case .failure:
                break
            }
        }
    }
    
}


