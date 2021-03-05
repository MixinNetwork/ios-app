import Foundation
import MobileCoreServices
import AVFoundation

final class CacheableAssetFileDescription: Codable {
    
    typealias Range = ClosedRange<Int64>
    
    var contentInfo: ContentInformation?
    
    private var availableRanges: [Range]
    
    init(contentInfo: ContentInformation?, availableRanges: [Range]) {
        self.contentInfo = contentInfo
        self.availableRanges = availableRanges
    }
    
    func availableRanges(for range: Range) -> [Range] {
        var intersections: [Range] = []
        for availableRange in availableRanges {
            if let intersection = intersection(availableRange, range) {
                intersections.append(intersection)
            } else if !intersections.isEmpty {
                break
            }
        }
        return intersections
    }
    
    func add(range new: Range) {
        var mergableLowerRangeIndex: Int?
        var mergableUpperRangeIndex: Int?
        var insertableIndex: Int = 0
        for i in 0..<availableRanges.count {
            let range = availableRanges[i]
            if new.lowerBound - 1 == range.upperBound {
                mergableLowerRangeIndex = i
            } else if new.upperBound + 1 == range.lowerBound {
                mergableUpperRangeIndex = i
            } else if new.lowerBound > range.upperBound {
                insertableIndex = i + 1
            }
        }
        
        if let index = mergableLowerRangeIndex, mergableUpperRangeIndex == nil {
            availableRanges[index] = availableRanges[index].lowerBound...new.upperBound
        } else if mergableLowerRangeIndex == nil, let index = mergableUpperRangeIndex {
            availableRanges[index] = new.lowerBound...availableRanges[index].upperBound
        } else if let lowerIndex = mergableLowerRangeIndex, let upperIndex = mergableUpperRangeIndex {
            availableRanges[lowerIndex] = availableRanges[lowerIndex].lowerBound...availableRanges[upperIndex].upperBound
            availableRanges.remove(at: upperIndex)
        } else {
            availableRanges.insert(new, at: insertableIndex)
        }
    }
    
    private func intersection(_ one: Range, _ another: Range) -> Range? {
        let upper = min(one.upperBound, another.upperBound)
        let lower = max(one.lowerBound, another.lowerBound)
        if lower > upper {
            return nil
        } else {
            return lower...upper
        }
    }
    
}

extension CacheableAssetFileDescription {
    
    struct ContentInformation: Codable {
        
        let contentType: String?
        let contentLength: Int64
        let isByteRangeAccessSupported: Bool
        
        init?(response: URLResponse) {
            guard let response = response as? HTTPURLResponse else {
                return nil
            }
            // Before iOS 13.0 Swift treat HTTP header fields as case sensitive
            // Refactor this after deployment targets updates to iOS 13.0
            // https://bugs.swift.org/browse/SR-2429
            let headers = response.allHeaderFields as NSDictionary
            guard let contentRange = headers["Content-Range"] as? String else {
                return nil
            }
            guard let maxRange = contentRange.components(separatedBy: "/").last else {
                return nil
            }
            guard let contentLength = Int64(maxRange) else {
                return nil
            }
            if let mime = response.mimeType {
                let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mime as CFString, nil)
                self.contentType = uti?.takeRetainedValue() as String?
            } else {
                self.contentType = nil
            }
            self.contentLength = contentLength
            if let acceptRanges = headers["Accept-Ranges"] as? String {
                self.isByteRangeAccessSupported = acceptRanges.contains("bytes")
            } else {
                self.isByteRangeAccessSupported = false
            }
        }
        
        func fill(into request: AVAssetResourceLoadingContentInformationRequest) {
            request.contentLength = contentLength
            request.contentType = contentType
            request.isByteRangeAccessSupported = isByteRangeAccessSupported
        }
        
    }
    
}
