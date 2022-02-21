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
                Logger.general.debug(category: "CacheableAssetLoader", message: "Finish loading: \(loadingRequest.opaque) with existed content info")
                return true
            }
        }
        
        if currentRequest != nil {
            pendingRequests.append(loadingRequest)
            Logger.general.debug(category: "CacheableAssetLoader", message: "Add pending request: \(loadingRequest.opaque)")
            return true
        }
        
        do {
            try start(loadingRequest: loadingRequest)
            return true
        } catch Error.requestNothing {
            Logger.general.debug(category: "CacheableAssetLoader", message: "Loading request: \(loadingRequest.opaque) wants nothing")
            return false
        } catch Error.invalidURL {
            Logger.general.debug(category: "CacheableAssetLoader", message: "Refused to load invalid request: \(loadingRequest.request)")
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
            Logger.general.debug(category: "CacheableAssetLoader", message: "Cancelled current request: \(loadingRequest.opaque)")
        } else if let index = pendingRequests.firstIndex(of: loadingRequest) {
            let request = pendingRequests.remove(at: index)
            Logger.general.debug(category: "CacheableAssetLoader", message: "Cancelled pending request: \(request.opaque)")
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
                Logger.general.debug(category: "CacheableAssetLoader", message: "Content info request \(request.opaque) failed for \(error?.localizedDescription ?? "(nil)")")
            } else {
                finishCurrentRequest()
                Logger.general.debug(category: "CacheableAssetLoader", message: "Finish content info request \(request.opaque) from remote")
            }
        } else {
            if fragments.isEmpty {
                Logger.general.debug(category: "CacheableAssetLoader", message: "Finish data request \(request.opaque) from remote")
                finishCurrentRequest()
            } else if let error = error {
                Logger.general.debug(category: "CacheableAssetLoader", message: "Failed to fulfill \(request.opaque) because: \(error)")
                finishCurrentRequest(with: error)
            } else if let response = task.response as? HTTPURLResponse, response.statusCode >= 400 {
                let error = Error.invalidResponseCode(response.statusCode)
                Logger.general.debug(category: "CacheableAssetLoader", message: "Failed to fulfill \(request.opaque) because: \(error)")
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
            Logger.general.debug(category: "CacheableAssetLoader", message: "Got content info, type: \(info.contentType ?? "nil"), length: \(info.contentLength), range: \(info.isByteRangeAccessSupported)")
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
            Logger.general.debug(category: "CacheableAssetLoader", message: "Failed to create content info")
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
        Logger.general.debug(category: "CacheableAssetLoader", message: "Begin receiving data, count: \(data.count)")
        
        let fileOffset: UInt64
        let receivedDataRange: ClosedRange<Int64>
        let fragmentAfterUpdate: Fragment?
        switch fragment {
        case .local:
            Logger.general.debug(category: "CacheableAssetLoader", message: "Requested local fragment")
            return
        case .remote(let fragmentRange):
            Logger.general.debug(category: "CacheableAssetLoader", message: "First fragment: \(fragmentRange.lowerBound)~\(fragmentRange.upperBound)")
            fileOffset = UInt64(fragmentRange.lowerBound)
            receivedDataRange = fragmentRange.lowerBound...(fragmentRange.lowerBound + Int64(data.count) - 1)
            if receivedDataRange.upperBound >= fragmentRange.upperBound {
                fragmentAfterUpdate = nil
            } else {
                fragmentAfterUpdate = .remote((receivedDataRange.upperBound + 1)...fragmentRange.upperBound)
            }
        case .remoteStartFrom(let start):
            Logger.general.debug(category: "CacheableAssetLoader", message: "First fragment: \(start)~")
            fileOffset = UInt64(start)
            receivedDataRange = start...(start + Int64(data.count) - 1)
            if let contentLength = fileDescription.contentInfo?.contentLength, receivedDataRange.upperBound == contentLength - 1 {
                fragmentAfterUpdate = nil
            } else {
                fragmentAfterUpdate = .remoteStartFrom(receivedDataRange.upperBound + 1)
            }
        }
        
        Logger.general.debug(category: "CacheableAssetLoader", message: "Write asset file from: \(fileOffset)")
        do {
            try assetFileHandle.seek(toOffset: fileOffset)
            assetFileHandle.write(data)
            try assetFileHandle.synchronize()
        } catch {
            Logger.general.debug(category: "CacheableAssetLoader", message: "Asset file writing failed for \(error)")
            finishCurrentRequest(with: error)
            return
        }
        Logger.general.debug(category: "CacheableAssetLoader", message: "Update fileDescription with: \(receivedDataRange)")
        fileDescription.add(range: receivedDataRange)
        saveFileDescription()
        Logger.general.debug(category: "CacheableAssetLoader", message: "Update dataRequest with: \(receivedDataRange)")
        dataRequest.respond(with: data)
        
        if let fragment = fragmentAfterUpdate {
            switch fragment {
            case .local:
                Logger.general.debug(category: "CacheableAssetLoader", message: "No way this is happening")
            case .remote(let range):
                Logger.general.debug(category: "CacheableAssetLoader", message: "First fragment is updated to: \(range.lowerBound)~\(range.upperBound)")
            case .remoteStartFrom(let start):
                Logger.general.debug(category: "CacheableAssetLoader", message: "First fragment is updated to: \(start)~")
            }
            fragments[0] = fragment
        } else {
            Logger.general.debug(category: "CacheableAssetLoader", message: "First fragment is fulfilled, remove it")
            fragments.removeFirst()
        }
        
        Logger.general.debug(category: "CacheableAssetLoader", message: "Finished receiving data")
    }
    
}

extension CacheableAssetLoader {
    
    private func saveFileDescription() {
        do {
            let data = try encoder.encode(fileDescription)
            try data.write(to: assetFileDescriptionURL, options: .atomic)
        } catch {
            Logger.general.debug(category: "CacheableAssetLoader", message: "Failed to save asset file description: \(error)")
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
                Logger.general.debug(category: "CacheableAssetLoader", message: "Failed to read local data: \(error)")
                finishCurrentRequest(with: error)
                return
            }
            dataRequest.respond(with: data)
            Logger.general.debug(category: "CacheableAssetLoader", message: "\(data.count) bytes of data is reported to loadingRequest: \(request.opaque)")
            fragments.removeFirst()
            Logger.general.debug(category: "CacheableAssetLoader", message: "Fragment \(fragmentRange.lowerBound)~\(fragmentRange.upperBound) is finish and removed")
            if fragments.isEmpty {
                Logger.general.debug(category: "CacheableAssetLoader", message: "All fragments are loaded & reported. finish loading: \(request.opaque)")
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
            Logger.general.debug(category: "CacheableAssetLoader", message: "Start loading remote data for: \(request.opaque), range: \(fragmentRange)")
        case let .remoteStartFrom(start):
            var urlRequest = URLRequest(url: originalURL)
            urlRequest.setValue("bytes=\(start)-", forHTTPHeaderField: "Range")
            let task = urlSession.dataTask(with: urlRequest)
            currentDataTask = task
            task.resume()
            Logger.general.debug(category: "CacheableAssetLoader", message: "Start loading remote data for: \(request.opaque), start from: \(start)")
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
            Logger.general.debug(category: "CacheableAssetLoader", message: "Begin composing fragments for \(loadingRequest.opaque)")
            var fragments: [Fragment] = []
            
            let requestedRange: ClosedRange<Int64>
            if dataRequest.requestsAllDataToEndOfResource {
                if let contentLength = fileDescription.contentInfo?.contentLength {
                    requestedRange = dataRequest.requestedOffset...(contentLength - 1)
                } else {
                    requestedRange = dataRequest.requestedOffset...Int64.max
                }
                Logger.general.debug(category: "CacheableAssetLoader", message: "Request range: \(dataRequest.requestedOffset)~")
            } else {
                requestedRange = dataRequest.requestedOffset...(dataRequest.requestedOffset + Int64(dataRequest.requestedLength) - 1)
                Logger.general.debug(category: "CacheableAssetLoader", message: "Request range: \(requestedRange.lowerBound)~\(requestedRange.upperBound)")
            }
            
            var localRanges = fileDescription.availableRanges(for: requestedRange)
            if localRanges.isEmpty {
                Logger.general.debug(category: "CacheableAssetLoader", message: "Finds no local fragment")
                if dataRequest.requestsAllDataToEndOfResource {
                    fragments = [.remoteStartFrom(dataRequest.requestedOffset)]
                } else {
                    fragments = [.remote(requestedRange)]
                }
            } else {
                Logger.general.debug(category: "CacheableAssetLoader", message: "Found local fragments:")
                for range in localRanges {
                    Logger.general.debug(category: "CacheableAssetLoader", message: "Fragment: \(range.lowerBound)~\(range.upperBound)")
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
                            Logger.general.debug(category: "CacheableAssetLoader", message: "Inconsistent fragment found")
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
            
            Logger.general.debug(category: "CacheableAssetLoader", message: "Finish composing fragments for \(loadingRequest.opaque)")
            for fragment in fragments {
                switch fragment {
                case .local(let range):
                    Logger.general.debug(category: "CacheableAssetLoader", message: "Local: \(range.lowerBound)~\(range.upperBound)")
                case .remote(let range):
                    Logger.general.debug(category: "CacheableAssetLoader", message: "Remote: \(range.lowerBound)~\(range.upperBound)")
                case .remoteStartFrom(let start):
                    Logger.general.debug(category: "CacheableAssetLoader", message: "Remote: \(start)~")
                }
            }
            
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
            Logger.general.debug(category: "CacheableAssetLoader", message: "Start content info request for: \(loadingRequest.opaque)")
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
