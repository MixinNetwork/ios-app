import Foundation
import Alamofire
import TIP

fileprivate let ephemeralGrace = 128 * UInt64(secondsPerDay) * UInt64(NSEC_PER_SEC)
fileprivate let maximumRetries: UInt64 = 2

public enum TIPNode {
    
    public struct Counter {
        let value: UInt64
        let signer: TIPSigner
    }
    
    public enum Error: Swift.Error {
        case decodeResponseSignature
        case decodeResponseCipher
        case decryptResponseCipher
        case notAllSignersSucceed(_ numberOfSuccess: Int)
        case notEnoughPartials
        case recoverSignature(NSError?)
        case invalidSignatureSize(Int)
        case watchRetryLimited
        case invalidSignResponse(Int)
        case differentIdentity
        case invalidAssignorData
        case retryLimitExceeded
        case response(TIPNodeResponseError)
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
    ) async throws -> (Data, UInt64) {
        Logger.tip.info(category: "TIPNode", message: "Sign with assigneePriv: \(assigneePriv != nil), failedSigners: \(failedSigners.map(\.index)), forRecover: \(forRecover)")
        
        let userSk = try TIPScalar(seed: identityPriv)
        let assigneeSk: TIPScalar?
        let assignee: Data?
        if let assigneePriv {
            let sk = try TIPScalar(seed: assigneePriv)
            let assigneePub = try sk.publicKey()
            let assigneeSig = try sk.sign(message: assigneePub)
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
        var errors: [TIPNodeResponseError] = []
        for result in results {
            switch result {
            case .success(let datum):
                data.append(datum)
            case .failure(let error):
                if let error = error as? TIPNodeResponseError {
                    errors.append(error)
                }
            }
        }
        
        // When different errors are mixed in response, throw the most critical one
        let fatalErrorIndex = errors.firstIndex(of: .tooManyRequests)
        ?? errors.firstIndex(of: .incorrectPIN)
        ?? errors.firstIndex(of: .internalServer)
        if let index = fatalErrorIndex {
            throw Error.response(errors[index])
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
        let signature = TipRecoverSignature(hexSigs, commitments, assignor, allSigners.count, &error)
        guard let signature, error == nil else {
            throw Error.recoverSignature(error)
        }
        guard signature.count == 64 else {
            let error = Error.invalidSignatureSize(signature.count)
            Logger.tip.error(category: "TIPNode", message: "Invalid signature size \(signature.count)")
            reporter.report(error: error)
            throw error
        }
        let maxCounter = data.map(\.counter).max() ?? data[0].counter
        return (signature, maxCounter)
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
        userSk: TIPScalar,
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
                            if let error = error as? TIPNodeResponseError {
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
                    let fractionCompleted = Float(sigs.count + 1) / Float(signers.count)
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
        userSk: TIPScalar,
        signer: TIPSigner,
        ephemeral: Data,
        watcher: Data,
        nonce: UInt64,
        grace: UInt64,
        assignee: Data?
    ) async throws -> TIPSignResponseData {
        let request = try await TIPSignRequest(
            id: requestID,
            userSk: userSk,
            signer: signer,
            ephemeral: ephemeral,
            watcher: watcher,
            nonce: nonce,
            grace: grace,
            assignee: assignee
        )
        let response = try await TIPAPI.sign(url: signer.apiURL, request: request)
        switch response {
        case .failure(let response):
            throw response.error
        case .success(let response):
            var error: NSError?
            let signerPk = TIPPoint(base58EncodedString: signer.identity)
            let msg = try JSONEncoder.default.encode(response.data)
            guard let responseSignature = Data(hexEncodedString: response.signature) else {
                throw Error.decodeResponseSignature
            }
            try signerPk.verify(message: msg, signature: responseSignature)
            
            guard let responseCipher = Data(hexEncodedString: response.data.cipher) else {
                throw Error.decodeResponseCipher
            }
            let plain = TipDecrypt(
                signer.identity,
                userSk.bytes.hexEncodedString(),
                responseCipher,
                &error
            )
            guard let plain, error == nil else {
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
