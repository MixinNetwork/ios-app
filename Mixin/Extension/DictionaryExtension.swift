import Foundation

extension Dictionary {

    public subscript(string key: Key) -> String {
        get {
            return self[key] as? String ?? ""
        }
    }

    public subscript(bool key: Key) -> Bool {
        get {
            return self[key] as? Bool ?? false
        }
    }

}

