import Foundation
import GRDB

class MixinTokenizer: FTS5WrapperTokenizer {
    
    private enum CharType {
        case asciiDigits
        case grouping // e.g. English letters, Cyrillic letters
        case nonGrouping // e.g. CJK characters, characters in Plane1 and Plane2
    }
    
    private struct FTS5WrapperContext {
        let tokenizer: FTS5WrapperTokenizer
        let context: UnsafeMutableRawPointer?
        let tokenization: FTS5Tokenization
        let tokenCallback: FTS5TokenCallback
    }
    
    static let name = "mixin"
    
    let wrappedTokenizer: FTS5Tokenizer
    
    private let isDebugging = false
    
    required init(db: GRDB.Database, arguments: [String]) throws {
        let components = [
            "unicode61",
            "remove_diacritics", "2",
            // ⚠️ Reorder these categories may end up with malfunctioned tokenizing on ascii chars.
            // Don't quite know the reason, maybe a bug of SQLite, whatever just keep the order as
            // same as what was in sqlite3Fts5UnicodeCatParse. Confirmed with SQLCipher 4.4.2
            "categories", "'Co L* N* S*'"
        ]
        let descriptor = FTS5TokenizerDescriptor(components: components)
        wrappedTokenizer = try db.makeTokenizer(descriptor)
    }
    
    func accept(
        token: String,
        flags: FTS5TokenFlags,
        for tokenization: FTS5Tokenization,
        tokenCallback: (String, FTS5TokenFlags) throws -> Void
    ) throws {
        guard !token.isEmpty else {
            return
        }
        var index = token.startIndex
        var groupingBuffer: [Character] = []
        var groupingType: CharType = .asciiDigits
        
        func reportAndClearGroupingBufferIfNotEmpty() throws {
            guard !groupingBuffer.isEmpty else {
                return
            }
            let subtoken = String(groupingBuffer)
            if isDebugging {
                print("Reporting group: \(subtoken)")
            }
            try tokenCallback(subtoken, [])
            groupingBuffer = []
        }
        
        while index < token.endIndex {
            let char = token[index]
            let charType: CharType
            if let value = char.asciiValue {
                if 0x30...0x39 ~= value {
                    charType = .asciiDigits
                } else {
                    // This is OK since punctuations and control codes are
                    // not recognized as token by unicode61 tokenizer
                    charType = .grouping
                }
            } else {
                let firstUnicodeScalar = char.unicodeScalars[char.unicodeScalars.startIndex]
                let firstCodepoint = firstUnicodeScalar.value
                let needsSplitting = 0x2E80...0xA4CF ~= firstCodepoint // CJK
                    || 0x0E00...0x0E7F ~= firstCodepoint // Thai
                    || 0x0E80...0x0EFF ~= firstCodepoint // Lao
                    || 0x0F00...0x0FFF ~= firstCodepoint // Tibetan
                    || 0x1000...0x109F ~= firstCodepoint // Myanmar
                    || 0x1780...0x17FF ~= firstCodepoint // Khmer
                    || 0x1100...0x11FF ~= firstCodepoint // Hangul Jamo
                    || 0xA900...0xA92F ~= firstCodepoint // Kayah Li
                    || 0xA930...0xA95F ~= firstCodepoint // Rejang
                    || 0xA960...0xA97F ~= firstCodepoint // Hangul Jamo Extended-A
                    || 0xA9E0...0xA9FF ~= firstCodepoint // Myanmar Extended-B
                    || 0xAA60...0xAA7F ~= firstCodepoint // Myanmar Extended-A
                    || 0xAC00...0xD7AF ~= firstCodepoint // Hangul Syllables
                    || 0xD7B0...0xD7FF ~= firstCodepoint // Hangul Jamo Extended-B
                    || 0xF900...0xFAFF ~= firstCodepoint // CJK Compatibility Ideographs
                    || 0xFE30...0xFE4F ~= firstCodepoint // CJK Compatibility Forms
                    || firstUnicodeScalar.properties.isEmoji
                charType = needsSplitting ? .nonGrouping : .grouping
            }
            if charType != groupingType {
                try reportAndClearGroupingBufferIfNotEmpty()
                groupingType = charType
            }
            switch charType {
            case .asciiDigits, .grouping:
                groupingBuffer.append(char)
            case .nonGrouping:
                if isDebugging {
                    print("Reporting char: \(char)")
                }
                try tokenCallback(String(char), [])
            }
            index = token.index(after: index)
        }
        
        try reportAndClearGroupingBufferIfNotEmpty()
    }
    
}
