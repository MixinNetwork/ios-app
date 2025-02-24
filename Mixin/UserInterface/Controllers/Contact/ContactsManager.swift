import Foundation
import Contacts
import MixinServices

class ContactsManager {
    
    static let shared = ContactsManager()
    
    let store = CNContactStore()
    
    var authorization: CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
    
    var contacts: [PhoneContact] {
        lock.lock()
        let contacts = _contacts
        lock.unlock()
        return contacts
    }
    
    private let lock = NSLock()
    
    private lazy var _contacts: [PhoneContact] = {
        guard let containers = try? store.containers(matching: nil) else {
            return []
        }
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        var cnContacts: [CNContact] = []
        for container in containers {
            let predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            guard let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch) else {
                continue
            }
            cnContacts += contacts
        }
        let utility = PhoneNumberValidator.global.utility
        var result: [PhoneContact] = []
        for cnContact in cnContacts {
            guard let fullName = CNContactFormatter.string(from: cnContact, style: .fullName) else {
                continue
            }
            let phoneNumberStrings = cnContact.phoneNumbers.map({ $0.value.stringValue })
            let phoneNumbers = phoneNumberStrings.compactMap({ try? utility.parse($0) })
            let mobilePhoneNumbers = phoneNumbers.filter({ $0.type == .mobile })
            let e164MobilePhoneNumbers = mobilePhoneNumbers.map({ utility.format($0, toType: .e164) })
            result += e164MobilePhoneNumbers.map({ PhoneContact(fullName: fullName, phoneNumber: $0) })
        }
        return result
    }()
    
}
