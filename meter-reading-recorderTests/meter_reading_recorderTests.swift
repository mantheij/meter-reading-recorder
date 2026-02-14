import Testing
@testable import meter_reading_recorder

struct ValueFormatterTests {

    // MARK: - Valid inputs

    @Test func normalDigits() {
        #expect(ValueFormatter.sanitizeMeterValue("12345") == "12345")
    }

    @Test func commaToPointNormalization() {
        #expect(ValueFormatter.sanitizeMeterValue("123,45") == "123.45")
    }

    @Test func multipleDotsKeepsOnlyFirst() {
        #expect(ValueFormatter.sanitizeMeterValue("1.2.3") == "1.23")
    }

    @Test func whitespaceIsTrimmed() {
        #expect(ValueFormatter.sanitizeMeterValue("  123  ") == "123")
    }

    @Test func nonDigitCharactersFiltered() {
        #expect(ValueFormatter.sanitizeMeterValue("abc123def") == "123")
    }

    @Test func commaAndDotCombination() {
        // Comma becomes dot first, then multiple dots collapse: "1.234.56" → "1.23456"
        #expect(ValueFormatter.sanitizeMeterValue("1,234.56") == "1.23456")
    }

    @Test func singleDigit() {
        #expect(ValueFormatter.sanitizeMeterValue("5") == "5")
    }

    @Test func decimalOnly() {
        #expect(ValueFormatter.sanitizeMeterValue("0.5") == "0.5")
    }

    // MARK: - Nil results

    @Test func emptyStringReturnsNil() {
        #expect(ValueFormatter.sanitizeMeterValue("") == nil)
    }

    @Test func onlySpecialCharsReturnsNil() {
        #expect(ValueFormatter.sanitizeMeterValue("abc!@#") == nil)
    }

    @Test func onlyDotReturnsNil() {
        #expect(ValueFormatter.sanitizeMeterValue(".") == nil)
    }

    @Test func onlyCommaReturnsNil() {
        #expect(ValueFormatter.sanitizeMeterValue(",") == nil)
    }
}
