//
//  PrintLog.swift
//  Mixin
//
//  Created by crossle on 27/3/2018.
//  Copyright © 2018 Mixin. All rights reserved.
//

import Foundation

@_silgen_name("printSignalLog")
public func printSignalLog(message: UnsafePointer<CChar>)
{
    let log = String(cString: message)
    FileManager.default.writeLog(log: log)
}
