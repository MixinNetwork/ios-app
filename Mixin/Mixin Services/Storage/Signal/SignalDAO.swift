import WCDBSwift

public class SignalDAO {

    @discardableResult
    public func insertOrReplace<T: BaseCodable>(obj: T) -> Bool {
        return SignalDatabase.shared.insertOrReplace(objects: [obj])
    }

    @discardableResult
    public func insertOrReplace<T: BaseCodable>(objects: [T]) -> Bool {
        return SignalDatabase.shared.insertOrReplace(objects: objects)
    }
    
}
