import Foundation

extension Array {
    
    public func indexSearchingBackwards(where predicate: (Element) throws -> Bool) rethrows -> Int? {
        guard let reversedIndex = try reversed().firstIndex(where: predicate) else {
            return nil
        }
        return index(before: reversedIndex.base)
    }
    
    func safeIndex(before i: Int) -> Int? {
        let index = self.index(before: i)
        return index >= self.startIndex ? index : nil
    }
    
    func safeIndex(after i: Int) -> Int? {
        let index = self.index(after: i)
        return index < self.endIndex ? index : nil
    }
    
    func slices(ofSize size: Int) -> [[Element]] {
        let endIndex = index(startIndex, offsetBy: count)
        return stride(from: startIndex, to: endIndex, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
    
}

extension Array where Iterator.Element: Equatable {
    
    func element(before element: Element) -> Element? {
        guard let index = firstIndex(of: element), let indexBefore = self.safeIndex(before: index) else {
            return nil
        }
        return self[indexBefore]
    }
    
    func element(after element: Element) -> Element? {
        guard let index = firstIndex(of: element) else {
            return nil
        }
        var possibleIndexAfter = self.safeIndex(after: index)
        while let idx = possibleIndexAfter, self[idx] == element {
            possibleIndexAfter = self.safeIndex(after: idx)
        }
        guard let indexAfter = possibleIndexAfter else {
            return nil
        }
        return self[indexAfter]
    }
    
}
