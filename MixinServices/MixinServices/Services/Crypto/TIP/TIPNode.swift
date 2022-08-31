import Foundation
import Tip
import Alamofire

fileprivate let ephemeralGrace = 128 * UInt64(secondsPerDay) * UInt64(NSEC_PER_SEC)
fileprivate let maximumRetries = 2

public enum TIPNode {
    
    public struct Counter {
        let value: UInt64
        let signer: TIPSigner
    }
    
    enum Error: Swift.Error {
        case bn256SuiteNotAvailable
        case userSkNotAvailable
        case assigneeSkNotAvailable
        case assigneePubNotAvailable
        case signTIPNode(NSError?)
        case decodeResponseSignature
        case decodeResponseCipher
        case decryptResponseCipher
        case notAllSignersSucceed
        case notEnoughPartials
        case recoverSignature(NSError?)
        case watchRetryLimited
        case invalidSignResponse(Int)
        case differentIdentity
        case invalidAssignorData
    }
    
    private struct TIPSignResponseData {
        let partial: Data
        let assignor: String
        let counter: UInt64
    }
    
    private actor Accumulator {
        
        private let maxValue: Int
        
        private var value: Int = 0
        
        init(maxValue: Int) {
            self.maxValue = maxValue
        }
        
        func countAndValidate() -> Bool {
            value += 1
            return value <= maxValue
        }
        
    }
    
#if DEBUG
    public static var failLastSigner = false
#endif
    
    static func sign(
        identityPriv: Data,
        ephemeral: Data,
        watcher: Data,
        assigneePriv: Data?,
        failedSigners: [TIPSigner],
        forRecover: Bool,
        progressHandler: (@MainActor (TIP.Step) -> Void)?
    ) async throws -> Data {
        guard let suite = CryptoNewSuiteBn256() else {
            throw Error.bn256SuiteNotAvailable
        }
        guard let userSk = suite.scalar() else {
            throw Error.userSkNotAvailable
        }
        userSk.setBytes(identityPriv)
        
        let assigneeSk: CryptoScalar?
        let assignee: Data?
        if let priv = assigneePriv {
            guard let sk = suite.scalar() else {
                throw Error.assigneeSkNotAvailable
            }
            sk.setBytes(priv)
            guard let assigneePub = sk.publicKey()?.publicKeyBytes() else {
                throw Error.assigneePubNotAvailable
            }
            let assigneeSig = try sk.sign(assigneePub)
            
            assigneeSk = sk
            assignee = assigneePub + assigneeSig
        } else {
            assigneeSk = nil
            assignee = nil
        }
        
        let data: [TIPSignResponseData]
        let allSigners = TIPConfig.current.signers
        if !failedSigners.isEmpty, let assigneeSk = assigneeSk {
            let successfulSigners = allSigners.filter { signer in
                !failedSigners.contains(signer)
            }
            let successfulData = try await nodeSigs(userSk: assigneeSk, signers: successfulSigners, ephemeral: ephemeral, watcher: watcher, assignee: nil) { step in
                switch step {
                case .creating, .connecting:
                    progressHandler?(step)
                case .synchronizing(let fractionCompleted):
                    let overallFractionCompleted = fractionCompleted * Float(successfulSigners.count) / Float(allSigners.count)
                    progressHandler?(.synchronizing(overallFractionCompleted))
                }
            }
            if successfulData.isEmpty || successfulData.contains(where: { $0.counter <= 1 }) {
                throw Error.differentIdentity
            }
            let failedData = try await nodeSigs(userSk: userSk, signers: failedSigners, ephemeral: ephemeral, watcher: watcher, assignee: assignee) { step in
                switch step {
                case .creating, .connecting:
                    progressHandler?(step)
                case .synchronizing(let fractionCompleted):
                    let overallFractionCompleted = fractionCompleted * Float(failedSigners.count) / Float(allSigners.count)
                    progressHandler?(.synchronizing(overallFractionCompleted))
                }
            }
            data = failedData + successfulData
        } else {
            data = try await nodeSigs(userSk: userSk,
                                      signers: allSigners,
                                      ephemeral: ephemeral,
                                      watcher: watcher,
                                      assignee: assignee,
                                      progressHandler: progressHandler)
        }
        
        if !forRecover && data.count < allSigners.count {
            throw Error.notAllSignersSucceed
        }
        
        let (assignor, partials) = try { () throws -> (Data, [Data]) in
            var acm: [String: Int] = [:]
            var partials: [Data] = []
            for datum in data {
                acm[datum.assignor] = (acm[datum.assignor] ?? 0) + 1
                partials.append(datum.partial)
            }
            var amc = 0
            guard var assignor = Data(hexEncodedString: data[0].assignor) else {
                throw Error.invalidAssignorData
            }
            for (a, c) in acm where c > amc {
                guard let aData = Data(hexEncodedString: a) else {
                    throw Error.invalidAssignorData
                }
                assignor = aData
                amc = c
            }
            return (assignor, partials)
        }()
        if partials.count < TIPConfig.current.commitments.count {
            throw Error.notEnoughPartials
        }
        
        let hexSigs = partials.map({ $0.hexEncodedString() }).joined(separator: ",")
        let commitments = TIPConfig.current.commitments.joined(separator: ",") // TODO: Cache
        
        var error: NSError?
        guard let signature = CryptoRecoverSignature(hexSigs, commitments, assignor, allSigners.count, &error) else {
            throw Error.recoverSignature(error)
        }
        return signature
    }
    
    public static func watch(watcher: Data) async throws -> [TIPNode.Counter] {
        try await withThrowingTaskGroup(of: TIPNode.Counter.self) { group in
            let signers = TIPConfig.current.signers
            for signer in signers {
                group.addTask {
                    let retries = Accumulator(maxValue: maximumRetries)
                    repeat {
                        do {
                            let counter = try await watchTIPNode(signer: signer, watcher: watcher)
                            if counter >= 0 {
                                return Counter(value: counter, signer: signer)
                            }
                        } catch {
                            throw error
                        }
                    } while await retries.countAndValidate()
                    throw Error.watchRetryLimited
                }
            }
            
            var results: [TIPNode.Counter] = []
            results.reserveCapacity(signers.count)
            for try await counter in group {
                results.append(counter)
            }
            return results
        }
    }
    
    private static func watchTIPNode(signer: TIPSigner, watcher: Data) async throws -> UInt64 {
        let request = TIPWatchRequest(watcher: watcher)
        let response = try await TIPAPI.watch(url: signer.api, request: request)
        return response.counter
    }
    
    private static func nodeSigs(
        userSk: CryptoScalar,
        signers: [TIPSigner],
        ephemeral: Data,
        watcher: Data,
        assignee: Data?,
        progressHandler: (@MainActor (TIP.Step) -> Void)?
    ) async throws -> [TIPSignResponseData] {
        let nonce = UInt64(Date().timeIntervalSince1970)
        let grace = ephemeralGrace
        return try await withThrowingTaskGroup(of: TIPSignResponseData.self) { group in
            let retries = Accumulator(maxValue: maximumRetries)
            
            for signer in signers {
                group.addTask {
#if DEBUG
                    if Self.failLastSigner, signer.index == signers.last?.index {
                        throw AFError.sessionTaskFailed(error: URLError(.badServerResponse))
                    }
#endif
                    func sign() async throws -> TIPSignResponseData {
                        try await signTIPNode(userSk: userSk,
                                              signer: signer,
                                              ephemeral: ephemeral,
                                              watcher: watcher,
                                              nonce: nonce,
                                              grace: grace,
                                              assignee: assignee)
                    }
                    
                    do {
                        return try await sign()
                    } catch {
                        if await retries.countAndValidate() {
                            return try await sign()
                        } else {
                            throw error
                        }
                    }
                }
            }
            
            var results: [TIPSignResponseData] = []
            results.reserveCapacity(signers.count)
            for try await data in group {
                results.append(data)
                let fractionCompleted = Float(results.count) / Float(signers.count)
                await progressHandler?(.synchronizing(fractionCompleted))
            }
            return results
        }
    }
    
    private static func signTIPNode(
        userSk: CryptoScalar,
        signer: TIPSigner,
        ephemeral: Data,
        watcher: Data,
        nonce: UInt64,
        grace: UInt64,
        assignee: Data?
    ) async throws -> TIPSignResponseData {
        let request = try TIPSignRequest(userSk: userSk,
                                         signer: signer,
                                         ephemeral: ephemeral,
                                         watcher: watcher,
                                         nonce: nonce,
                                         grace: grace,
                                         assignee: assignee)
        let response = try await TIPAPI.sign(url: signer.api, request: request)
        
        var error: NSError?
        guard let signerPk = CryptoPubKeyFromBase58(signer.identity, &error) else {
            throw Error.signTIPNode(error)
        }
        let msg = try JSONEncoder.default.encode(response.data)
        guard let responseSignature = Data(hexEncodedString: response.signature) else {
            throw Error.decodeResponseSignature
        }
        try signerPk.verify(msg, sig: responseSignature)
        
        guard let responseCipher = Data(hexEncodedString: response.data.cipher) else {
            throw Error.decodeResponseCipher
        }
        guard let plain = CryptoDecrypt(signerPk, userSk, responseCipher) else {
            throw Error.decryptResponseCipher
        }
        guard plain.count == 218 else {
            throw Error.invalidSignResponse(plain.count)
        }
        let partial = plain[8...8+65]
        let assignor = plain[8+66...8+66+127]
        let counter: UInt64 = {
            var raw: UInt64 = 0
            withUnsafeMutableBytes(of: &raw) { counter in
                plain[211...].withUnsafeBytes { plain in
                    plain.copyBytes(to: counter) // Copy bytes to avoid unaligned access
                }
            }
            return UInt64(bigEndian: raw)
        }()
        return TIPSignResponseData(partial: partial,
                                   assignor: assignor.hexEncodedString(),
                                   counter: counter)
    }
    
}
