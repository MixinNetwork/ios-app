import Foundation

class PhoneNumberRegexper {
    
    private let regularExpressionPoolQueue = DispatchQueue(label: "com.mixin.messager.PhoneNumberRegexper", target: .global())
    
    private var regularExpressionPool = [String: NSRegularExpression]()
    private var spaceCharacterSet: CharacterSet
    
    init() {
        var characterSet = CharacterSet(charactersIn: PhoneNumberConstants.nonBreakingSpace)
        characterSet.formUnion(.whitespacesAndNewlines)
        spaceCharacterSet = characterSet
    }
    
    func regexMatches(_ pattern: String, string: String) throws -> [NSTextCheckingResult] {
        do {
            return try regexWithPattern(pattern).matches(in: string)
        } catch {
            throw PhoneNumberError.generalError
        }
    }
    
    func phoneDataDetectorMatch(_ string: String) throws -> NSTextCheckingResult {
        let fallBackMatches = try regexMatches(PhoneNumberPatterns.validPhoneNumberPattern, string: string)
        if let firstMatch = fallBackMatches.first {
            return firstMatch
        } else {
            throw PhoneNumberError.notANumber
        }
    }
    
    func matchesAtStart(_ pattern: String, string: String) -> Bool {
        do {
            let matches = try regexMatches(pattern, string: string)
            for match in matches {
                if match.range.location == 0 {
                    return true
                }
            }
        } catch {
            
        }
        return false
    }
    
    func stringPositionByRegex(_ pattern: String, string: String) -> Int {
        do {
            let matches = try regexMatches(pattern, string: string)
            if let match = matches.first {
                return (match.range.location)
            }
            return -1
        } catch {
            return -1
        }
    }
    
    func matchesEntirely(_ pattern: String?, string: String) -> Bool {
        guard var pattern = pattern else {
            return false
        }
        pattern = "^(\(pattern))$"
        do {
            let matches = try regexMatches(pattern, string: string)
            return matches.count > 0
        } catch {
            return false
        }
    }
    
    func replaceStringByRegex(_ pattern: String, string: String, template: String = "") -> String {
        do {
            var replacementResult = string
            let regex = try regexWithPattern(pattern)
            let matches = regex.matches(in: string)
            if matches.count == 1 {
                let range = regex.rangeOfFirstMatch(in: string)
                if range != nil {
                    replacementResult = regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: template)
                }
                return replacementResult
            } else if matches.count > 1 {
                replacementResult = regex.stringByReplacingMatches(in: string, withTemplate: template)
            }
            return replacementResult
        } catch {
            return string
        }
    }
    
    func replaceFirstStringByRegex(_ pattern: String, string: String, templateString: String) -> String {
        do {
            let regex = try regexWithPattern(pattern)
            let range = regex.rangeOfFirstMatch(in: string)
            if range != nil {
                return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: templateString)
            }
            return string
        } catch {
            return String()
        }
    }
    
    func stringByReplacingOccurrences(_ string: String, map: [String: String], keepUnmapped: Bool = false) -> String {
        var targetString = String()
        for i in 0 ..< string.count {
            let oneChar = string[string.index(string.startIndex, offsetBy: i)]
            let keyString = String(oneChar).uppercased()
            if let mappedValue = map[keyString] {
                targetString.append(mappedValue)
            } else if keepUnmapped {
                targetString.append(keyString)
            }
        }
        return targetString
    }
    
    func hasValue(_ value: String?) -> Bool {
        if let valueString = value {
            if valueString.trimmingCharacters(in: spaceCharacterSet).count == 0 {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func testStringLengthAgainstPattern(_ pattern: String, string: String) -> Bool {
        if matchesEntirely(pattern, string: string) {
            return true
        } else {
            return false
        }
    }
    
    private func regexWithPattern(_ pattern: String) throws -> NSRegularExpression {
        var cached: NSRegularExpression?
        cached = regularExpressionPoolQueue.sync {
            regularExpressionPool[pattern]
        }
        if let cached = cached {
            return cached
        }
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            regularExpressionPoolQueue.sync {
                regularExpressionPool[pattern] = regex
            }
            return regex
        } catch {
            throw PhoneNumberError.generalError
        }
    }
    
}
