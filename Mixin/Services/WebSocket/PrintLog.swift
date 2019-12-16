import Foundation

@_silgen_name("printSignalLog")
public func printSignalLog(message: UnsafePointer<CChar>)
{
    let log = String(cString: message)
    FileManager.default.writeLog(log: log)
}
