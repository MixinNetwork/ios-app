import MixinServices

public final class ContactAPI: MixinAPI {
    
    enum Path {
        static let contacts = "/friends"
    }
    
    public static func syncContacts() {
        request(method: .get, path: Path.contacts) { (result: MixinAPI.Result<[UserResponse]>) in
            switch result {
            case let .success(contacts):
                UserDAO.shared.updateUsers(users: contacts)
            case .failure:
                break
            }
        }
    }
    
}
