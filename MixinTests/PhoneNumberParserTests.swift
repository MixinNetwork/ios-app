import XCTest

final class PhoneNumberParserTests: XCTestCase {

    let phoneNumberParser = PhoneNumberParser()
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testFailingNumber() {
        do {
            _ = try phoneNumberParser.parse("+5491187654321 ABC123")
            XCTFail()
        } catch {
            XCTAssertTrue(true)
        }
    }
    
    func testCNNumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("138 0038 0000", withRegion: "CN")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+8613800380000")
        } catch {
            XCTFail()
        }
    }
    
    func testUSNumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("650 253 0000", withRegion: "US")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+16502530000")
            let phoneNumber2 = try phoneNumberParser.parse("800 253 0000", withRegion: "US")
            XCTAssertNotNil(phoneNumber2)
            let phoneNumberE164Format2 = phoneNumberParser.format(phoneNumber2)
            XCTAssertTrue(phoneNumberE164Format2 == "+18002530000")
            let phoneNumber3 = try phoneNumberParser.parse("900 253 0000", withRegion: "US")
            XCTAssertNotNil(phoneNumber3)
            let phoneNumberE164Format3 = phoneNumberParser.format(phoneNumber3)
            XCTAssertTrue(phoneNumberE164Format3 == "+19002530000")
        } catch {
            XCTFail()
        }
    }

    func testBSNumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("242 365 1234", withRegion: "BS")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+12423651234")
        } catch {
            XCTFail()
        }
    }

    func testGBNumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("(020) 7031 3000", withRegion: "GB")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+442070313000")
            let phoneNumber2 = try phoneNumberParser.parse("(07912) 345 678", withRegion: "GB")
            XCTAssertNotNil(phoneNumber2)
            let phoneNumberE164Format2 = phoneNumberParser.format(phoneNumber2)
            XCTAssertTrue(phoneNumberE164Format2 == "+447912345678")
        } catch {
            XCTFail()
        }
    }

    func testDENumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("0291 12345678", withRegion: "DE")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+4929112345678")
            let phoneNumber2 = try phoneNumberParser.parse("04134 1234", withRegion: "DE")
            XCTAssertNotNil(phoneNumber2)
            let phoneNumberE164Format2 = phoneNumberParser.format(phoneNumber2)
            XCTAssertTrue(phoneNumberE164Format2 == "+4941341234")
            let phoneNumber3 = try phoneNumberParser.parse("+49 8021 2345", withRegion: "DE")
            XCTAssertNotNil(phoneNumber3)
            let phoneNumberE164Format3 = phoneNumberParser.format(phoneNumber3)
            XCTAssertTrue(phoneNumberE164Format3 == "+4980212345")
        } catch {
            XCTFail()
        }
    }

    func testITNumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("02 3661 8300", withRegion: "IT")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+390236618300")
        } catch {
            XCTFail()
        }
    }

    func testAUNumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("02 3661 8300", withRegion: "AU")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+61236618300")
            let phoneNumber2 = try phoneNumberParser.parse("+61 1800 123 456", withRegion: "AU")
            XCTAssertNotNil(phoneNumber2)
            let phoneNumberE164Format2 = phoneNumberParser.format(phoneNumber2)
            XCTAssertTrue(phoneNumberE164Format2 == "+611800123456")
        } catch {
            XCTFail()
        }
    }
    
    func testAllExampleNumbers() {
        let metaDataArray = phoneNumberParser.dataSource.territories.filter { $0.codeID.count == 2 }
        for metadata in metaDataArray {
            let codeID = metadata.codeID
            let metadataWithTypes: [(MetadataPhoneNumberDesc?, PhoneNumberType?)] = [
                (metadata.generalDesc, nil),
                (metadata.fixedLine, .fixedLine),
                (metadata.mobile, .mobile),
                (metadata.tollFree, .tollFree),
                (metadata.premiumRate, .premiumRate),
                (metadata.sharedCost, .sharedCost),
                (metadata.voip, .voip),
                (metadata.voicemail, .voicemail),
                (metadata.pager, .pager),
                (metadata.uan, .uan),
                (metadata.emergency, nil)
            ]
            metadataWithTypes.forEach { record in
                if let desc = record.0 {
                    if let exampleNumber = desc.exampleNumber {
                        do {
                            let phoneNumber = try phoneNumberParser.parse(exampleNumber, withRegion: codeID)
                            XCTAssertNotNil(phoneNumber)
                            if let type = record.1 {
                                if phoneNumber.type == .fixedOrMobile {
                                    XCTAssert(type == .fixedLine || type == .mobile)
                                } else {
                                    XCTAssertEqual(phoneNumber.type, type, "Expected type \(type) for number \(phoneNumber)")
                                }
                            }
                        } catch (let e) {
                            XCTFail("Failed to create PhoneNumber for \(exampleNumber): \(e)")
                        }
                    }
                }
            }
        }
    }
    
    func testUSTollFreeNumberType() {
        guard let number = try? phoneNumberParser.parse("8002345678", withRegion: "US") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.tollFree)
    }

    func testBelizeTollFreeType() {
        guard let number = try? phoneNumberParser.parse("08001234123", withRegion: "BZ") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.tollFree)
    }

    func testItalyFixedLineType() {
        guard let number = try? phoneNumberParser.parse("0669812345", withRegion: "IT") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.fixedLine)
    }

    func testMaldivesMobileNumber() {
        guard let number = try? phoneNumberParser.parse("7812345", withRegion: "MV") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.mobile)
    }

    func testZimbabweVoipType() {
        guard let number = try? phoneNumberParser.parse("8686123456", withRegion: "ZW") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.voip)
    }

    func testAntiguaPagerNumberType() {
        guard let number = try? phoneNumberParser.parse("12684061234", withRegion: "US") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.pager)
    }

    func testFranceMobileNumberType() {
        guard let number = try? phoneNumberParser.parse("+33 612-345-678") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.mobile)
    }

    func testAENumberWithHinduArabicNumerals() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("+٩٧١٥٠٠٥٠٠٥٥٠", withRegion: "AE")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+971500500550")
        } catch {
            XCTFail()
        }
    }

    func testAENumberWithMixedHinduArabicNumerals() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("+٩٧١5٠٠5٠٠55٠", withRegion: "AE")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+971500500550")
        } catch {
            XCTFail()
        }
    }

    func testAENumberWithEasternArabicNumerals() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("+۹۷۱۵۰۰۵۰۰۵۵۰", withRegion: "AE")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+971500500550")
        } catch {
            XCTFail()
        }
    }

    func testAENumberWithMixedEasternArabicNumerals() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("+۹۷۱5۰۰5۰۰55۰", withRegion: "AE")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+971500500550")
        } catch {
            XCTFail()
        }
    }

    func testUANumber() {
        do {
            let phoneNumber1 = try phoneNumberParser.parse("380501887766", withRegion: "UA")
            XCTAssertNotNil(phoneNumber1)
            let phoneNumberE164Format1 = phoneNumberParser.format(phoneNumber1)
            XCTAssertTrue(phoneNumberE164Format1 == "+380501887766")
            let phoneNumber2 = try phoneNumberParser.parse("050 188 7766", withRegion: "UA")
            XCTAssertNotNil(phoneNumber2)
            let phoneNumberE164Format2 = phoneNumberParser.format(phoneNumber2)
            XCTAssertTrue(phoneNumberE164Format2 == "+380501887766")
            let phoneNumber3 = try phoneNumberParser.parse("050 188 7766", withRegion: "UA")
            XCTAssertNotNil(phoneNumber3)
            let phoneNumberE164Format3 = phoneNumberParser.format(phoneNumber3)
            XCTAssertTrue(phoneNumberE164Format3 == "+380501887766")
        } catch {
            XCTFail()
        }
    }
    func testExtensionWithCommaParsing() {
        guard let number = try? phoneNumberParser.parse("+33 612-345-678,22") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.mobile)
        XCTAssertEqual(number.numberExtension, "22")
    }
    
    func testExtensionWithSemiColonParsing() {
        guard let number = try? phoneNumberParser.parse("+33 612-345-678;22") else {
            XCTFail()
            return
        }
        XCTAssertEqual(number.type, PhoneNumberType.mobile)
        XCTAssertEqual(number.numberExtension, "22")
    }
    
}