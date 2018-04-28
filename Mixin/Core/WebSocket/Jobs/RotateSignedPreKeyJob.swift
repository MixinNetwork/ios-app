import Foundation

class RotateSignedPreKeyJob: BaseJob {

    override func getJobId() -> String {
        return "rotate-signed-prekey"
    }

    override func run() throws {
        let identityKeyPair = PreKeyUtil.getIdentityKeyPair()
        let signedPreKey = try PreKeyUtil.generateSignedPreKey(identityKeyPair: identityKeyPair)

        let request = SignalKeyRequest(identityKey: identityKeyPair.publicKey.base64EncodedString(),
                                       signedPreKey: SignedPreKeyRequest(signed: signedPreKey),
                                       oneTimePreKeys: nil)
        _ = SignalKeyAPI.shared.pushSignalKeys(key: request)
    }

}
