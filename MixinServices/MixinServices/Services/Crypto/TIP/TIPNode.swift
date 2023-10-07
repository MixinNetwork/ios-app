import Foundation
import Tip
import Alamofire

fileprivate let ephemeralGrace = 128 * UInt64(secondsPerDay) * UInt64(NSEC_PER_SEC)
fileprivate let maximumRetries: UInt64 = 2

public enum TIPNode {
    
    public struct Counter {
        let value: UInt64
        let signer: TIPSigner
    }
    
    public enum Error: Swift.Error {
        case bn256SuiteNotAvailable
        case userSkNotAvailable
        case assigneeSkNotAvailable
        case assigneePubNotAvailable
        case signTIPNode(NSError?)
        case decodeResponseSignature
        case decodeResponseCipher
        case decryptResponseCipher
        case notAllSignersSucceed(_ numberOfSuccess: Int)
        case notEnoughPartials
        case recoverSignature(NSError?)
        case watchRetryLimited
        case invalidSignResponse(Int)
        case differentIdentity
        case invalidAssignorData
        case retryLimitExceeded
        case internalServerError
        case tooManyRequests
        case incorrectPIN
    }
    
    private struct TIPSignResponseData {
        let partial: Data
        let assignor: String
        let counter: UInt64
    }
    
    private actor Accumulator {
        
        private let maxValue: UInt64
        
        private(set) var value: UInt64 = 0
        
        init(maxValue: UInt64) {
            self.maxValue = maxValue
        }
        
        func countAndValidate() -> Bool {
            value += 1
            return value <= maxValue
        }
        
    }
    
    static func sign(
        identityPriv: Data,
        ephemeral: Data,
        watcher: Data,
        assigneePriv: Data?,
        failedSigners: [TIPSigner],
        forRecover: Bool,
        progressHandler: (@MainActor (TIP.Progress) -> Void)?
    ) async throws -> Data {
        Logger.tip.info(category: "TIPNode", message: "Sign with assigneePriv: \(assigneePriv != nil), failedSigners: \(failedSigners.map(\.index)), forRecover: \(forRecover)")
        guard let suite = TipNewSuiteBn256() else {
            throw Error.bn256SuiteNotAvailable
        }
        guard let userSk = suite.scalar() else {
            throw Error.userSkNotAvailable
        }
        userSk.setBytes(identityPriv)
        
        let assigneeSk: TipScalar?
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
        
        let results: [Result<TIPSignResponseData, Swift.Error>]
        let allSigners = TIPConfig.current.signers
        if !failedSigners.isEmpty, let assigneeSk = assigneeSk {
            let successfulSigners = allSigners.filter { signer in
                !failedSigners.contains(signer)
            }
            Logger.tip.info(category: "TIPNode", message: "Successful signers: \(successfulSigners.count)")
            let successfulData = try await nodeSigs(userSk: assigneeSk, signers: successfulSigners, ephemeral: ephemeral, watcher: watcher, assignee: nil) { step in
                switch step {
                case .creating, .connecting:
                    progressHandler?(step)
                case .synchronizing(let fractionCompleted):
                    let overallFractionCompleted = fractionCompleted * Float(successfulSigners.count) / Float(allSigners.count)
                    progressHandler?(.synchronizing(overallFractionCompleted))
                }
            }
            if successfulData.isEmpty || successfulData.compactMap({ try? $0.get() }).contains(where: { $0.counter <= 1 }) {
                throw Error.differentIdentity
            }
            Logger.tip.info(category: "TIPNode", message: "successfulData ready")
            let failedData = try await nodeSigs(userSk: userSk, signers: failedSigners, ephemeral: ephemeral, watcher: watcher, assignee: assignee) { step in
                switch step {
                case .creating, .connecting:
                    progressHandler?(step)
                case .synchronizing(let fractionCompleted):
                    let overallFractionCompleted = (fractionCompleted * Float(failedSigners.count) + Float(successfulSigners.count)) / Float(allSigners.count)
                    progressHandler?(.synchronizing(overallFractionCompleted))
                }
            }
            Logger.tip.info(category: "TIPNode", message: "failedData ready")
            results = failedData + successfulData
        } else {
            results = try await nodeSigs(userSk: userSk,
                                         signers: allSigners,
                                         ephemeral: ephemeral,
                                         watcher: watcher,
                                         assignee: assignee,
                                         progressHandler: progressHandler)
            Logger.tip.info(category: "TIPNode", message: "data ready")
        }
        
        var data: [TIPSignResponseData] = []
        var errorCodes: [Int] = []
        for result in results {
            switch result {
            case .success(let datum):
                data.append(datum)
            case .failure(let error):
                if let error = error as? TIPSignResponse.Failure.Error {
                    errorCodes.append(error.code)
                }
            }
        }
        
        if errorCodes.contains(429) {
            throw Error.tooManyRequests
        } else if errorCodes.contains(403) {
            throw Error.incorrectPIN
        } else if errorCodes.contains(500) {
            throw Error.internalServerError
        }
        
        if !forRecover && data.count < allSigners.count {
            throw Error.notAllSignersSucceed(data.count)
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
        Logger.tip.info(category: "TIPNode", message: "Partials: \(partials.count)")
        if partials.count < TIPConfig.current.commitments.count {
            throw Error.notEnoughPartials
        }
        
        let hexSigs = partials.map({ $0.hexEncodedString() }).joined(separator: ",")
        let commitments = TIPConfig.current.commitments.joined(separator: ",")
        
        var error: NSError?
        guard let signature = TipRecoverSignature(hexSigs, commitments, assignor, allSigners.count, &error) else {
            throw Error.recoverSignature(error)
        }
        return signature
    }
    
    public static func watch(watcher: Data, timeoutInterval: TimeInterval) async throws -> [TIPNode.Counter] {
        try await withThrowingTaskGroup(of: TIPNode.Counter.self) { group in
            let signers = TIPConfig.current.signers
            for signer in signers {
                group.addTask {
                    let retries = Accumulator(maxValue: maximumRetries)
                    repeat {
                        do {
                            let request = TIPWatchRequest(watcher: watcher)
                            Logger.tip.info(category: "TIPNode", message: "Watch node: \(signer.index)")
                            let response = try await TIPAPI.watch(url: signer.apiURL,
                                                                  request: request,
                                                                  timeoutInterval: timeoutInterval)
                            if response.counter >= 0 {
                                return Counter(value: response.counter, signer: signer)
                            } else {
                                Logger.tip.info(category: "TIPNode", message: "Invalid counter: \(response.counter) from node: \(signer.index)")
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
    
    private static func nodeSigs(
        userSk: TipScalar,
        signers: [TIPSigner],
        ephemeral: Data,
        watcher: Data,
        assignee: Data?,
        progressHandler: (@MainActor (TIP.Progress) -> Void)?
    ) async throws -> [Result<TIPSignResponseData, Swift.Error>] {
#if DEBUG
        let nonce: UInt64 = await MainActor.run {
            if TIPDiagnostic.invalidNonceOnce {
                TIPDiagnostic.invalidNonceOnce = false
                return 20
            } else {
                return UInt64(Date().timeIntervalSince1970)
            }
        }
#else
        let nonce = UInt64(Date().timeIntervalSince1970)
#endif
        let grace = ephemeralGrace
        return await withTaskGroup(of: Result<TIPSignResponseData, Swift.Error>.self) { group in
            let retries = Accumulator(maxValue: maximumRetries)
            
            for signer in signers {
                group.addTask {
#if DEBUG
                    do {
                        try await MainActor.run {
                            if TIPDiagnostic.failLastSignerOnce, signer.index == signers.last?.index {
                                TIPDiagnostic.failLastSignerOnce = false
                                throw TIP.Error.mock
                            }
                        }
                    } catch {
                        return .failure(error)
                    }
#endif
                    repeat {
                        let requestID = UUID().uuidString.lowercased()
                        do {
                            let sig = try await signTIPNode(requestID: requestID,
                                                            userSk: userSk,
                                                            signer: signer,
                                                            ephemeral: ephemeral,
                                                            watcher: watcher,
                                                            nonce: nonce + retries.value,
                                                            grace: grace,
                                                            assignee: assignee)
                            Logger.tip.info(category: "TIPNode", message: "Node \(signer.index) sign succeed")
                            return .success(sig)
                        } catch {
                            if let error = error as? TIPSignResponse.Failure.Error {
                                Logger.tip.error(category: "TIPNode", message: "Node \(signer.index) sign failed with status code: \(error.code), id: \(requestID)")
                                if error.isFatal {
                                    return .failure(error)
                                } else {
                                    continue
                                }
                            } else {
                                Logger.tip.error(category: "TIPNode", message: "Node \(signer.index) sign failed with: \(error), id: \(requestID)")
                                continue
                            }
                        }
                    } while await retries.countAndValidate()
                    return .failure(Error.retryLimitExceeded)
                }
            }
            
            var sigs: [Result<TIPSignResponseData, Swift.Error>] = []
            sigs.reserveCapacity(signers.count)
            for await result in group {
                switch result {
                case .success(let sig):
                    let fractionCompleted = Float(sigs.count) / Float(signers.count)
                    await progressHandler?(.synchronizing(fractionCompleted))
                case .failure(let error):
                    Logger.tip.error(category: "TIPNode", message: "Failed to sign: \(error)")
                }
                sigs.append(result)
            }
            return sigs
        }
    }
    
    private static func signTIPNode(
        requestID: String,
        userSk: TipScalar,
        signer: TIPSigner,
        ephemeral: Data,
        watcher: Data,
        nonce: UInt64,
        grace: UInt64,
        assignee: Data?
    ) async throws -> TIPSignResponseData {
        let request = try TIPSignRequest(id: requestID,
                                         userSk: userSk,
                                         signer: signer,
                                         ephemeral: ephemeral,
                                         watcher: watcher,
                                         nonce: nonce,
                                         grace: grace,
                                         assignee: assignee)
        let response = try await TIPAPI.sign(url: signer.apiURL, request: request)
        switch response {
        case .failure(let response):
            throw response.error
        case .success(let response):
            var error: NSError?
            guard let signerPk = TipPubKeyFromBase58(signer.identity, &error) else {
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
            guard let plain = TipDecrypt(signerPk, userSk, responseCipher) else {
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
    
}
