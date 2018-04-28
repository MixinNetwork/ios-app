import Foundation

extension Encodable {

    func toJSON() -> String {
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(self) {
            return String(data: jsonData, encoding: .utf8) ?? ""
        }
        return ""
    }

}

extension KeyedDecodingContainer  {

    func getCodable<T: Codable>(key: KeyedDecodingContainer.Key, defalutValue: T) -> T {
        return contains(key) ? (try? decode(T.self, forKey: key)) ?? defalutValue : defalutValue
    }

    func getCodable<T: Codable>(key: KeyedDecodingContainer.Key) -> T? {
        return contains(key) ? (try? decode(T.self, forKey: key)) ?? nil : nil
    }

    func getCodableArray<T: Codable>(key: KeyedDecodingContainer.Key) -> [T] {
        return contains(key) ? (try? decode([T].self, forKey: key)) ?? [] : []
    }

    func getString(key: KeyedDecodingContainer.Key) -> String {
        return contains(key) ? (try? decode(String.self, forKey: key)) ?? "" : ""
    }

    func getBool(key: KeyedDecodingContainer.Key) -> Bool {
        return contains(key) ? (try? decode(Bool.self, forKey: key)) ?? false : false
    }

    func getInt(key: KeyedDecodingContainer.Key) -> Int {
        return contains(key) ? (try? decode(Int.self, forKey: key)) ?? 0 : 0
    }

    func getInt64(key: KeyedDecodingContainer.Key) -> Int64 {
        return contains(key) ? (try? decode(Int64.self, forKey: key)) ?? 0 : 0
    }

    func getFloat(key: KeyedDecodingContainer.Key) -> Float {
        return contains(key) ? (try? decode(Float.self, forKey: key)) ?? 0 : 0
    }

    func getDouble(key: KeyedDecodingContainer.Key) -> Double {
        return contains(key) ? (try? decode(Double.self, forKey: key)) ?? 0 : 0
    }

    func getDate(key: KeyedDecodingContainer.Key) -> Date {
        return contains(key) ? (try? decode(Date.self, forKey: key)) ?? Date() : Date()
    }

    func getData(key: KeyedDecodingContainer.Key) -> Data {
        return contains(key) ? (try? decode(Data.self, forKey: key)) ?? Data() : Data()
    }
}

extension String {

    func toModel<T: Codable>() -> T? {
        let decoder = JSONDecoder()
        if let jsonData = self.data(using: .utf8) {
            return try? decoder.decode(T.self, from: jsonData)
        }
        return nil
    }

}

