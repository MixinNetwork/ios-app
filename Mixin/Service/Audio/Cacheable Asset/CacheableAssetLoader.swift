import Foundation
import AVFoundation
import MixinServices

final class CacheableAssetLoader: NSObject {
    
    enum Error: Swift.Error {
        case missingAssetFile
        case missingContentInfo(Swift.Error?)
        case readsNothing
        case invalidURL
        case requestNothing
        case invalidResponseCode(Int)
    }
    
    private enum Fragment {
        case local(ClosedRange<Int64>)
        case remote(ClosedRange<Int64>)
        case remoteStartFrom(Int64)
    }
    
    let id: String
    let queue: DispatchQueue
    let fileDescription: CacheableAssetFileDescription
    let assetFileHandle: FileHandle
    let assetFileDescriptionURL: URL
    
    private let isDebugging = false
    private let decoder = PropertyListDecoder()
    private let encoder = PropertyListEncoder()
    
    private lazy var urlSession: URLSession = {
        let operationQueue = OperationQueue(maxConcurrentOperationCount: 1)
        operationQueue.underlyingQueue = queue
        let session = URLSession(configuration: .default,
                                 delegate: self,
                                 delegateQueue: operationQueue)
        urlSessionIfLoaded = session
        return session
    }()
    
    private weak var urlSessionIfLoaded: URLSession?
    
    private var currentRequest: AVAssetResourceLoadingRequest?
    private var currentDataTask: URLSessionDataTask?
    private var fragments: [Fragment] = []
    
    private var pendingRequests: [AVAssetResourceLoadingRequest] = []
    
    init(id: String) throws {
        let pack = try CacheableAssetFileManager.shared.filePack(for: id)
        let assetFileHandle = try FileHandle(forUpdating: pack.assetURL)
        
        let fileDescription: CacheableAssetFileDescription
        let isFileDescriptionNewlyCreated: Bool
        do {
            if pack.isAssetFileNewlyCreated {
                throw Error.missingAssetFile
            }
            let data = try Data(contentsOf: pack.fileDescriptionURL)
            fileDescription = try decoder.decode(CacheableAssetFileDescription.self, from: data)
            isFileDescriptionNewlyCreated = false
        } catch {
            fileDescription = CacheableAssetFileDescription(contentInfo: nil, availableRanges: [])
            isFileDescriptionNewlyCreated = true
        }
        
        self.id = id
        self.queue = DispatchQueue(label: "one.mixin.messenger.CacheableAssetLoader-\(id)")
        self.fileDescription = fileDescription
        self.assetFileHandle = assetFileHandle
        self.assetFileDescriptionURL = pack.fileDescriptionURL
        
        super.init()
        
        if isFileDescriptionNewlyCreated {
            saveFileDescription()
        }
    }
    
    func invalidate() {
        urlSessionIfLoaded?.invalidateAndCancel()
    }
    
}

extension CacheableAssetLoader: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let request = loadingRequest.contentInformationRequest, let info = fileDescription.contentInfo {
            info.fill(into: request)
            if loadingRequest.dataRequest == nil {
                loadingRequest.finishLoading()
                debugInfo("[CacheableAssetLoader] ✅ Finish loading: \(loadingRequest.opaque) with existed content info")
                return true
            }
        }
        
        if currentRequest != nil {
            pendingRequests.append(loadingRequest)
            debugInfo("[CacheableAssetLoader] 🕒 Add pending request: \(loadingRequest.opaque)")
            return true
        }
        
        do {
            try start(loadingRequest: loadingRequest)
            return true
        } catch Error.requestNothing {
            debugInfo("[CacheableAssetLoader] ❓ Loading request: \(loadingRequest.opaque) wants nothing")
            return false
        } catch Error.invalidURL {
            debugInfo("[CacheableAssetLoader] ❌ Refused to load invalid request: \(loadingRequest.request)")
            return false
        } catch {
            return false
        }
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        if loadingRequest == currentRequest {
            currentRequest = nil
            currentDataTask?.cancel()
            currentDataTask = nil
            fragments = []
            debugInfo("[CacheableAssetLoader] 👋 Cancelled current request: \(loadingRequest.opaque)")
        } else if let index = pendingRequests.firstIndex(of: loadingRequest) {
            let request = pendingRequests.remove(at: index)
            debugInfo("[CacheableAssetLoader] 👋 Cancelled pending request: \(request.opaque)")
        }
    }
    
}

extension CacheableAssetLoader: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?) {
        guard let request = currentRequest, task == currentDataTask else {
            return
        }
        if request.dataRequest == nil {
            if fileDescription.contentInfo == nil {
                finishCurrentRequest(with: Error.missingContentInfo(error))
                debugInfo("[CacheableAssetLoader] ❌ Content info request \(request.opaque) failed for \(error?.localizedDescription ?? "(nil)")")
            } else {
                finishCurrentRequest()
                debugInfo("[CacheableAssetLoader] ✅ Finish content info request \(request.opaque) from remote")
            }
        } else {
            if fragments.isEmpty {
                debugInfo("[CacheableAssetLoader] ✅ Finish data request \(request.opaque) from remote")
                finishCurrentRequest()
            } else if let error = error {
                debugInfo("[CacheableAssetLoader] ❌ Failed to fulfill \(request.opaque) because: \(error)")
                finishCurrentRequest(with: error)
            } else if let response = task.response as? HTTPURLResponse, response.statusCode >= 400 {
                let error = Error.invalidResponseCode(response.statusCode)
                debugInfo("[CacheableAssetLoader] ❌ Failed to fulfill \(request.opaque) because: \(error)")
                finishCurrentRequest(with: error)
            } else {
                loadNextFragment()
            }
        }
    }
    
}

extension CacheableAssetLoader: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let request = currentRequest, dataTask == currentDataTask else {
            completionHandler(.cancel)
            return
        }
        if let info = CacheableAssetFileDescription.ContentInformation(response: response) {
            debugInfo("[CacheableAssetLoader] ✅ Got content info, type: \(info.contentType ?? "nil"), length: \(info.contentLength), range: \(info.isByteRangeAccessSupported)")
            fileDescription.contentInfo = info
            saveFileDescription()
            if let infoRequest = request.contentInformationRequest {
                info.fill(into: infoRequest)
            }
            if request.dataRequest == nil {
                // currentRequest will finishLoading in didCompleteWithError
                completionHandler(.cancel)
                return
            }
        } else {
            debugInfo("[CacheableAssetLoader] ❌ Failed to create content info")
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let request = currentRequest, dataTask == currentDataTask else {
            return
        }
        guard let dataRequest = request.dataRequest, let fragment = fragments.first else {
            return
        }
        debugInfo("\n[CacheableAssetLoader] ℹ️ Begin receiving data, count: \(data.count)")
        
        let fileOffset: UInt64
        let receivedDataRange: ClosedRange<Int64>
        let fragmentAfterUpdate: Fragment?
        switch fragment {
        case .local:
            debugInfo("[CacheableAssetLoader] ❓ Requested local fragment")
            return
        case .remote(let fragmentRange):
            debugInfo("[CacheableAssetLoader] ℹ️ first fragment: \(fragmentRange.lowerBound)~\(fragmentRange.upperBound)")
            fileOffset = UInt64(fragmentRange.lowerBound)
            receivedDataRange = fragmentRange.lowerBound...(fragmentRange.lowerBound + Int64(data.count) - 1)
            if receivedDataRange.upperBound >= fragmentRange.upperBound {
                fragmentAfterUpdate = nil
            } else {
                fragmentAfterUpdate = .remote((receivedDataRange.upperBound + 1)...fragmentRange.upperBound)
            }
        case .remoteStartFrom(let start):
            debugInfo("[CacheableAssetLoader] ℹ️ first fragment: \(start)~")
            fileOffset = UInt64(start)
            receivedDataRange = start...(start + Int64(data.count) - 1)
            if let contentLength = fileDescription.contentInfo?.contentLength, receivedDataRange.upperBound == contentLength - 1 {
                fragmentAfterUpdate = nil
            } else {
                fragmentAfterUpdate = .remoteStartFrom(receivedDataRange.upperBound + 1)
            }
        }
        
        debugInfo("[CacheableAssetLoader] ℹ️ write asset file from: \(fileOffset)")
        if #available(iOS 13.0, *) {
            do {
                try assetFileHandle.seek(toOffset: fileOffset)
                assetFileHandle.write(data)
                try assetFileHandle.synchronize()
            } catch {
                debugInfo("[CacheableAssetLoader] ❌ Asset file writing failed for \(error)")
                finishCurrentRequest(with: error)
                return
            }
        } else {
            assetFileHandle.seek(toFileOffset: fileOffset)
            assetFileHandle.write(data)
            assetFileHandle.synchronizeFile()
        }
        debugInfo("[CacheableAssetLoader] ℹ️ Update fileDescription with: \(receivedDataRange)")
        fileDescription.add(range: receivedDataRange)
        saveFileDescription()
        debugInfo("[CacheableAssetLoader] ℹ️ Update dataRequest with: \(receivedDataRange)")
        dataRequest.respond(with: data)
        
        if let fragment = fragmentAfterUpdate {
            switch fragment {
            case .local:
                debugInfo("[CacheableAssetLoader] ❌ No way this is happening")
            case .remote(let range):
                debugInfo("[CacheableAssetLoader] ℹ️ first fragment is updated to: \(range.lowerBound)~\(range.upperBound)")
            case .remoteStartFrom(let start):
                debugInfo("[CacheableAssetLoader] ℹ️ first fragment is updated to: \(start)~")
            }
            fragments[0] = fragment
        } else {
            debugInfo("[CacheableAssetLoader] ℹ️ first fragment is fulfilled, remove it")
            fragments.removeFirst()
        }
        
        debugInfo("[CacheableAssetLoader] ℹ️ Finished receiving data\n")
    }
    
}

extension CacheableAssetLoader {
    
    @inline(__always)
    private func debugInfo(_ item: Any) {
        if isDebugging {
            print(item)
        }
    }
    
    private func saveFileDescription() {
        do {
            let data = try encoder.encode(fileDescription)
            try data.write(to: assetFileDescriptionURL, options: .atomic)
        } catch {
            debugInfo("[CacheableAssetLoader] ❌ Failed to save asset file description: \(error)")
            reporter.report(error: error)
        }
    }
    
    private func loadNextFragment() {
        guard let request = currentRequest, let dataRequest = request.dataRequest else {
            return
        }
        guard let cacheableURL = request.request.url, let originalURL = CacheableAsset.URLConverter.originalURL(from: cacheableURL) else {
            return
        }
        guard let fragment = fragments.first else {
            return
        }
        switch fragment {
        case let .local(fragmentRange):
            let offset = UInt64(fragmentRange.lowerBound)
            let length = Int(fragmentRange.upperBound - fragmentRange.lowerBound + 1)
            let data: Data
            if #available(iOS 13.0, *) {
                do {
                    try assetFileHandle.seek(toOffset: offset)
                    if #available(iOS 13.4, *) {
                        if let d = try assetFileHandle.read(upToCount: length) {
                            data = d
                        } else {
                            throw Error.readsNothing
                        }
                    } else {
                        data = assetFileHandle.readData(ofLength: length)
                    }
                } catch {
                    debugInfo("[CacheableAssetLoader] ❌ Failed to read local data: \(error)")
                    finishCurrentRequest(with: error)
                    return
                }
            } else {
                assetFileHandle.seek(toFileOffset: offset)
                data = assetFileHandle.readData(ofLength: length)
            }
            dataRequest.respond(with: data)
            debugInfo("[CacheableAssetLoader] ✅ \(data.count) bytes of data is reported to loadingRequest: \(request.opaque)")
            fragments.removeFirst()
            debugInfo("[CacheableAssetLoader] ℹ️ fragment \(fragmentRange.lowerBound)~\(fragmentRange.upperBound) is finish and removed")
            if fragments.isEmpty {
                debugInfo("[CacheableAssetLoader] ✅ All fragments are loaded & reported. finish loading: \(request.opaque)")
                finishCurrentRequest()
            } else {
                queue.async(execute: loadNextFragment)
            }
        case let .remote(fragmentRange):
            var urlRequest = URLRequest(url: originalURL)
            urlRequest.setValue("bytes=\(fragmentRange.lowerBound)-\(fragmentRange.upperBound)", forHTTPHeaderField: "Range")
            let task = urlSession.dataTask(with: urlRequest)
            currentDataTask = task
            task.resume()
            debugInfo("[CacheableAssetLoader] 🕒 Start loading remote data for: \(request.opaque), range: \(fragmentRange)")
        case let .remoteStartFrom(start):
            var urlRequest = URLRequest(url: originalURL)
            urlRequest.setValue("bytes=\(start)-", forHTTPHeaderField: "Range")
            let task = urlSession.dataTask(with: urlRequest)
            currentDataTask = task
            task.resume()
            debugInfo("[CacheableAssetLoader] 🕒 Start loading remote data for: \(request.opaque), start from: \(start)")
        }
    }
    
    private func start(loadingRequest: AVAssetResourceLoadingRequest) throws {
        guard let cacheableURL = loadingRequest.request.url, let originalURL = CacheableAsset.URLConverter.originalURL(from: cacheableURL) else {
            throw Error.invalidURL
        }
        guard loadingRequest.dataRequest != nil || loadingRequest.contentInformationRequest != nil else {
            throw Error.requestNothing
        }
        if let dataRequest = loadingRequest.dataRequest {
            debugInfo("\n[CacheableAssetLoader] ℹ️ Begin composing fragments for \(loadingRequest.opaque)")
            var fragments: [Fragment] = []
            
            let requestedRange: ClosedRange<Int64>
            if dataRequest.requestsAllDataToEndOfResource {
                if let contentLength = fileDescription.contentInfo?.contentLength {
                    requestedRange = dataRequest.requestedOffset...(contentLength - 1)
                } else {
                    requestedRange = dataRequest.requestedOffset...Int64.max
                }
                debugInfo("[CacheableAssetLoader] ℹ️ Request range: \(dataRequest.requestedOffset)~")
            } else {
                requestedRange = dataRequest.requestedOffset...(dataRequest.requestedOffset + Int64(dataRequest.requestedLength) - 1)
                debugInfo("[CacheableAssetLoader] ℹ️ Request range: \(requestedRange.lowerBound)~\(requestedRange.upperBound)")
            }
            
            var localRanges = fileDescription.availableRanges(for: requestedRange)
            if localRanges.isEmpty {
                debugInfo("[CacheableAssetLoader] ℹ️ Finds no local fragment")
                if dataRequest.requestsAllDataToEndOfResource {
                    fragments = [.remoteStartFrom(dataRequest.requestedOffset)]
                } else {
                    fragments = [.remote(requestedRange)]
                }
            } else {
                debugInfo("[CacheableAssetLoader] ℹ️ Found local fragments:")
                for range in localRanges {
                    debugInfo("\(range.lowerBound)~\(range.upperBound)")
                }
                while !localRanges.isEmpty {
                    let localRange = localRanges.removeFirst()
                    if let lastFragment = fragments.last {
                        switch lastFragment {
                        case let .local(lastFragmentRange):
                            if (localRange.lowerBound - lastFragmentRange.upperBound) > 1 {
                                fragments.append(.remote((lastFragmentRange.upperBound + 1)...(localRange.lowerBound - 1)))
                            }
                        case .remote, .remoteStartFrom:
                            debugInfo("[CacheableAssetLoader] ❌ Inconsistent fragment found")
                        }
                        fragments.append(.local(localRange))
                    } else {
                        if localRange.lowerBound > requestedRange.lowerBound {
                            fragments.append(.remote(requestedRange.lowerBound...(localRange.lowerBound - 1)))
                        }
                        fragments.append(.local(localRange))
                    }
                }
                if let lastFragment = fragments.last, case let .local(lastLocalRange) = lastFragment, requestedRange.upperBound > lastLocalRange.upperBound {
                    if dataRequest.requestsAllDataToEndOfResource {
                        fragments.append(.remoteStartFrom(lastLocalRange.upperBound + 1))
                    } else {
                        fragments.append(.remote((lastLocalRange.upperBound + 1)...requestedRange.upperBound))
                    }
                }
            }
            
            debugInfo("[CacheableAssetLoader] ℹ️ Finish composing fragments for \(loadingRequest.opaque)")
            for fragment in fragments {
                switch fragment {
                case .local(let range):
                    debugInfo("Local: \(range.lowerBound)~\(range.upperBound)")
                case .remote(let range):
                    debugInfo("Remote: \(range.lowerBound)~\(range.upperBound)")
                case .remoteStartFrom(let start):
                    debugInfo("Remote: \(start)~")
                }
            }
            debugInfo("")
            
            self.currentRequest = loadingRequest
            self.fragments = fragments
            self.currentDataTask = nil
            
            loadNextFragment()
        } else if loadingRequest.contentInformationRequest != nil  {
            var request = URLRequest(url: originalURL)
            request.setValue("bytes=0-1", forHTTPHeaderField: "Range")
            let task = urlSession.dataTask(with: request)
            
            self.currentRequest = loadingRequest
            self.fragments = []
            self.currentDataTask = task
            
            task.resume()
            debugInfo("[CacheableAssetLoader] 🕒 Start content info request for: \(loadingRequest.opaque)")
        }
    }
    
    private func startNextPendingRequest() {
        guard !pendingRequests.isEmpty else {
            return
        }
        let request = pendingRequests.removeFirst()
        do {
            try start(loadingRequest: request)
        } catch {
            finishCurrentRequest(with: error)
        }
    }
    
    private func finishCurrentRequest(with error: Swift.Error? = nil) {
        if let error = error {
            currentRequest?.finishLoading(with: error)
        } else {
            currentRequest?.finishLoading()
        }
        currentRequest = nil
        currentDataTask?.cancel()
        currentDataTask = nil
        fragments = []
        queue.async(execute: startNextPendingRequest)
    }
    
}

fileprivate extension AVAssetResourceLoadingRequest {
    
    // For debugging only
    var opaque: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }
    
}
