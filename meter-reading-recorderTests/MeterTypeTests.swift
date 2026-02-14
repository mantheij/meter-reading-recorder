import Testing
@testable import meter_reading_recorder

struct MeterTypeTests {

    @Test func allCasesCount() {
        #expect(MeterType.allCases.count == 3)
    }

    @Test func rawValues() {
        #expect(MeterType.water.rawValue == "water")
        #expect(MeterType.electricity.rawValue == "electricity")
        #expect(MeterType.gas.rawValue == "gas")
    }

    @Test func iconNamesAreValid() {
        #expect(MeterType.water.iconName == "drop.fill")
        #expect(MeterType.electricity.iconName == "bolt.fill")
        #expect(MeterType.gas.iconName == "flame.fill")
    }

    @Test func displayNamesNotEmpty() {
        for type in MeterType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }

    @Test func iconNamesNotEmpty() {
        for type in MeterType.allCases {
            #expect(!type.iconName.isEmpty)
        }
    }

    @Test func accentColorsExist() {
        #expect(!MeterType.accentColors.isEmpty)
        #expect(!MeterType.darkAccentColors.isEmpty)
    }
}
