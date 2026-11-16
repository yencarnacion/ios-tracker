import XCTest

final class NumericUITests: XCTestCase {
    @MainActor
    private func appWithTracker(_ template: String, title: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        app.buttons["Add habit"].tap()
        app.buttons["Values"].tap()
        app.buttons["measurement-template"].tap()
        app.buttons[template].tap()
        app.buttons["save-habit"].tap()
        app.swipeUp()
        let row = app.buttons["habit-\(title)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        return app
    }

    @MainActor
    private func record(_ values: [String], in app: XCUIApplication) {
        app.buttons["log-values"].tap()
        for (index, value) in values.enumerated() where !value.isEmpty {
            let field = app.textFields["measurement-\(index)"]
            field.tap(); field.typeText(value)
        }
        app.buttons["save-entry"].tap()
    }

    @MainActor
    func testWeightValuesCanBeGraphedEditedAndReloaded() {
        continueAfterFailure = false
        let app = appWithTracker("Weight (kg)", title: "Weight")
        XCTAssertFalse(app.buttons["add-one"].exists)
        record(["82.4"], in: app)
        record(["82.1"], in: app)
        XCTAssertEqual(app.staticTexts["numeric-entry-count"].label, "2 entries on this day")
        XCTAssertEqual(app.staticTexts["chart-value"].label, "82.1 kg")
        app.swipeUp()
        let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "measurement-entry-"))
        XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 5))
        entries.firstMatch.tap()
        XCTAssertEqual(app.textFields["measurement-0"].value as? String, "82.1")
        app.buttons["Clear Weight"].tap()
        let value = app.textFields["measurement-0"]
        value.tap(); value.typeText("81.9")
        app.buttons["save-entry"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.swipeUp()
        app.buttons["habit-Weight"].tap()
        XCTAssertEqual(app.staticTexts["numeric-entry-count"].label, "2 entries on this day")
        XCTAssertEqual(app.staticTexts["chart-value"].label, "81.9 kg")
    }

    @MainActor
    func testRowingSupportsTwoValuesAndPartialEntriesWithoutInventingZeros() {
        continueAfterFailure = false
        let app = appWithTracker("Rowing", title: "Rowing")
        record(["20.5", "5000"], in: app)
        record(["25", "6000"], in: app)
        app.buttons["chart-metric"].tap()
        app.buttons["Distance (m)"].tap()
        XCTAssertEqual(app.staticTexts["chart-value"].label, "6000 m")
        record(["30", ""], in: app)
        XCTAssertEqual(app.staticTexts["numeric-entry-count"].label, "3 entries on this day")
        XCTAssertEqual(app.staticTexts["chart-value"].label, "6000 m")
        app.buttons["chart-metric"].tap()
        app.buttons["Duration (min)"].tap()
        XCTAssertEqual(app.staticTexts["chart-value"].label, "30 min")
        app.buttons["Close habit"].tap()
        app.buttons["All activity timeline"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Duration: 20.5")).firstMatch.exists)
    }
}
