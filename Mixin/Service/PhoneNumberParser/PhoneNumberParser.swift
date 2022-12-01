import Contacts

class PhoneNumberParser {
    
    let dataSource = PhoneNumberDataSource()
    
    private let regexper = PhoneNumberRegexper()
    
    func parse(_ numberString: String, withRegion region: String = CNContactsUserDefaults.shared().countryCode) throws -> PhoneNumber {
        var numberStringWithPlus = numberString
        do {
            return try parse(numberString, withRegion: region, ignoreType: false)
        } catch {
            if numberStringWithPlus.first != "+" {
                numberStringWithPlus = "+" + numberStringWithPlus
            }
        }
        return try parse(numberStringWithPlus, withRegion: region, ignoreType: false)
    }
    
    func format(_ phoneNumber: PhoneNumber, toType formatType: PhoneNumberFormat, withPrefix prefix: Bool = true) -> String {
        if formatType == .e164 {
            let formattedNationalNumber = phoneNumber.adjustedNationalNumber()
            if prefix == false {
                return formattedNationalNumber
            }
            return "+\(phoneNumber.countryCode)\(formattedNationalNumber)"
        } else {
            var formattedNationalNumber = phoneNumber.adjustedNationalNumber()
            if let regionMetadata = dataSource.mainTerritory(forCode: phoneNumber.countryCode) {
                var selectedFormat: MetadataPhoneNumberFormat?
                for format in regionMetadata.numberFormats {
                    if let leadingDigitPattern = format.leadingDigitsPatterns?.last {
                        if regexper.stringPositionByRegex(leadingDigitPattern, string: String(formattedNationalNumber)) == 0 {
                            if regexper.matchesEntirely(format.pattern, string: String(formattedNationalNumber)) {
                                selectedFormat = format
                                break
                            }
                        }
                    } else {
                        if regexper.matchesEntirely(format.pattern, string: String(formattedNationalNumber)) {
                            selectedFormat = format
                            break
                        }
                    }
                }
                if let selectedFormat,
                   let numberFormatRule = (formatType == PhoneNumberFormat.international && selectedFormat.intlFormat != nil) ? selectedFormat.intlFormat : selectedFormat.format,
                   let pattern = selectedFormat.pattern {
                    var prefixFormattingRule = String()
                    if let nationalPrefixFormattingRule = selectedFormat.nationalPrefixFormattingRule, let nationalPrefix = regionMetadata.nationalPrefix {
                        prefixFormattingRule = regexper.replaceStringByRegex(PhoneNumberPatterns.npPattern, string: nationalPrefixFormattingRule, template: nationalPrefix)
                        prefixFormattingRule = regexper.replaceStringByRegex(PhoneNumberPatterns.fgPattern, string: prefixFormattingRule, template: "\\$1")
                    }
                    if formatType == PhoneNumberFormat.national, regexper.hasValue(prefixFormattingRule) {
                        let replacePattern = regexper.replaceFirstStringByRegex(PhoneNumberPatterns.firstGroupPattern, string: numberFormatRule, templateString: prefixFormattingRule)
                        formattedNationalNumber = regexper.replaceStringByRegex(pattern, string: formattedNationalNumber, template: replacePattern)
                    } else {
                        formattedNationalNumber = regexper.replaceStringByRegex(pattern, string: formattedNationalNumber, template: numberFormatRule)
                    }
                }
                if let numberExtension = phoneNumber.numberExtension {
                    let formattedExtension: String
                    if let preferredExtnPrefix = regionMetadata.preferredExtnPrefix {
                        formattedExtension = "\(preferredExtnPrefix)\(numberExtension)"
                    } else {
                        formattedExtension = "\(PhoneNumberConstants.defaultExtnPrefix)\(numberExtension)"
                    }
                    formattedNationalNumber = formattedNationalNumber + formattedExtension
                }
            }
            if formatType == .international, prefix == true {
                return "+\(phoneNumber.countryCode) \(formattedNationalNumber)"
            } else {
                return formattedNationalNumber
            }
        }
    }
    
}

extension PhoneNumberParser {
    
    private func normalizePhoneNumber(_ number: String) -> String {
        let normalizationMappings = PhoneNumberPatterns.allNormalizationMappings
        return regexper.stringByReplacingOccurrences(number, map: normalizationMappings)
    }
    
    private func isNumberMatchingDesc(_ nationalNumber: String, numberDesc: MetadataPhoneNumberDesc?) -> Bool {
        regexper.matchesEntirely(numberDesc?.nationalNumberPattern, string: nationalNumber)
    }
    
    private func stripNationalPrefix(_ number: inout String, metadata: MetadataPhoneNumberTerritory) {
        guard let possibleNationalPrefix = metadata.nationalPrefixForParsing else {
            return
        }
        let prefixPattern = "^(?:\(possibleNationalPrefix))"
        do {
            let matches = try regexper.regexMatches(prefixPattern, string: number)
            if let firstMatch = matches.first {
                let nationalNumberRule = metadata.generalDesc?.nationalNumberPattern
                let firstMatchString = number.substring(with: firstMatch.range)
                let numOfGroups = firstMatch.numberOfRanges - 1
                var transformedNumber: String = String()
                let firstRange = firstMatch.range(at: numOfGroups)
                let firstMatchStringWithGroup = (firstRange.location != NSNotFound && firstRange.location < number.count) ? number.substring(with: firstRange) : String()
                let firstMatchStringWithGroupHasValue = regexper.hasValue(firstMatchStringWithGroup)
                if let transformRule = metadata.nationalPrefixTransformRule, firstMatchStringWithGroupHasValue == true {
                    transformedNumber = regexper.replaceFirstStringByRegex(prefixPattern, string: number, templateString: transformRule)
                } else {
                    let index = number.index(number.startIndex, offsetBy: firstMatchString.count)
                    transformedNumber = String(number[index...])
                }
                if regexper.hasValue(nationalNumberRule), regexper.matchesEntirely(nationalNumberRule, string: number), regexper.matchesEntirely(nationalNumberRule, string: transformedNumber) == false {
                    return
                }
                number = transformedNumber
                return
            }
        } catch {
            return
        }
    }
    
    private func checkNumberType(_ nationalNumber: String, metadata: MetadataPhoneNumberTerritory, leadingZero: Bool = false) -> PhoneNumberType {
        if leadingZero {
            let type = checkNumberType("0" + String(nationalNumber), metadata: metadata)
            if type != .unknown {
                return type
            }
        }
        guard let generalNumberDesc = metadata.generalDesc else {
            return .unknown
        }
        if regexper.hasValue(generalNumberDesc.nationalNumberPattern) == false || isNumberMatchingDesc(nationalNumber, numberDesc: generalNumberDesc) == false {
            return .unknown
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.pager) {
            return .pager
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.premiumRate) {
            return .premiumRate
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.tollFree) {
            return .tollFree
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.sharedCost) {
            return .sharedCost
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.voip) {
            return .voip
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.personalNumber) {
            return .personalNumber
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.uan) {
            return .uan
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.voicemail) {
            return .voicemail
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.fixedLine) {
            if metadata.fixedLine?.nationalNumberPattern == metadata.mobile?.nationalNumberPattern {
                return .fixedOrMobile
            } else if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.mobile) {
                return .fixedOrMobile
            } else {
                return .fixedLine
            }
        }
        if isNumberMatchingDesc(nationalNumber, numberDesc: metadata.mobile) {
            return .mobile
        }
        return .unknown
    }
    
    private func validPhoneNumber(from nationalNumber: String, using regionMetadata: MetadataPhoneNumberTerritory, countryCode: UInt64, ignoreType: Bool, numberString: String, numberExtension: String?) throws -> PhoneNumber? {
        var nationalNumber = nationalNumber
        var regionMetadata = regionMetadata
        // National Prefix Strip
        stripNationalPrefix(&nationalNumber, metadata: regionMetadata)
        // Test number against general number description for correct metadata
        if let generalNumberDesc = regionMetadata.generalDesc, regexper.hasValue(generalNumberDesc.nationalNumberPattern) == false || isNumberMatchingDesc(nationalNumber, numberDesc: generalNumberDesc) == false {
            return nil
        }
        // Finalize remaining parameters and create phone number object
        let leadingZero = nationalNumber.hasPrefix("0")
        guard let finalNationalNumber = UInt64(nationalNumber) else {
            throw PhoneNumberError.notANumber
        }
        // Check if the number if of a known type
        var type: PhoneNumberType = .unknown
        if ignoreType == false {
            if let regionCode = getRegionCode(of: finalNationalNumber, countryCode: countryCode, leadingZero: leadingZero), let foundMetadata = dataSource.filterTerritories(byCountry: regionCode) {
                regionMetadata = foundMetadata
            }
            type = checkNumberType(String(nationalNumber), metadata: regionMetadata, leadingZero: leadingZero)
            if type == .unknown {
                throw PhoneNumberError.unknownType
            }
        }
        return PhoneNumber(numberString: numberString, countryCode: countryCode, leadingZero: leadingZero, nationalNumber: finalNationalNumber, numberExtension: numberExtension, type: type, regionID: regionMetadata.codeID)
    }
    
    private func extractCountryCode(_ number: String, nationalNumber: inout String, metadata: MetadataPhoneNumberTerritory) throws -> UInt64 {
        var fullNumber = number
        guard let possibleCountryIddPrefix = metadata.internationalPrefix else {
            return 0
        }
        let countryCodeSource: PhoneNumberCountryCodeSource
        if regexper.matchesAtStart(PhoneNumberPatterns.leadingPlusCharsPattern, string: fullNumber) {
            fullNumber = regexper.replaceStringByRegex(PhoneNumberPatterns.leadingPlusCharsPattern, string: fullNumber)
            countryCodeSource = .numberWithPlusSign
        } else {
            fullNumber = normalizePhoneNumber(fullNumber)
            if parsePrefixAsIdd(&fullNumber, possibleCountryIddPrefix: possibleCountryIddPrefix) {
                countryCodeSource = .numberWithIDD
            } else {
                countryCodeSource = .defaultCountry
            }
        }
        if countryCodeSource != .defaultCountry {
            if fullNumber.count <= PhoneNumberConstants.minLengthForNSN {
                throw PhoneNumberError.tooShort
            }
            return extractPotentialCountryCode(fullNumber, nationalNumber: &nationalNumber)
        } else {
            let defaultCountryCode = String(metadata.countryCode)
            if fullNumber.hasPrefix(defaultCountryCode) {
                let nsFullNumber = fullNumber as NSString
                var potentialNationalNumber = nsFullNumber.substring(from: defaultCountryCode.count)
                guard let validNumberPattern = metadata.generalDesc?.nationalNumberPattern, let possibleNumberPattern = metadata.generalDesc?.possibleNumberPattern else {
                    return 0
                }
                stripNationalPrefix(&potentialNationalNumber, metadata: metadata)
                let potentialNationalNumberStr = potentialNationalNumber
                if (!regexper.matchesEntirely(validNumberPattern, string: fullNumber) && regexper.matchesEntirely(validNumberPattern, string: potentialNationalNumberStr)) || regexper.testStringLengthAgainstPattern(possibleNumberPattern, string: fullNumber as String) == false {
                    nationalNumber = potentialNationalNumberStr
                    if let countryCode = UInt64(defaultCountryCode) {
                        return UInt64(countryCode)
                    }
                }
            }
        }
        return 0
    }
    
    private func parse(_ numberString: String, withRegion region: String, ignoreType: Bool) throws -> PhoneNumber {
        // Make sure region is in uppercase so that it matches metadata
        let region = region.uppercased()
        // Extract number
        var nationalNumber = numberString
        let match = try regexper.phoneDataDetectorMatch(numberString)
        let matchedNumber = nationalNumber.substring(with: match.range)
        // Replace Arabic and Persian numerals and let the rest unchanged
        nationalNumber = regexper.stringByReplacingOccurrences(matchedNumber, map: PhoneNumberPatterns.allNormalizationMappings, keepUnmapped: true)
        // Strip and extract extension
        let numberExtension: String?
        let matches = try? regexper.regexMatches(PhoneNumberPatterns.extnPattern, string: nationalNumber)
        if let match = matches?.first {
            let adjustedRange = NSRange(location: match.range.location + 1, length: match.range.length - 1)
            let rawExtension = nationalNumber.substring(with: adjustedRange)
            let stringRange = NSRange(location: 0, length: match.range.location)
            nationalNumber = nationalNumber.substring(with: stringRange)
            numberExtension = normalizePhoneNumber(rawExtension)
        } else {
            numberExtension = nil
        }
        // Country code parse
        guard var regionMetadata = dataSource.filterTerritories(byCountry: region) else {
            throw PhoneNumberError.invalidCountryCode
        }
        let countryCode: UInt64
        do {
            countryCode = try extractCountryCode(nationalNumber, nationalNumber: &nationalNumber, metadata: regionMetadata)
        } catch {
            let plusRemovedNumberString = regexper.replaceStringByRegex(PhoneNumberPatterns.leadingPlusCharsPattern, string: nationalNumber as String)
            countryCode = try extractCountryCode(plusRemovedNumberString, nationalNumber: &nationalNumber, metadata: regionMetadata)
        }
        // Normalized number
        nationalNumber = normalizePhoneNumber(nationalNumber)
        if countryCode == 0 {
            if let result = try validPhoneNumber(from: nationalNumber, using: regionMetadata, countryCode: regionMetadata.countryCode, ignoreType: ignoreType, numberString: numberString, numberExtension: numberExtension) {
                return result
            }
            throw PhoneNumberError.notANumber
        }
        // If country code is not default, grab correct metadata
        if countryCode != regionMetadata.countryCode, let countryMetadata = dataSource.mainTerritory(forCode: countryCode) {
            regionMetadata = countryMetadata
        }
        if let result = try validPhoneNumber(from: nationalNumber, using: regionMetadata, countryCode: countryCode, ignoreType: ignoreType, numberString: numberString, numberExtension: numberExtension) {
            return result
        }
        // If everything fails, iterate through other territories with the same country code
        var possibleResults = [PhoneNumber]()
        if let metadataList = dataSource.filterTerritories(byCode: countryCode) {
            for metadata in metadataList where regionMetadata.codeID != metadata.codeID {
                if let result = try validPhoneNumber(from: nationalNumber, using: metadata, countryCode: countryCode, ignoreType: ignoreType, numberString: numberString, numberExtension: numberExtension) {
                    possibleResults.append(result)
                }
            }
        }
        switch possibleResults.count {
        case 0:
            throw PhoneNumberError.notANumber
        case 1:
            return possibleResults[0]
        default:
            throw PhoneNumberError.ambiguousNumber(phoneNumbers: possibleResults)
        }
    }
    
    private func getRegionCode(of nationalNumber: UInt64, countryCode: UInt64, leadingZero: Bool) -> String? {
        guard let regions = dataSource.filterTerritories(byCode: countryCode) else {
            return nil
        }
        if regions.count == 1 {
            return regions[0].codeID
        }
        let nationalNumberString = String(nationalNumber)
        for region in regions {
            if let leadingDigits = region.leadingDigits {
                if regexper.matchesAtStart(leadingDigits, string: nationalNumberString) {
                    return region.codeID
                }
            }
            if leadingZero, checkNumberType("0" + nationalNumberString, metadata: region) != .unknown {
                return region.codeID
            }
            if checkNumberType(nationalNumberString, metadata: region) != .unknown {
                return region.codeID
            }
        }
        return nil
    }
    
    private func extractPotentialCountryCode(_ fullNumber: String, nationalNumber: inout String) -> UInt64 {
        let nsFullNumber = fullNumber as NSString
        if nsFullNumber.length == 0 || nsFullNumber.substring(to: 1) == "0" {
            return 0
        }
        let numberLength = nsFullNumber.length
        let maxCountryCode = PhoneNumberConstants.maxLengthCountryCode
        var startPosition = 0
        if fullNumber.hasPrefix("+") {
            if nsFullNumber.length == 1 {
                return 0
            }
            startPosition = 1
        }
        for i in 1...min(numberLength - startPosition, maxCountryCode) {
            let stringRange = NSRange(location: startPosition, length: i)
            let subNumber = nsFullNumber.substring(with: stringRange)
            if let potentialCountryCode = UInt64(subNumber), dataSource.filterTerritories(byCode: potentialCountryCode) != nil {
                nationalNumber = nsFullNumber.substring(from: i)
                return potentialCountryCode
            }
        }
        return 0
    }
    
    private func parsePrefixAsIdd(_ fullNumber: inout String, possibleCountryIddPrefix: String) -> Bool {
        if regexper.stringPositionByRegex(possibleCountryIddPrefix, string: fullNumber) == 0 {
            do {
                guard let matched = try regexper.regexMatches(possibleCountryIddPrefix, string: fullNumber as String).first else {
                    return false
                }
                let matchedString = fullNumber.substring(with: matched.range)
                let matchEnd = matchedString.count
                let remainString = (fullNumber as NSString).substring(from: matchEnd)
                let capturingDigitPatterns = try NSRegularExpression(pattern: PhoneNumberPatterns.capturingDigitPattern, options: NSRegularExpression.Options.caseInsensitive)
                let matchedGroups = capturingDigitPatterns.matches(in: remainString as String)
                if let firstMatch = matchedGroups.first {
                    let digitMatched = remainString.substring(with: firstMatch.range) as NSString
                    if digitMatched.length > 0 {
                        let normalizedGroup = regexper.stringByReplacingOccurrences(digitMatched as String, map: PhoneNumberPatterns.allNormalizationMappings)
                        if normalizedGroup == "0" {
                            return false
                        }
                    }
                }
                fullNumber = remainString as String
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }
    
}
