import XCTest

final class BloomUITests: XCTestCase {
    @MainActor
    func testTimestampedLoggingAndOneOffCreation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        app.buttons["habit-Drink water"].tap()
        XCTAssertTrue(app.buttons["add-one"].waitForExistence(timeout: 5))
        app.buttons["add-one"].tap()
        app.buttons["add-one"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "2")
        XCTAssertTrue(app.staticTexts["2 entries"].exists)
        app.buttons["Log amount and time"].tap()
        let amount = app.textFields["log-amount"]
        amount.tap(); amount.typeText(XCUIKeyboardKey.delete.rawValue + "3")
        app.buttons["save-entry"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "5")
        app.buttons["Close habit"].tap()
        app.buttons["Add habit"].tap()
        app.buttons["Just this day"].tap()
        let name = app.textFields["habit-name"]
        name.tap(); name.typeText("Collected parcel")
        app.buttons["save-habit"].tap()
        let item = app.buttons["habit-Collected parcel"]
        app.swipeUp()
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        app.buttons["add-one"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "2")
        app.buttons["Close habit"].tap()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        app.buttons[tomorrow.formatted(date: .complete, time: .omitted)].tap()
        XCTAssertFalse(app.buttons["habit-Collected parcel"].exists)
        app.buttons[Date().formatted(date: .complete, time: .omitted)].tap()
        app.buttons["All activity timeline"].tap()
        XCTAssertTrue(app.staticTexts["Collected parcel"].exists)
        XCTAssertTrue(app.staticTexts["Drink water"].exists)
        app.buttons["Done"].tap()
        app.buttons["Progress tab"].tap()
        XCTAssertTrue(app.staticTexts["Monthly rate"].exists)
        app.buttons["Report tab"].tap()
        XCTAssertTrue(app.staticTexts["Habit Tracker"].exists)
        app.buttons["Settings tab"].tap()
        XCTAssertTrue(app.buttons["Export backup"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["habit-Drink water"].tap()
        XCTAssertEqual(app.staticTexts["habit-count"].label, "5")
    }
}
