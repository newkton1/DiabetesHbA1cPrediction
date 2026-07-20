//
//  DiabetesFeastScreenshots.swift
//  DiabetesHbA1cPredictionUITests
//
//  fastlane snapshot UI test scaffold.
//  Captures all main screens in every locale defined in the Snapfile.
//

import XCTest

final class DiabetesFeastScreenshots: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        // setupSnapshot() is @MainActor so it's called inside testCaptureAllScreens()
        // before app.launch() — do NOT call app.launch() here.
        app.launchArguments += ["-LoadDemoDataOnLaunch", "YES"]
        // Environment variable is more reliable than launch arguments for suppressing
        // the HealthKit auth dialog — it's forwarded to the host app without any parsing.
        app.launchEnvironment["IS_UI_SCREENSHOT_TEST"] = "1"
    }

    // MARK: - Main screenshot run

    @MainActor
    func testCaptureAllScreens() throws {

        // setupSnapshot MUST be called before app.launch()
        setupSnapshot(app)

        app.launch()

        // HealthKit auth is suppressed by -SkipHealthKitAuth launch argument.
        // Give the app a moment to finish loading demo data.
        sleep(3)

        // ── 1. Dashboard ──────────────────────────────────────────────────
        tapTab(index: 0)
        sleep(1)
        snapshot("01_Dashboard")

        // ── 2. What If? ───────────────────────────────────────────────────
        tapTab(index: 1)
        sleep(1)
        snapshot("02_WhatIf")

        // ── 3. Glucose Log ────────────────────────────────────────────────
        tapTab(index: 2)
        sleep(1)
        snapshot("03_GlucoseLog")

        // ── 4. Exercise Log ───────────────────────────────────────────────
        tapTab(index: 3)
        sleep(1)
        snapshot("04_ExerciseLog")

        // ── 5. Profile ────────────────────────────────────────────────────
        tapTab(index: 4)
        sleep(1)
        snapshot("05_Profile")

        // Scroll down to show exercise offset + units sections
        app.swipeUp()
        sleep(1)
        snapshot("06_Profile_Scrolled")

        // ── 6. Add Last Meal sheet ────────────────────────────────────────
        tapTab(index: 0)   // back to Dashboard
        sleep(1)

        let addMealButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'meal' OR label CONTAINS[c] '食事'")
        ).firstMatch
        if addMealButton.exists {
            addMealButton.tap()
            sleep(1)
            snapshot("07_AddLastMeal")

            // ── 7. Food search sheet ──────────────────────────────────────
            let searchButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'search' OR label CONTAINS[c] '検索'")
            ).firstMatch
            if searchButton.exists {
                searchButton.tap()
                sleep(1)
                snapshot("08_FoodSearch_All")

                // Tap 日本食 chip if visible
                let jpChip = app.buttons["日本食"]
                if jpChip.exists {
                    jpChip.tap()
                    sleep(1)
                    snapshot("09_FoodSearch_Japanese")
                }

                let cancelFood = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] 'cancel' OR label CONTAINS[c] 'キャンセル'")
                ).firstMatch
                if cancelFood.exists { cancelFood.tap() }
            }

            let cancelMeal = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'cancel' OR label CONTAINS[c] 'キャンセル'")
            ).firstMatch
            if cancelMeal.exists { cancelMeal.tap() }
        }

        // ── 8. Meal Log ───────────────────────────────────────────────────
        let mealLogLink = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'log' OR label CONTAINS[c] '記録'")
        ).firstMatch
        if mealLogLink.exists {
            mealLogLink.tap()
            sleep(1)
            snapshot("10_MealLog")
            app.navigationBars.buttons.firstMatch.tap()
        }

        // ── 9. Plan Feast Treat ───────────────────────────────────────────
        tapTab(index: 1)
        sleep(1)
        let feastButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'feast' OR label CONTAINS[c] 'ごちそう'")
        ).firstMatch
        if feastButton.exists {
            feastButton.tap()
            sleep(1)
            snapshot("11_PlanFeast")
            let cancelFeast = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'cancel' OR label CONTAINS[c] 'キャンセル'")
            ).firstMatch
            if cancelFeast.exists { cancelFeast.tap() }
        }
    }

    // MARK: - Helpers

    private func tapTab(index: Int) {
        let tabs = app.tabBars.firstMatch.buttons
        guard tabs.count > index else { return }
        tabs.element(boundBy: index).tap()
    }
}
