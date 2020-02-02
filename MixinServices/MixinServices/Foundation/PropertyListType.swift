import Foundation

public protocol PropertyListType { }

extension Array: PropertyListType where Element: PropertyListType { }
extension Dictionary: PropertyListType where Key: PropertyListType, Value: PropertyListType { }
extension String: PropertyListType { }
extension Data: PropertyListType { }
extension Date: PropertyListType { }
extension NSNumber: PropertyListType { }
extension Int: PropertyListType { }
extension Float: PropertyListType { }
extension Double: PropertyListType { }
extension Bool: PropertyListType { }
