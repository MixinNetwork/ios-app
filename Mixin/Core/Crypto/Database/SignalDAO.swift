import WCDBSwift

class SignalDAO {

    @discardableResult
    func insertOrReplace<T: BaseCodable>(obj: T) -> Bool {
        return SignalDatabase.shared.insertOrReplace(objects: [obj])
    }

    @discardableResult
    func insertOrReplace<T: BaseCodable>(objects: [T]) -> Bool {
        return SignalDatabase.shared.insertOrReplace(objects: objects)
    }
    
}
