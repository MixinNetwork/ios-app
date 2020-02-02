import Foundation

extension AppGroupUserDefaults {
    
    public enum Signal {
        
        enum Key: String, CaseIterable {
            case registrationId = "registration_id"
            case privateKey = "private_key"
            case publicKey = "public_key"
        }
        
        @Default(namespace: .signal, key: Key.registrationId, defaultValue: 0)
        public static var registrationId: UInt32
        
        @Default(namespace: .signal, key: Key.privateKey, defaultValue: Data())
        public static var privateKey: Data
        
        @Default(namespace: .signal, key: Key.publicKey, defaultValue: Data())
        public static var publicKey: Data
        
        internal static func migrate() {
            registrationId = UInt32(UserDefaults.standard.integer(forKey: "local_registration_id"))
            privateKey = UserDefaults.standard.data(forKey: "local_private_key") ?? Data()
            publicKey = UserDefaults.standard.data(forKey: "local_public_key") ?? Data()
        }
        
    }
    
}
