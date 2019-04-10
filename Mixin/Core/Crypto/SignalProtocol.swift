import Foundation
import UIKit
import Bugsnag

class SignalProtocol {

    let DEFAULT_DEVICE_ID: Int32 = 1
    static let shared = SignalProtocol()
    private var store: SignalStore

    init() {
        store = try! SignalStore(
            identityKeyStore: MixinIdentityKeyStore(),
            preKeyStore: MixinPreKeyStore(),
            sessionStore: MixinSessionStore(),
            signedPreKeyStore: MixinSignedPreKeyStore(),
            senderKeyStore: MixinSenderKeyStore())
    }

    func initSignal() {
        guard let localRegistrationId = try? Signal.generateRegistrationId() else {
            return
        }
        UserDefaults.standard.set(localRegistrationId, forKey: PreKeyUtil.LOCAL_REGISTRATION_ID)

        guard let identityKeyPair = try? Signal.generateIdentityKeyPair() else {
            return
        }

        IdentityDao.shared.insertOrReplace(obj: Identity(address: "-1", registrationId: Int(localRegistrationId), publicKey: identityKeyPair.publicKey, privateKey: identityKeyPair.privateKey, nextPreKeyId: nil, timestamp: Date().timeIntervalSince1970))
        print("insert success identitiy")
    }

    func getRegistrationId() -> UInt32 {
        let registrationId = UserDefaults.standard.value(forKey: PreKeyUtil.LOCAL_REGISTRATION_ID) as! UInt32
        return registrationId
    }

    func clearSenderKey(groupId: String, senderId: String) {
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        store.senderKeyStore!.removeSenderKey(senderKeyName: senderKeyName)
    }

    func isExistSenderKey(groupId: String, senderId: String) -> Bool {
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        let data = store.senderKeyStore!.loadSenderKey(for: senderKeyName)
        return data != nil
    }

    func containsSession(recipient: String, deviceId: Int32 = SignalProtocol.shared.DEFAULT_DEVICE_ID) -> Bool {
        let address = SignalAddress(name: recipient, deviceId: deviceId)
        return store.sessionStore.containsSession(for: address)
    }

    func deleteSession(userId: String) {
        SessionDAO.shared.delete(address: userId)
    }

    func processSession(userId: String, signalKey: SignalKeyResponse, deviceId: Int32 = SignalProtocol.shared.DEFAULT_DEVICE_ID) throws {
        let address = SignalAddress(name: userId, deviceId: deviceId)
        let sessionBuilder = SessionBuilder(for: address, in: store)
        let sessionPreKeyBuild = SessionPreKeyBundle(registrationId: signalKey.registrationId,
                                                     deviceId: Int32(DEFAULT_DEVICE_ID),
                                                     preKeyId: signalKey.preKey.key_id,
                                                     preKey: signalKey.getPreKeyPublic(),
                                                     signedPreKeyId: UInt32(signalKey.signedPreKey.key_id),
                                                     signedPreKey: signalKey.getSignedPreKeyPublic(),
                                                     signature: signalKey.getSignedSignature(),
                                                     identityKey: signalKey.getIdentityPublic())
        try sessionBuilder.process(preKeyBundle: sessionPreKeyBuild)
    }

    func getSenderKeyDistribution(groupId: String, senderId: String) throws -> CiphertextMessage {
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        let senderKeyData = store.senderKeyStore!.loadSenderKey(for: senderKeyName)
        let builder = GroupSessionBuilder(in: store)
        if (senderKeyData == nil) {
            return try builder.createSession(for: senderKeyName)
        } else {
            return try builder.getDistributionMessage(for: senderKeyName)
        }
    }

    func encryptSenderKey(conversationId: String, recipientId: String) throws -> String {
        let senderKeyDistributionMessage = try getSenderKeyDistribution(groupId: conversationId, senderId: AccountAPI.shared.accountUserId)
        let cipherMessage = try encryptSession(content: senderKeyDistributionMessage.message, destination: recipientId)
        let compose = ComposeMessageData(keyType: cipherMessage.type.rawValue, cipher: cipherMessage.message, resendMessageId: nil)
        return encodeMessageData(data: compose)
    }

    func encryptSessionMessageData(recipientId: String, content: String, resendMessageId: String? = nil) throws -> String {
        let cipher = try encryptSession(content: content.data(using: .utf8)!, destination: recipientId)
        let data = encodeMessageData(data: ComposeMessageData(keyType: cipher.type.rawValue, cipher: cipher.message, resendMessageId: resendMessageId))
        return data
    }

    func encryptTransferSessionMessageData(content: String, sessionId: String, recipientId: String) throws -> String {
        let deviceId = sessionId.hashCode()
        let cipher = try encryptSession(content: content.data(using: .utf8)!, destination: recipientId, deviceId: deviceId)
        let data = encodeMessageData(data: ComposeMessageData(keyType: cipher.type.rawValue, cipher: cipher.message, resendMessageId: nil))
        return data
    }

    func encryptGroupMessageData(conversationId: String, senderId: String, content: String, resendMessageId: String? = nil) throws -> String {
        let senderKeyName = SignalSenderKeyName(groupId: conversationId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        let groupCipher = GroupCipher(for: senderKeyName, in: store)
        var cipher = Data()
        do {
            cipher = try groupCipher.encrypt(content.data(using: .utf8)!).message
        } catch {
            Bugsnag.notifyError(error)
        }
        let data = encodeMessageData(data: ComposeMessageData(keyType: CiphertextMessage.MessageType.senderKey.rawValue, cipher: cipher, resendMessageId: resendMessageId))
        return data
    }

    func decrypt(groupId: String, senderId: String, keyType: UInt8, cipherText: Data, category: String, deviceId: Int32 = SignalProtocol.shared.DEFAULT_DEVICE_ID, callback: @escaping DecryptionCallback) throws {
        let sourceAddress = SignalAddress(name: senderId, deviceId: deviceId)
        let sessionCipher = SessionCipher(for: sourceAddress, in: store)
        if category == MessageCategory.SIGNAL_KEY.rawValue {
            if keyType == CiphertextMessage.MessageType.preKey.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .preKey, message: cipherText), callback: { (plain) in
                    self.processGroupSession(groupId: groupId, sender: sourceAddress, data: plain)
                    callback(plain)
                })

            } else if keyType == CiphertextMessage.MessageType.signal.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .signal, message: cipherText), callback: { (plain) in
                    self.processGroupSession(groupId: groupId, sender: sourceAddress, data: plain)
                    callback(plain)
                })
            }
        } else {
            if keyType == CiphertextMessage.MessageType.preKey.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .preKey, message: cipherText), callback: callback)
            } else if keyType == CiphertextMessage.MessageType.signal.rawValue {
                _ = try sessionCipher.decrypt(message: CiphertextMessage(type: .signal, message: cipherText), callback: callback)
            } else if keyType == CiphertextMessage.MessageType.senderKey.rawValue {
                let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: sourceAddress)
                let groupCipher = GroupCipher(for: senderKeyName, in: store)
                _ = try groupCipher.decrypt(CiphertextMessage(type: .senderKey, message: cipherText), callback: callback)
            }
        }
    }

    private func encryptSession(content: Data, destination: String, deviceId: Int32 = SignalProtocol.shared.DEFAULT_DEVICE_ID) throws -> CiphertextMessage {
        let address = SignalAddress(name: destination, deviceId: deviceId)
        let sessionCipher = SessionCipher(for: address, in: store)
        do {
            return try sessionCipher.encrypt(content)
        } catch {
            if let err = error as? SignalError, err == SignalError.unknownError {
                let sessionId = AccountUserDefault.shared.extensionSession ?? ""
                FileManager.default.writeLog(log: "[SignalProtocol][EncryptSession]...sessionId:\(sessionId)...destination:\(destination)...deviceId:\(deviceId)...containsSession:\(store.sessionStore.containsSession(for: address))")
                _ = store.sessionStore.deleteSession(for: address)
            }
            throw error
        }
    }

    func processGroupSession(groupId: String, sender: SignalAddress, data: Data) {
        let senderKeyDM = CiphertextMessage(type: .distribution, message: data)
        let builder = GroupSessionBuilder(in: store)
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: sender)
        try! builder.process(senderKeyDistributionMessage: senderKeyDM, from: senderKeyName)
    }

    struct ComposeMessageData {
        var keyType: UInt8
        var cipher: Data
        var resendMessageId: String?
    }

    func encodeMessageData(data: ComposeMessageData) -> String {
        if data.resendMessageId == nil {
            let header: [UInt8] = [3, data.keyType, 0, 0, 0, 0, 0, 0]
            let headerData = Data(bytes: header)
            let cipherText = headerData + data.cipher
            return cipherText.base64EncodedString()
        } else {
            let header = [3, data.keyType, 1, 0, 0, 0, 0, 0]
            let messageId = data.resendMessageId!
            let cipherText = Data(bytes: header) + messageId.data(using: .utf8)! + data.cipher
            return cipherText.base64EncodedString()
        }
    }

    func decodeMessageData(encoded: String) -> ComposeMessageData {
        let cipherText = Data(base64Encoded: encoded)!
        let header = cipherText.subdata(in: 0..<8)
        _ = header.bytes[0]
        let dataType = header.bytes[1]
        let isResendMessage = header.bytes[2]
        if (isResendMessage == 1) {
            let messageId = cipherText.subdata(in: 8..<44)
            let data = cipherText.subdata(in: 44..<cipherText.count)
            return ComposeMessageData(keyType: dataType, cipher: data, resendMessageId: messageId.toString())
        } else {
            let data = cipherText.subdata(in: 8..<cipherText.count)
            return ComposeMessageData(keyType: dataType, cipher: data, resendMessageId: nil)
        }
    }

    func setRatchetSenderKeyStatus(groupId: String, senderId: String, status: String) {
        let senderKeyName = SignalSenderKeyName(groupId: groupId, sender: SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID))
        let ratchet = RatchetSenderKey(groupId: senderKeyName.groupId, senderId: senderKeyName.sender.toString(), status: status)
        RatchetSenderKeyDAO.shared.insertOrReplace(obj: ratchet)
    }

    func getRatchetSenderKeyStatus(groupId: String, senderId: String) -> String? {
        let address = SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID)
        let ratchet = RatchetSenderKeyDAO.shared.getRatchetSenderKey(groupId: groupId, senderId: address.toString())
        return ratchet?.status
    }

    func deleteRatchetSenderKey(groupId: String, senderId: String) {
        let address = SignalAddress(name: senderId, deviceId: DEFAULT_DEVICE_ID)
        RatchetSenderKeyDAO.shared.delete(groupId: groupId, senderId: address.toString())
    }

}
