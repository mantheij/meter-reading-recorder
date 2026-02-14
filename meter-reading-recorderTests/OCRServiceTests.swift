import Testing
@testable import meter_reading_recorder

struct OCRServiceTests {

    @Test func validNumberAtLeastFourDigits() {
        #expect(OCRService.extractNumbers(from: ["12345"]) == "12345")
    }

    @Test func numberWithDecimal() {
        #expect(OCRService.extractNumbers(from: ["1234.5"]) == "1234.5")
    }

    @Test func commaNormalization() {
        #expect(OCRService.extractNumbers(from: ["1234,5"]) == "1234.5")
    }

    @Test func tooFewDigitsReturnsNil() {
        #expect(OCRService.extractNumbers(from: ["123"]) == nil)
    }

    @Test func emptyArrayReturnsNil() {
        #expect(OCRService.extractNumbers(from: []) == nil)
    }

    @Test func firstValidStringIsUsed() {
        let result = OCRService.extractNumbers(from: ["abc", "12345", "67890"])
        #expect(result == "12345")
    }

    @Test func skipsInvalidPicksValid() {
        let result = OCRService.extractNumbers(from: ["12", "99", "54321"])
        #expect(result == "54321")
    }

    @Test func embeddedLettersStripped() {
        #expect(OCRService.extractNumbers(from: ["abc12345def"]) == "12345")
    }

    @Test func multipleDecimalPointsNormalized() {
        #expect(OCRService.extractNumbers(from: ["1234.5.6"]) == "1234.56")
    }

    @Test func exactlyFourDigits() {
        #expect(OCRService.extractNumbers(from: ["1234"]) == "1234")
    }
}
