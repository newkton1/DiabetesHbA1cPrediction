//
//  DiabetesFeastScreenshots.swift
//  DiabetesHbA1cPredictionUITests
//
//  fastlane snapshot UI test — captures all screens including sub-screens.
//
//  Run order:
//    1. Load demo data (Profile → "Load Demo Data")
//    2. Dashboard
//    3. What If? tab
//    4. Glucose tab
//    5. Exercise tab
//    6. Profile tab (normal + scrolled)
//    7. Dashboard → Meals History → expanded meal row
//    8. Dashboard → Add Meal sheet → Food Search (All) → Food Search (日本食)
//    9. What If? tab → Plan Feast Treat sheet
//

import XCTest

final class DiabetesFeastScreenshots: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchEnvironment["IS_UI_SCREENSHOT_TEST"] = "1"
    }

    // MARK: - Main run

    @MainActor
    func testCaptureAllScreens() throws {

        setupSnapshot(app)
        app.launch()

        // Dismiss welcome sheet if it appears
        let welcomeDismiss = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'get started' OR label CONTAINS[c] 'continue' OR label CONTAINS[c] 'close' OR label CONTAINS[c] '始める' OR label CONTAINS[c] '閉じる'")
        ).firstMatch
        if welcomeDismiss.waitForExistence(timeout: 4) { welcomeDismiss.tap() }

        // ── Step 0: Load demo data from Profile tab ───────────────────────
        tapTab(index: 4)
        let loadDemo = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Load Demo' OR label CONTAINS[c] 'demo'")
        ).firstMatch
        if loadDemo.waitForExistence(timeout: 4) {
            loadDemo.tap()
            sleep(5)   // wait for Core Data inserts
        }

        // ── 1. Dashboard ──────────────────────────────────────────────────
        tapTab(index: 0)
        sleep(2)
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
        app.swipeUp()
        sleep(1)
        snapshot("06_Profile_Scrolled")

        // ── 6. Meals History (from Dashboard card) ────────────────────────
        tapTab(index: 0)
        sleep(1)

        let mealsCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Meals History' OR label CONTAINS[c] '食事履歴'")
        ).firstMatch
        if mealsCard.waitForExistence(timeout: 3) {
            mealsCard.tap()
            sleep(2)
            snapshot("07_MealHistory")

            // Tap the first meal row to expand food items
            let firstMealRow = app.buttons.firstMatch
            if firstMealRow.waitForExistence(timeout: 2) {
                firstMealRow.tap()
                sleep(1)
                snapshot("08_MealHistory_Expanded")
            }

            // Back to Dashboard
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists { backButton.tap() }
            sleep(1)
        }

        // ── 7. Add Meal sheet ─────────────────────────────────────────────
        let addMealCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Add Meal' OR label CONTAINS[c] '食事を記録'")
        ).firstMatch
        if addMealCard.waitForExistence(timeout: 3) {
            addMealCard.tap()
            sleep(1)
            snapshot("09_AddMeal")

            // ── 8. Food search ────────────────────────────────────────────
            let searchLink = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Search Food' OR label CONTAINS[c] '食品を検索' OR label CONTAINS[c] 'Search'")
            ).firstMatch
            if searchLink.waitForExistence(timeout: 2) {
                searchLink.tap()
                sleep(2)
                snapshot("10_FoodSearch_All")

                // 日本食 chip
                let jpChip = app.buttons.matching(
                    NSPredicate(format: "label == '日本食' OR label CONTAINS[c] 'Japanese'")
                ).firstMatch
                if jpChip.waitForExistence(timeout: 2) {
                    jpChip.tap()
                    sleep(1)
                    snapshot("11_FoodSearch_Japanese")
                }

                // Cancel food search
                let cancelFood = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] 'cancel' OR label CONTAINS[c] 'キャンセル' OR label CONTAINS[c] 'back' OR label CONTAINS[c] '戻'")
                ).firstMatch
                if cancelFood.waitForExistence(timeout: 2) { cancelFood.tap() }
                sleep(1)
            }

            // Cancel meal sheet
            let cancelMeal = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'cancel' OR label CONTAINS[c] 'キャンセル'")
            ).firstMatch
            if cancelMeal.waitForExistence(timeout: 2) { cancelMeal.tap() }
            sleep(1)
        }

        // ── 9. Plan Feast Treat (What If? tab) ───────────────────────────
        tapTab(index: 1)
        sleep(1)

        let feastButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'feast' OR label CONTAINS[c] 'Eat Treat' OR label CONTAINS[c] 'ごちそう' OR label CONTAINS[c] 'Plan'")
        ).firstMatch
        if feastButton.waitForExistence(timeout: 3) {
            feastButton.tap()
            sleep(2)
            snapshot("12_PlanFeast")

            // Tap Similar Meal if present to go deeper
            let similarButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Similar' OR label CONTAINS[c] '似た' OR label CONTAINS[c] 'similar'")
            ).firstMatch
            if similarButton.waitForExistence(timeout: 2) {
                similarButton.tap()
                sleep(2)
                snapshot("13_SimilarMeal")
                // back
                let back = app.navigationBars.buttons.firstMatch
                if back.exists { back.tap() }
                sleep(1)
            }

            let cancelFeast = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'cancel' OR label CONTAINS[c] 'キャンセル' OR label CONTAINS[c] 'back'")
            ).firstMatch
            if cancelFeast.waitForExistence(timeout: 2) { cancelFeast.tap() }
        }
    }

    // MARK: - Helpers

    private func tapTab(index: Int) {
        let tabs = app.tabBars.firstMatch.buttons
        guard tabs.count > index else { return }
        tabs.element(boundBy: index).tap()
    }
}
