# Diabetes Feast — Japanese Localisation String Reference

**Branch:** japanese-localisation  
**Purpose:** Complete list of user-facing strings requiring Japanese translation.  
**Format:** `"English string"` → `"Japanese translation"` (fill in Japanese column)

---

## How Xcode Handles Localisation

### What Xcode String Catalogs extract automatically
SwiftUI's `Text("literal string")` already uses `LocalizedStringKey` internally — Xcode 15+ can scan the project and extract every literal string into a `.xcstrings` file via **Product → Export Localizations**. This covers the vast majority of UI text below.

### What needs manual wrapping before extraction works
These patterns are NOT automatically extracted and require code changes first:

| Pattern | Example in code | Fix needed |
|---|---|---|
| String interpolation in Text() | `Text("Based on \(count) readings")` | Convert to `Text("Based on \(count) readings", tableName: nil)` with `%lld` format key in strings file |
| Strings built by concatenation | `"prefix" + variable + "suffix"` | Wrap each literal in `NSLocalizedString()` |
| Strings passed as `String` (not `LocalizedStringKey`) | computed var returned as `String` | Change parameter type to `LocalizedStringKey` or use `NSLocalizedString` |
| Error messages in non-View code | strings in managers/engines | Wrap with `NSLocalizedString("key", comment: "")` |

### Special categories requiring separate work
- **Food database names** — FoodDatabase.json and FoodDatabase_JP.json food item names (thousands of entries; Japanese DB already has Japanese names)
- **Exercise type names** — enum raw values used in UI ("Walking", "Running", etc.)
- **Food category chips** — MultiSelectFoodSearchView category labels
- **USDA attribution** — "Data: USDA FoodData Central" (may stay in English per USDA terms)

---

## Strings by Screen

### Tab Bar (ContentView)

| # | English | Japanese |
|---|---|---|
| 1 | Dashboard | |
| 2 | What if? | |
| 3 | Glucose | |
| 4 | Exercise | |
| 5 | User | |

---

### Dashboard (DashboardView)

#### Navigation / Headers
| # | English | Japanese |
|---|---|---|
| 6 | Dashboard | |
| 7 | Lab HbA1c Results | |
| 8 | Actions | |

#### GMI Card
| # | English | Japanese |
|---|---|---|
| 9 | Glucose Management Indicator | |
| 10 | Not enough recent readings to calculate GMI | |
| 11 | Log at least %d glucose readings in the last %d days to update your GMI. | |
| 12 | Log at least %d glucose readings in the last %d days to see your GMI estimate. | |
| 13 | Your GMI estimate needs at least %d glucose readings over %d days. Keep logging daily and your first estimate will appear here automatically. | |
| 14 | Tap the value to recalculate · GMI is an FDA-recognized and endorsed glucose-based indicator, not a laboratory HbA1c result. | |
| 15 | Tap to recalculate GMI | |

#### Lab HbA1c Card
| # | English | Japanese |
|---|---|---|
| 16 | Lab HbA1c | |
| 17 | No lab results in the last %d days | |

#### Quick Stats
| # | English | Japanese |
|---|---|---|
| 18 | Glucose | |
| 19 | Exercise | |
| 20 | (Week) | |
| 21 | Meals History | |
| 22 | User | |

#### Action Buttons
| # | English | Japanese |
|---|---|---|
| 23 | Add Meal | |
| 24 | What if? | |
| 25 | Log what you just ate | |
| 26 | Plan Feast Treat | |

#### Dawn Effect Notice
| # | English | Japanese |
|---|---|---|
| 27 | Pattern noticed: glucose readings between 4–8 AM have been consistently higher than overnight, with no meals logged beforehand. | |
| 28 | This is sometimes called the "dawn effect" — a natural rise in glucose driven by hormones in the early morning. It is common in people with diabetes and does not necessarily indicate a problem. Your GMI value includes these readings as part of its standard calculation. | |

#### CGM Dropout Warning
| # | English | Japanese |
|---|---|---|
| 29 | No glucose data received in the last 30 minutes. Check your CGM Bluetooth connection and bridge app (e.g. Zukka). | |
| 30 | No CGM readings in 30+ min. Check your Bluetooth and bridge app (e.g. Zukka). | |

#### Disclaimer
| # | English | Japanese |
|---|---|---|
| 31 | Diabetes Feast is a wellness app. Estimates shown are for personal tracking only — not medical diagnoses or treatment advice. | |

#### Lab Results Sheet
| # | English | Japanese |
|---|---|---|
| 32 | No lab results to display. | |
| 33 | Swipe left on a result to delete it. This cannot be undone. | |
| 34 | Done | |

#### 14-Day Activity Snapshot
| # | English | Japanese |
|---|---|---|
| 35 | 14-Day Activity Snapshot | |
| 36 | had a post-meal exercise session logged | |
| 37 | within | |
| 38 | 90 min | |
| 39 | after | |
| 40 | 90–180 min | |

---

### Getting Started Checklist (GettingStartedChecklistView)

#### Header
| # | English | Japanese |
|---|---|---|
| 41 | Getting Started | |
| 42 | Dismiss | |

#### Step Titles & Subtitles
| # | English | Japanese |
|---|---|---|
| 43 | Log glucose readings | |
| 44 | When no CGM readings, add your first 3 finger-stick readings | |
| 45 | Connected to Apple Health — glucose syncs automatically | |
| 46 | Log your meals | |
| 47 | Search or build meals from the foods you ate | |
| 48 | Capture post-meal glucose | |
| 49 | Log a reading 1–3 hours after eating to see how meals affected your levels | |
| 50 | With CGM and meals logged, post-meal readings are captured automatically | |
| 51 | Log exercise sessions | |
| 52 | Record walks, runs, or workouts to see how activity affected your glucose | |
| 53 | Connected to Apple Health — workouts sync automatically | |

#### Day Milestones
| # | English | Japanese |
|---|---|---|
| 54 | All steps complete — keep going! | |
| 55 | 3 days of data | |
| 56 | Glucose trend charts are now available | |
| 57 | 7 days of data | |
| 58 | Similar-meal history is now available | |
| 59 | 14 days of data | |
| 60 | Your first GMI estimate is now available | |

---

### Meal Builder (MealBuilderView)

#### Navigation / Toolbar
| # | English | Japanese |
|---|---|---|
| 61 | Done | |
| 62 | Cancel | |
| 63 | Save | |

#### Warning Overlays
| # | English | Japanese |
|---|---|---|
| 64 | High Carb Impact | |
| 65 | This wellness feature shows exercise options based on your activity history. These are for personal tracking only — not medical diagnoses or treatment advice. | |
| 66 | Elevated Blood Glucose | |
| 67 | Adding this food significantly increases the meal's estimated glucose impact. Some people choose to pair high-GI foods with lower-GI options. | |

#### Save Confirmation
| # | English | Japanese |
|---|---|---|
| 68 | Feast Saved | |
| 69 | Meal Saved | |
| 70 | Log glucose readings over the next 2 hours to build your historical pattern for similar meals. | |

#### Form Labels
| # | English | Japanese |
|---|---|---|
| 71 | Selected Foods | |
| 72 | Nutrition Summary | |
| 73 | Treat Name (optional) | |
| 74 | Meal Name (optional) | |
| 75 | Search & Add Foods | |
| 76 | How long ago did you eat this meal? | |
| 77 | When do you plan to eat this meal? | |
| 78 | TOTAL CARBOHYDRATES | |
| 79 | Carb impact | |

#### Time Buttons
| # | English | Japanese |
|---|---|---|
| 80 | Now | |
| 81 | 1 h | |
| 82 | 2 h | |
| 83 | 3 h | |
| 84 | 24 h | |
| 85 | 48 h | |

#### Nutrition Labels
| # | English | Japanese |
|---|---|---|
| 86 | GL | |
| 87 | Carbs | |
| 88 | Fiber | |
| 89 | Protein | |
| 90 | Fat | |
| 91 | Cal | |

#### Historical Pattern Section
| # | English | Japanese |
|---|---|---|
| 92 | Add foods to see your pattern with similar meals. | |
| 93 | Looking for similar meals in your history… | |
| 94 | Typical rise after similar meals | |
| 95 | Range across meals | |
| 96 | Your lab HbA1c in this window | |
| 97 | Carb impact of this meal | |
| 98 | Not enough history yet | |
| 99 | Found %d similar meals, but none had enough glucose data around them to show a pattern. | |
| 100 | High carb impact. Some people choose smaller portions or pair with protein/fiber. | |
| 101 | High carb impact. Lower-GI alternatives tend to produce a smaller glucose response. | |
| 102 | Very high carb feast. Some people find a post-meal walk helpful after meals like this. | |

---

### Meal Log (MealLogView)

#### Navigation
| # | English | Japanese |
|---|---|---|
| 103 | Meals | |
| 104 | Save Error | |

#### Empty State
| # | English | Japanese |
|---|---|---|
| 105 | See how meals have affected your glucose | |
| 106 | Once you've logged meals alongside glucose readings, Diabetes Feast will show you which foods raised your levels — and by how much. Start by logging a meal and checking your glucose before and after eating. | |
| 107 | Log glucose | |
| 108 | Log a meal | |
| 109 | Wait 2 hours | |
| 110 | Log glucose again | |

#### Section Headers / Row Labels
| # | English | Japanese |
|---|---|---|
| 111 | Today | |
| 112 | Yesterday | |
| 113 | Tomorrow | |
| 114 | Meal | |
| 115 | Food Items: | |
| 116 | Unknown | |
| 117 | Carbs | |
| 118 | Fiber | |
| 119 | Proteins | |
| 120 | Fats | |

#### Context Menu
| # | English | Japanese |
|---|---|---|
| 121 | Delete | |
| 122 | Remove from My Menu | |
| 123 | Add to My Menu | |

#### Error
| # | English | Japanese |
|---|---|---|
| 124 | Could not delete meal. Please try again. | |

---

### Food Search (FoodSearchView)

| # | English | Japanese |
|---|---|---|
| 125 | Search Foods | |
| 126 | Close | |
| 127 | Search foods | |
| 128 | Food Database Error | |
| 129 | The food database could not be loaded. | |
| 130 | No Foods Found | |
| 131 | Try searching with a different keyword | |
| 132 | Search Online | |
| 133 | Low | |
| 134 | Medium | |
| 135 | High | |

---

### Glucose Log (GlucoseLogView)

#### Navigation / Toolbar
| # | English | Japanese |
|---|---|---|
| 136 | Glucose | |
| 137 | Sync | |
| 138 | Add Reading | |

#### Alert Messages
| # | English | Japanese |
|---|---|---|
| 139 | Sync Status | |
| 140 | Save Error | |
| 141 | HealthKit Error | |
| 142 | HealthKit could not be authorized. Check Settings > Health > Data Access & Devices. | |
| 143 | Confirm Lab Result | |
| 144 | Is this HbA1c value from a lab blood test? Do NOT enter CGM estimate — this app's estimates require actual lab results. | |
| 145 | Yes, it's a lab result | |
| 146 | Cancel | |

#### Chart Controls
| # | English | Japanese |
|---|---|---|
| 147 | Now | |
| 148 | 1d | |
| 149 | 3d | |
| 150 | 7d | |
| 151 | Tap a highlighted point to see meal and exercise details | |
| 152 | No glucose readings in the last %d days | |
| 153 | Try last 7 days | |

#### Readings List
| # | English | Japanese |
|---|---|---|
| 154 | Unknown | |
| 155 | Finger Stick | |
| 156 | CGM | |
| 157 | Delete | |
| 158 | Could not delete reading. Please try again. | |

#### Hotspot Popover
| # | English | Japanese |
|---|---|---|
| 159 | %@ from baseline | |
| 160 | Above 170 mg/dL threshold | |
| 161 | Returning to baseline | |
| 162 | No meal logged | |
| 163 | Carbs %d g | |
| 164 | No exercise logged | |
| 165 | %d min before | |
| 166 | %d min after | |

#### Add Reading Form
| # | English | Japanese |
|---|---|---|
| 167 | Glucose Reading | |
| 168 | HbA1c Lab Result | |
| 169 | Unit System | |
| 170 | mg/dL (US/Japan) | |
| 171 | mmol/L (Europe/World) | |
| 172 | Glucose Value | |
| 173 | Enter value | |
| 174 | Source | |
| 175 | Manual Finger Stick | |
| 176 | Continuous Glucose Monitor | |
| 177 | Trend | |
| 178 | Timestamp | |
| 179 | Time | |
| 180 | Auto-detected from your region (%@). Override if your lab report uses a different standard. | |
| 181 | Enter lab result | |
| 182 | Value out of clinical range | |
| 183 | Lab Test Date | |
| 184 | Could not save glucose reading. Please try again. | |
| 185 | Could not save HbA1c lab result. Please try again. | |

#### Sync Status Messages
| # | English | Japanese |
|---|---|---|
| 186 | HealthKit authorization denied. Please enable access in Settings > Health > Data Access & Devices. | |
| 187 | Sync encountered an error: %@ | |
| 188 | Sync completed successfully! Imported %d new glucose reading(s) from HealthKit. | |
| 189 | Sync completed. Your glucose readings are already up to date. | |
| 190 | Sync completed. No glucose readings found in HealthKit for the last 30 days. | |

---

### Exercise Log (ExerciseLogView)

#### Navigation
| # | English | Japanese |
|---|---|---|
| 191 | Exercise Log | |

#### Alerts
| # | English | Japanese |
|---|---|---|
| 192 | Delete Exercise | |
| 193 | Are you sure you want to delete this exercise session? | |
| 194 | Delete | |
| 195 | Cancel | |

#### Summary Card
| # | English | Japanese |
|---|---|---|
| 196 | Last 7 Days Summary | |
| 197 | Full Exercise Log | |
| 198 | No Exercise Sessions | |
| 199 | Add your first workout or sync from Health | |
| 200 | Time | |
| 201 | Energy | |
| 202 | Sessions | |
| 203 | Intensity | |

#### Add Exercise Sheet
| # | English | Japanese |
|---|---|---|
| 204 | Add Exercise Session | |
| 205 | Exercise Type | |
| 206 | Walking | |
| 207 | Running | |
| 208 | Cycling | |
| 209 | Swimming | |
| 210 | Strength Training | |
| 211 | Yoga | |
| 212 | HIIT | |
| 213 | Dancing | |
| 214 | Hiking | |
| 215 | Gardening | |
| 216 | Other | |
| 217 | Start Time | |
| 218 | Duration | |
| 219 | Distance | |
| 220 | Intensity (1-10) | |
| 221 | Calories Burned | |
| 222 | Use Estimated Value | |
| 223 | Notes | |
| 224 | Could not save exercise session. Please try again. | |

#### Sync Messages
| # | English | Japanese |
|---|---|---|
| 225 | Sync completed. No new data found in HealthKit for the last 30 days. | |
| 226 | Could not delete exercise. Please try again. | |

---

### User Profile (UserProfileView)

#### Section Headers
| # | English | Japanese |
|---|---|---|
| 227 | Personal Information | |
| 228 | Health Conditions | |
| 229 | About | |
| 230 | Settings | |
| 231 | Share | |
| 232 | Data Management | |
| 233 | Demo Data | |

#### Personal Information
| # | English | Japanese |
|---|---|---|
| 234 | Age | |
| 235 | Sex | |
| 236 | Male | |
| 237 | Female | |
| 238 | Other | |
| 239 | Height (cm) | |
| 240 | Height (ft-in) | |
| 241 | Weight (kg) | |
| 242 | Weight (lbs) | |

#### Health Conditions
| # | English | Japanese |
|---|---|---|
| 243 | Diabetes | |
| 244 | Diabetes Type | |
| 245 | Type 1 | |
| 246 | Type 2 | |
| 247 | Gestational | |
| 248 | This app is NOT for Type 1 diabetics or anyone using insulin bolus therapy. It does not calculate insulin dosage and must not be used for that purpose. | |
| 249 | COPD | |
| 250 | Heart Disease | |
| 251 | Tobacco Use | |
| 252 | Never | |
| 253 | Former | |
| 254 | Current | |
| 255 | Alcohol Units/Week | |

#### Settings / About
| # | English | Japanese |
|---|---|---|
| 256 | BMI | |
| 257 | N/A | |
| 258 | Underweight | |
| 259 | Normal | |
| 260 | Overweight | |
| 261 | Obese | |
| 262 | Offset Exercise | |
| 263 | HbA1c Units | |
| 264 | Weight Units | |
| 265 | Height Units | |
| 266 | Version | |

#### Actions
| # | English | Japanese |
|---|---|---|
| 267 | Quick GMI Text Summary | |
| 268 | Export All Data | |
| 269 | Import Data from JSON | |
| 270 | Load Demo Data | |
| 271 | Wipe All Data | |
| 272 | Watch Onboarding Guide | |
| 273 | Join the Discord Community | |
| 274 | Requires free Discord app for iPhone. Community can also be accessed on desktop from a browser. | |
| 275 | Join the WhatsApp Community | |
| 276 | Requires free WhatsApp app for iPhone. | |
| 277 | Privacy Policy | |
| 278 | Save | |
| 279 | Done | |

#### Alerts
| # | English | Japanese |
|---|---|---|
| 280 | Validation Error | |
| 281 | Profile Saved | |
| 282 | Your profile has been saved successfully. | |
| 283 | Share Health Data? | |
| 284 | This will share your glucose and GMI data with a third party of your choosing (e.g. email, messaging app). This export contains sensitive personal health information. Are you sure you want to continue? | |
| 285 | Export Health Data? | |
| 286 | The export screen contains all your health data including glucose readings, meals, exercise sessions, and your personal profile. This data is sensitive — only share it with people you trust. | |
| 287 | Continue | |
| 288 | Wipe All Data? | |
| 289 | This will permanently delete all data including glucose readings, meals, exercise sessions, and GMI estimates. This cannot be undone. | |
| 290 | Wipe | |
| 291 | Data Wiped | |
| 292 | Demo Data Loaded | |

#### Validation Errors
| # | English | Japanese |
|---|---|---|
| 293 | Age must be between 1 and 120 years. | |
| 294 | Height must be between 50 and 250 cm. | |
| 295 | Weight must be between 20 and 300 kg. | |
| 296 | Weight must be between 44 and 660 lbs. | |
| 297 | Please fill in all required fields. | |

---

### Data Export (DataExportView)

| # | English | Japanese |
|---|---|---|
| 298 | Export Data | |
| 299 | Data Summary | |
| 300 | Export | |
| 301 | Glucose Readings | |
| 302 | Meals | |
| 303 | Exercise Sessions | |
| 304 | GMI Estimates | |
| 305 | User Profiles | |
| 306 | Health Conditions | |
| 307 | Export All Data as JSON | |
| 308 | Export for Doctor (Excel) | |
| 309 | Exports all app data as a single JSON file suitable for validation evidence or Apple Review submission. No data leaves the device until you choose where to share it. | |

---

### Data Import (DataImportView)

| # | English | Japanese |
|---|---|---|
| 310 | Import Data | |
| 311 | Choose JSON File to Import | |
| 312 | Importing… | |
| 313 | Import Summary | |
| 314 | Warnings | |
| 315 | Total imported | |
| 316 | Already existed (skipped) | |
| 317 | Import a JSON file previously exported from Diabetes Feast. Records with the same UUID as existing data will be skipped (no duplicates). New records are added to your existing data. | |
| 318 | No file selected. | |
| 319 | Delete Backup? | |
| 320 | This cannot be undone. | |

---

### Similar Impact / What If? (SimilarImpactView)

| # | English | Japanese |
|---|---|---|
| 321 | Your Pattern with Similar Meals | |
| 322 | Searching your meal history… | |
| 323 | Planned Date & Time | |
| 324 | Eat Treat | |
| 325 | Your meal history at a glance | |
| 326 | After a week of logging meals and glucose, Diabetes Feast will match new meals to similar ones you've eaten before — so you can review how your glucose responded to those past meals and use that information however you choose. | |
| 327 | Most recent similar meal | |
| 328 | Glucose 60–120 min after eating | |
| 329 | Baseline | |
| 330 | Not enough glucose readings in this window to show a chart. | |
| 331 | Max increase over baseline | |
| 332 | Personalised exercise offset | |
| 333 | 14-day GMI trend | |
| 334 | Current GMI | |
| 335 | Log more glucose readings over the next few days to see a trend chart. | |
| 336 | Not enough glucose data yet to calculate GMI. Keep logging daily readings. | |
| 337 | Feast treats this week | |
| 338 | You have logged 3 or more feast treats this week. | |

---

### Welcome Sheet (WelcomeSheetView)

| # | English | Japanese |
|---|---|---|
| 339 | Welcome to | |
| 340 | Diabetes Feast | |
| 341 | Monitor your GMI & glucose trends, plan meals, treats, etc. | |
| 342 | Wellness App | |
| 343 | This app shows trends from your own historical data for personal wellness tracking. It is not a medical device and does not diagnose, treat, or predict health conditions. The estimated GMI is not a substitute for a laboratory HbA1c test. Always consult your healthcare provider for medical advice. | |
| 344 | Watch the Guide | |
| 345 | Get Started | |

---

### Paywall (PaywallView)

| # | English | Japanese |
|---|---|---|
| 346 | Diabetes Feast | |
| 347 | Your personal blood sugar journal | |
| 348 | Blood glucose charts and history | |
| 349 | Meal logging with GI and carb tracking | |
| 350 | Exercise session tracking | |
| 351 | Weight trend indicators | |
| 352 | GMI (Glucose Management Indicator) | |
| 353 | Export data as JSON or Excel | |
| 354 | Apple Health integration | |
| 355 | Annual Subscription | |
| 356 | after your free trial ends | |
| 357 | Start 1 Month Free Trial | |
| 358 | Cancel anytime in Settings > Apple ID > Subscriptions. | |
| 359 | Restore Purchases | |
| 360 | Privacy Policy | |
| 361 | Terms of Use | |
| 362 | Subscription Error | |

---

### Demo Data Banner (DemoDataBannerView)

| # | English | Japanese |
|---|---|---|
| 363 | Demo data | |
| 364 | — explore the app, then clear to start logging your own. | |
| 365 | Clear | |
| 366 | Clear demo data? | |
| 367 | This will remove all demo data so you can start logging your own glucose, meals, and exercise. This cannot be undone. | |

---

### Feast Mode Banner (FeastModeBannerView)

| # | English | Japanese |
|---|---|---|
| 368 | Feast Mode | |
| 369 | Planning a feast or just a special treat? Review how similar past meals appeared in your glucose and GMI trends. | |

---

### Online Food Search (OnlineFoodSearchSheet)

| # | English | Japanese |
|---|---|---|
| 370 | Online Search | |
| 371 | Close | |
| 372 | Search Online? | |
| 373 | We can look it up in the USDA nutrition database. | |
| 374 | Search Online | |
| 375 | No thanks | |
| 376 | Search Failed | |
| 377 | Please check your connection and try again. | |
| 378 | Try Again | |
| 379 | No Matches Found | |
| 380 | Try a more specific name (e.g. "chicken pad thai" instead of "pad thai"). | |
| 381 | Data: USDA FoodData Central | |
| 382 | Low | |
| 383 | Med | |
| 384 | High | |
| 385 | + Add | |
| 386 | Added | |

---

### Multi-Select Food Search (MultiSelectFoodSearchView)

#### Search / Toolbar
| # | English | Japanese |
|---|---|---|
| 387 | Search foods... | |
| 388 | Cancel | |
| 389 | Done | |
| 390 | Add Treat | |
| 391 | Add Foods | |

#### Category Chips
| # | English | Japanese |
|---|---|---|
| 392 | All | |
| 393 | My Menu | |
| 394 | Recent | |
| 395 | Asian | |
| 396 | Baked | |
| 397 | Bakery | |
| 398 | Breakfasts | |
| 399 | British | |
| 400 | Burgers/Dogs | |
| 401 | Deli | |
| 402 | European | |
| 403 | Fast | |
| 404 | Sea | |
| 405 | Frozen | |
| 406 | Grains | |
| 407 | Beans | |
| 408 | Meat | |
| 409 | Nuts | |
| 410 | Italian | |
| 411 | Noodles | |
| 412 | Oven | |
| 413 | Finger Food | |
| 414 | Sweets/Candies | |
| 415 | Soups | |
| 416 | Grills | |

#### Empty / Error States
| # | English | Japanese |
|---|---|---|
| 417 | No Meals Yet | |
| 418 | Long-press any food to add it to My Menu for quick access. | |
| 419 | No Foods Found | |
| 420 | Try a different keyword, or search online | |
| 421 | Tap a meal to add all its foods | |

---

### Planned Meal / What If? Entry (PlannedMealView)

| # | English | Japanese |
|---|---|---|
| 422 | What If? | |
| 423 | Before You Eat | |
| 424 | Build your feast treat and review your glucose and GMI trends from previous meals with similar GI, as well as how to offset it, before taking a single bite. | |
| 425 | What you'll see | |
| 426 | Your glucose history | |
| 427 | See how your glucose responded to similar meals in the past | |
| 428 | Your GMI trend | |
| 429 | Review your 14-day GMI trend alongside similar past meals | |
| 430 | Personalised exercise plan | |
| 431 | Minutes & distance for your chosen activity | |
| 432 | Compared to your typical meal | |
| 433 | Ranks this feast against your last 30 days | |
| 434 | Feast frequency is high | |
| 435 | Second feast this week | |
| 436 | Plan Feast Treat | |
| 437 | Feast Frequency Notice | |
| 438 | Continue Anyway | |

---

### Plan Meal Dashboard Card (PlanMealDashboardCard)

| # | English | Japanese |
|---|---|---|
| 439 | Next Planned Meal | |
| 440 | Plan Your Next Meal | |
| 441 | Review your glucose & GMI history before you eat | |

---

## Strings That Stay in English

These should **not** be translated:

- `"mg/dL"` and `"mmol/L"` — international medical abbreviations
- `"HbA1c"` and `"GMI"` — international medical abbreviations  
- `"GI"` and `"GL"` — international nutrition abbreviations
- `"CGM"` — international medical abbreviation
- `"USDA FoodData Central"` — proper name / attribution
- `"Apple Health"` — Apple trademark
- `"FreeStyle Libre"`, `"Dexcom"` — brand names
- `"Zukka"` — brand name
- `"Discord"`, `"WhatsApp"` — brand names
- `"BMI"` — international abbreviation
- `"HIIT"` — widely understood in Japan
- `"JSON"`, `"Excel"` — technical terms
- All URL strings
- All SF Symbol names
- All format specifiers (`%d`, `%@`, `%lld`)

---

## Notes for Translator

1. **App name** — "Diabetes Feast" should remain untranslated (brand name), though a Japanese subtitle is fine.
2. **Feast** — this is a deliberate double meaning (feast = special/indulgent meal AND feast as in celebration). Japanese should preserve this nuance if possible. Possible options: ごちそう (gochisou — feast/treat) or お楽しみ食事.
3. **"Wellness"** — ウェルネス is widely used in Japan and acceptable.
4. **Plurals** — Japanese has no grammatical plurals, so strings like "1 reading / 2 readings" simplify significantly.
5. **Formal register** — Use です/ます form (polite) throughout, appropriate for a health app.
6. **Numbers and units** — Japan uses mg/dL for glucose (same as US), so unit strings need no change.

---

*Total translatable strings: ~441 entries*  
*Strings staying in English: ~20 categories*
