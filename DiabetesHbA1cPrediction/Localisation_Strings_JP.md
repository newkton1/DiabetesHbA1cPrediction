# Diabetes Feast — Japanese Localisation String Reference

**Branch:** v2-dev  
**Purpose:** Complete list of user-facing strings with Japanese translations.  
**Status:** Translations complete — 408 unique keys in `Localizable.xcstrings`

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

## Xcode Integration Steps (one-time setup)

1. **Add Japanese language** — Xcode → Project → Info tab → Localizations → click **+** → select **Japanese**
2. **Add Localizable.xcstrings to target** — drag `Localizable.xcstrings` into the project navigator → tick **Target Membership** for DiabetesHbA1cPrediction
3. **Build & test** — switch device/simulator language to Japanese (Settings → General → Language & Region) and run

---

## Strings by Screen

### Tab Bar (ContentView)

| # | English | Japanese |
|---|---|---|
| 1 | Dashboard | ダッシュボード |
| 2 | What if? | もしも？ |
| 3 | Glucose | 血糖値 |
| 4 | Exercise | 運動 |
| 5 | User | プロフィール |

---

### Dashboard (DashboardView)

#### Navigation / Headers
| # | English | Japanese |
|---|---|---|
| 6 | Dashboard | ダッシュボード |
| 7 | Lab HbA1c Results | HbA1c検査結果 |
| 8 | Actions | アクション |

#### GMI Card
| # | English | Japanese |
|---|---|---|
| 9 | Glucose Management Indicator | 血糖管理指標（GMI） |
| 10 | Not enough recent readings to calculate GMI | GMIの計算に十分なデータがありません |
| 11 | Log at least %d glucose readings in the last %d days to update your GMI. | GMIを更新するには、過去%d日間に%d件以上の血糖値を記録してください。 |
| 12 | Log at least %d glucose readings in the last %d days to see your GMI estimate. | GMIの推定値を確認するには、過去%d日間に%d件以上の血糖値を記録してください。 |
| 13 | Your GMI estimate needs at least %d glucose readings over %d days. Keep logging daily and your first estimate will appear here automatically. | GMIの推定値には、%d日間で%d件以上の血糖値記録が必要です。毎日記録を続けると、最初の推定値が自動的に表示されます。 |
| 14 | Tap the value to recalculate · GMI is an FDA-recognized and endorsed glucose-based indicator, not a laboratory HbA1c result. | 数値をタップして再計算 · GMIはFDAが認めた血糖ベースの指標で、HbA1c検査結果ではありません。 |
| 15 | Tap to recalculate GMI | タップしてGMIを再計算 |

#### Lab HbA1c Card
| # | English | Japanese |
|---|---|---|
| 16 | Lab HbA1c | HbA1c（検査値） |
| 17 | No lab results in the last %d days | 過去%d日間の検査結果はありません |

#### Quick Stats
| # | English | Japanese |
|---|---|---|
| 18 | Glucose | 血糖値 |
| 19 | Exercise | 運動 |
| 20 | (Week) | （今週） |
| 21 | Meals History | 食事履歴 |
| 22 | User | プロフィール |

#### Action Buttons
| # | English | Japanese |
|---|---|---|
| 23 | Add Meal | 食事を記録 |
| 24 | What if? | もしも？ |
| 25 | Log what you just ate | 今食べたものを記録 |
| 26 | Plan Feast Treat | ごちそうを計画 |

#### Dawn Effect Notice
| # | English | Japanese |
|---|---|---|
| 27 | Pattern noticed: glucose readings between 4–8 AM have been consistently higher than overnight, with no meals logged beforehand. | パターン検出：前日の食事記録がないにもかかわらず、午前4〜8時の血糖値が夜間より継続的に高くなっています。 |
| 28 | This is sometimes called the "dawn effect" — a natural rise in glucose driven by hormones in the early morning. It is common in people with diabetes and does not necessarily indicate a problem. Your GMI value includes these readings as part of its standard calculation. | これは「暁現象」と呼ばれ、早朝のホルモン分泌による自然な血糖上昇です。糖尿病の方によく見られる現象で、必ずしも問題があるわけではありません。GMI値はこれらの測定値を通常の計算に含めています。 |

#### CGM Dropout Warning
| # | English | Japanese |
|---|---|---|
| 29 | No glucose data received in the last 30 minutes. Check your CGM Bluetooth connection and bridge app (e.g. Zukka). | 過去30分間、血糖データを受信していません。CGMのBluetooth接続とブリッジアプリ（例：Zukka）を確認してください。 |
| 30 | No CGM readings in 30+ min. Check your Bluetooth and bridge app (e.g. Zukka). | 30分以上CGMデータなし。Bluetooth接続とブリッジアプリ（例：Zukka）を確認してください。 |

#### Disclaimer
| # | English | Japanese |
|---|---|---|
| 31 | Diabetes Feast is a wellness app. Estimates shown are for personal tracking only — not medical diagnoses or treatment advice. | Diabetes Feastはウェルネスアプリです。表示される推定値は個人記録用であり、医療診断や治療指導ではありません。 |

#### Lab Results Sheet
| # | English | Japanese |
|---|---|---|
| 32 | No lab results to display. | 検査結果がありません。 |
| 33 | Swipe left on a result to delete it. This cannot be undone. | 結果を左にスワイプして削除できます。この操作は取り消せません。 |
| 34 | Done | 完了 |

#### 14-Day Activity Snapshot
| # | English | Japanese |
|---|---|---|
| 35 | 14-Day Activity Snapshot | 14日間の活動サマリー |
| 36 | had a post-meal exercise session logged | 食後の運動セッションを記録 |
| 37 | within | 以内 |
| 38 | 90 min | 90分 |
| 39 | after | 後 |
| 40 | 90–180 min | 90〜180分 |

---

### Getting Started Checklist (GettingStartedChecklistView)

#### Header
| # | English | Japanese |
|---|---|---|
| 41 | Getting Started | はじめに |
| 42 | Dismiss | 閉じる |

#### Step Titles & Subtitles
| # | English | Japanese |
|---|---|---|
| 43 | Log glucose readings | 血糖値を記録 |
| 44 | When no CGM readings, add your first 3 finger-stick readings | CGMデータがない場合、指先採血の測定値を3件記録してください |
| 45 | Connected to Apple Health — glucose syncs automatically | Apple Healthに接続済み — 血糖値は自動的に同期されます |
| 46 | Log your meals | 食事を記録 |
| 47 | Search or build meals from the foods you ate | 食べた食品を検索または組み合わせて食事を作成 |
| 48 | Capture post-meal glucose | 食後血糖値を記録 |
| 49 | Log a reading 1–3 hours after eating to see how meals affected your levels | 食後1〜3時間後に血糖値を記録して、食事の影響を確認しましょう |
| 50 | With CGM and meals logged, post-meal readings are captured automatically | CGMと食事の記録が揃うと、食後の血糖値は自動的に記録されます |
| 51 | Log exercise sessions | 運動セッションを記録 |
| 52 | Record walks, runs, or workouts to see how activity affected your glucose | ウォーキング、ランニング、運動を記録して血糖値への影響を確認 |
| 53 | Connected to Apple Health — workouts sync automatically | Apple Healthに接続済み — ワークアウトは自動的に同期されます |

#### Day Milestones
| # | English | Japanese |
|---|---|---|
| 54 | All steps complete — keep going! | すべてのステップ完了 — このまま続けましょう！ |
| 55 | 3 days of data | 3日分のデータ |
| 56 | Glucose trend charts are now available | 血糖値トレンドグラフが利用可能になりました |
| 57 | 7 days of data | 7日分のデータ |
| 58 | Similar-meal history is now available | 類似食事履歴が利用可能になりました |
| 59 | 14 days of data | 14日分のデータ |
| 60 | Your first GMI estimate is now available | 最初のGMI推定値が利用可能になりました |

---

### Meal Builder (MealBuilderView)

#### Navigation / Toolbar
| # | English | Japanese |
|---|---|---|
| 61 | Done | 完了 |
| 62 | Cancel | キャンセル |
| 63 | Save | 保存 |

#### Warning Overlays
| # | English | Japanese |
|---|---|---|
| 64 | High Carb Impact | 高糖質インパクト |
| 65 | This wellness feature shows exercise options based on your activity history. These are for personal tracking only — not medical diagnoses or treatment advice. | このウェルネス機能は、活動履歴に基づく運動オプションを表示します。個人記録用であり、医療診断や治療指導ではありません。 |
| 66 | Elevated Blood Glucose | 血糖値上昇 |
| 67 | Adding this food significantly increases the meal's estimated glucose impact. Some people choose to pair high-GI foods with lower-GI options. | この食品を追加すると、食事の推定血糖インパクトが大幅に増加します。高GI食品と低GI食品を組み合わせる方もいます。 |

#### Save Confirmation
| # | English | Japanese |
|---|---|---|
| 68 | Feast Saved | ごちそうを保存しました |
| 69 | Meal Saved | 食事を保存しました |
| 70 | Log glucose readings over the next 2 hours to build your historical pattern for similar meals. | 今後2時間、血糖値を記録して類似食事のパターンを蓄積しましょう。 |

#### Form Labels
| # | English | Japanese |
|---|---|---|
| 71 | Selected Foods | 選択した食品 |
| 72 | Nutrition Summary | 栄養サマリー |
| 73 | Treat Name (optional) | ごちそう名（任意） |
| 74 | Meal Name (optional) | 食事名（任意） |
| 75 | Search & Add Foods | 食品を検索して追加 |
| 76 | How long ago did you eat this meal? | この食事をいつ食べましたか？ |
| 77 | When do you plan to eat this meal? | この食事をいつ食べる予定ですか？ |
| 78 | TOTAL CARBOHYDRATES | 総炭水化物量 |
| 79 | Carb impact | 糖質インパクト |

#### Time Buttons
| # | English | Japanese |
|---|---|---|
| 80 | Now | 今 |
| 81 | 1 h | 1時間 |
| 82 | 2 h | 2時間 |
| 83 | 3 h | 3時間 |
| 84 | 24 h | 24時間 |
| 85 | 48 h | 48時間 |

#### Nutrition Labels
| # | English | Japanese |
|---|---|---|
| 86 | GL | GL |
| 87 | Carbs | 糖質 |
| 88 | Fiber | 食物繊維 |
| 89 | Protein | タンパク質 |
| 90 | Fat | 脂質 |
| 91 | Cal | カロリー |

#### Historical Pattern Section
| # | English | Japanese |
|---|---|---|
| 92 | Add foods to see your pattern with similar meals. | 食品を追加すると、類似食事のパターンが表示されます。 |
| 93 | Looking for similar meals in your history… | 類似食事を履歴から検索中… |
| 94 | Typical rise after similar meals | 類似食事後の典型的な血糖上昇 |
| 95 | Range across meals | 食事間の範囲 |
| 96 | Your lab HbA1c in this window | この期間のHbA1c検査値 |
| 97 | Carb impact of this meal | この食事の糖質インパクト |
| 98 | Not enough history yet | データが不足しています |
| 99 | Found %d similar meals, but none had enough glucose data around them to show a pattern. | %d件の類似食事が見つかりましたが、パターンを表示するのに十分な血糖データがありません。 |
| 100 | High carb impact. Some people choose smaller portions or pair with protein/fiber. | 高糖質インパクトです。少量にするか、タンパク質や食物繊維と組み合わせる方もいます。 |
| 101 | High carb impact. Lower-GI alternatives tend to produce a smaller glucose response. | 高糖質インパクトです。低GIの代替食品は血糖上昇が少ない傾向があります。 |
| 102 | Very high carb feast. Some people find a post-meal walk helpful after meals like this. | 非常に高糖質のごちそうです。この種の食事の後、食後ウォーキングが効果的な方もいます。 |

---

### Meal Log (MealLogView)

#### Navigation
| # | English | Japanese |
|---|---|---|
| 103 | Meals | 食事 |
| 104 | Save Error | 保存エラー |

#### Empty State
| # | English | Japanese |
|---|---|---|
| 105 | See how meals have affected your glucose | 食事が血糖値にどう影響したかを確認 |
| 106 | Once you've logged meals alongside glucose readings, Diabetes Feast will show you which foods raised your levels — and by how much. Start by logging a meal and checking your glucose before and after eating. | 食事と血糖値を記録すると、Diabetes Feastがどの食品がどれだけ血糖値を上げたかを表示します。まず食事を記録し、食前・食後の血糖値を測定してみましょう。 |
| 107 | Log glucose | 血糖値を記録 |
| 108 | Log a meal | 食事を記録 |
| 109 | Wait 2 hours | 2時間待つ |
| 110 | Log glucose again | 再度血糖値を記録 |

#### Section Headers / Row Labels
| # | English | Japanese |
|---|---|---|
| 111 | Today | 今日 |
| 112 | Yesterday | 昨日 |
| 113 | Tomorrow | 明日 |
| 114 | Meal | 食事 |
| 115 | Food Items: | 食品： |
| 116 | Unknown | 不明 |
| 117 | Carbs | 糖質 |
| 118 | Fiber | 食物繊維 |
| 119 | Proteins | タンパク質 |
| 120 | Fats | 脂質 |

#### Context Menu
| # | English | Japanese |
|---|---|---|
| 121 | Delete | 削除 |
| 122 | Remove from My Menu | マイメニューから削除 |
| 123 | Add to My Menu | マイメニューに追加 |

#### Error
| # | English | Japanese |
|---|---|---|
| 124 | Could not delete meal. Please try again. | 食事を削除できませんでした。もう一度お試しください。 |

---

### Food Search (FoodSearchView)

| # | English | Japanese |
|---|---|---|
| 125 | Search Foods | 食品を検索 |
| 126 | Close | 閉じる |
| 127 | Search foods | 食品を検索 |
| 128 | Food Database Error | 食品データベースエラー |
| 129 | The food database could not be loaded. | 食品データベースを読み込めませんでした。 |
| 130 | No Foods Found | 食品が見つかりません |
| 131 | Try searching with a different keyword | 別のキーワードで検索してみてください |
| 132 | Search Online | オンライン検索 |
| 133 | Low | 低 |
| 134 | Medium | 中 |
| 135 | High | 高 |

---

### Glucose Log (GlucoseLogView)

#### Navigation / Toolbar
| # | English | Japanese |
|---|---|---|
| 136 | Glucose | 血糖値 |
| 137 | Sync | 同期 |
| 138 | Add Reading | 測定値を追加 |

#### Alert Messages
| # | English | Japanese |
|---|---|---|
| 139 | Sync Status | 同期状態 |
| 140 | Save Error | 保存エラー |
| 141 | HealthKit Error | HealthKitエラー |
| 142 | HealthKit could not be authorized. Check Settings > Health > Data Access & Devices. | HealthKitを認証できませんでした。設定 > ヘルスケア > データアクセスとデバイスを確認してください。 |
| 143 | Confirm Lab Result | 検査結果の確認 |
| 144 | Is this HbA1c value from a lab blood test? Do NOT enter CGM estimate — this app's estimates require actual lab results. | この値は血液検査によるHbA1cですか？CGMの推定値は入力しないでください — このアプリの推定には実際の検査結果が必要です。 |
| 145 | Yes, it's a lab result | はい、検査値です |
| 146 | Cancel | キャンセル |

#### Chart Controls
| # | English | Japanese |
|---|---|---|
| 147 | Now | 今 |
| 148 | 1d | 1日 |
| 149 | 3d | 3日 |
| 150 | 7d | 7日 |
| 151 | Tap a highlighted point to see meal and exercise details | ハイライトされたポイントをタップして食事・運動の詳細を確認 |
| 152 | No glucose readings in the last %d days | 過去%d日間の血糖値記録はありません |
| 153 | Try last 7 days | 過去7日間を表示 |

#### Readings List
| # | English | Japanese |
|---|---|---|
| 154 | Unknown | 不明 |
| 155 | Finger Stick | 指先採血 |
| 156 | CGM | CGM |
| 157 | Delete | 削除 |
| 158 | Could not delete reading. Please try again. | 測定値を削除できませんでした。もう一度お試しください。 |

#### Hotspot Popover
| # | English | Japanese |
|---|---|---|
| 159 | %@ from baseline | ベースラインから%@ |
| 160 | Above 170 mg/dL threshold | 170 mg/dL閾値超過 |
| 161 | Returning to baseline | ベースラインに戻っています |
| 162 | No meal logged | 食事の記録なし |
| 163 | Carbs %d g | 糖質 %d g |
| 164 | No exercise logged | 運動の記録なし |
| 165 | %d min before | %d分前 |
| 166 | %d min after | %d分後 |

#### Add Reading Form
| # | English | Japanese |
|---|---|---|
| 167 | Glucose Reading | 血糖値測定 |
| 168 | HbA1c Lab Result | HbA1c検査値 |
| 169 | Unit System | 単位系 |
| 170 | mg/dL (US/Japan) | mg/dL（米国・日本） |
| 171 | mmol/L (Europe/World) | mmol/L（欧州・世界） |
| 172 | Glucose Value | 血糖値 |
| 173 | Enter value | 値を入力 |
| 174 | Source | 測定方法 |
| 175 | Manual Finger Stick | 指先採血（手動） |
| 176 | Continuous Glucose Monitor | 持続血糖モニター（CGM） |
| 177 | Trend | トレンド |
| 178 | Timestamp | 日時 |
| 179 | Time | 時刻 |
| 180 | Auto-detected from your region (%@). Override if your lab report uses a different standard. | お住まいの地域から自動検出（%@）。検査報告書が異なる規格を使用している場合は変更できます。 |
| 181 | Enter lab result | 検査値を入力 |
| 182 | Value out of clinical range | 値が臨床範囲外です |
| 183 | Lab Test Date | 検査日 |
| 184 | Could not save glucose reading. Please try again. | 血糖値を保存できませんでした。もう一度お試しください。 |
| 185 | Could not save HbA1c lab result. Please try again. | HbA1c検査値を保存できませんでした。もう一度お試しください。 |

#### Sync Status Messages
| # | English | Japanese |
|---|---|---|
| 186 | HealthKit authorization denied. Please enable access in Settings > Health > Data Access & Devices. | HealthKitの認証が拒否されました。設定 > ヘルスケア > データアクセスとデバイスでアクセスを有効にしてください。 |
| 187 | Sync encountered an error: %@ | 同期中にエラーが発生しました：%@ |
| 188 | Sync completed successfully! Imported %d new glucose reading(s) from HealthKit. | 同期が完了しました！HealthKitから%d件の新しい血糖値をインポートしました。 |
| 189 | Sync completed. Your glucose readings are already up to date. | 同期が完了しました。血糖値は最新の状態です。 |
| 190 | Sync completed. No glucose readings found in HealthKit for the last 30 days. | 同期が完了しました。過去30日間のHealthKitに血糖値が見つかりませんでした。 |

---

### Exercise Log (ExerciseLogView)

#### Navigation
| # | English | Japanese |
|---|---|---|
| 191 | Exercise Log | 運動記録 |

#### Alerts
| # | English | Japanese |
|---|---|---|
| 192 | Delete Exercise | 運動を削除 |
| 193 | Are you sure you want to delete this exercise session? | この運動セッションを削除してもよろしいですか？ |
| 194 | Delete | 削除 |
| 195 | Cancel | キャンセル |

#### Summary Card
| # | English | Japanese |
|---|---|---|
| 196 | Last 7 Days Summary | 過去7日間のサマリー |
| 197 | Full Exercise Log | 運動記録一覧 |
| 198 | No Exercise Sessions | 運動セッションがありません |
| 199 | Add your first workout or sync from Health | 最初のワークアウトを追加するか、HealthKitから同期してください |
| 200 | Time | 時刻 |
| 201 | Energy | エネルギー |
| 202 | Sessions | セッション数 |
| 203 | Intensity | 強度 |

#### Add Exercise Sheet
| # | English | Japanese |
|---|---|---|
| 204 | Add Exercise Session | 運動セッションを追加 |
| 205 | Exercise Type | 運動の種類 |
| 206 | Walking | ウォーキング |
| 207 | Running | ランニング |
| 208 | Cycling | サイクリング |
| 209 | Swimming | 水泳 |
| 210 | Strength Training | 筋力トレーニング |
| 211 | Yoga | ヨガ |
| 212 | HIIT | HIIT |
| 213 | Dancing | ダンス |
| 214 | Hiking | ハイキング |
| 215 | Gardening | 園芸 |
| 216 | Other | その他 |
| 217 | Start Time | 開始時刻 |
| 218 | Duration | 時間 |
| 219 | Distance | 距離 |
| 220 | Intensity (1-10) | 強度（1〜10） |
| 221 | Calories Burned | 消費カロリー |
| 222 | Use Estimated Value | 推定値を使用 |
| 223 | Notes | メモ |
| 224 | Could not save exercise session. Please try again. | 運動セッションを保存できませんでした。もう一度お試しください。 |

#### Sync Messages
| # | English | Japanese |
|---|---|---|
| 225 | Sync completed. No new data found in HealthKit for the last 30 days. | 同期が完了しました。過去30日間のHealthKitに新しいデータが見つかりませんでした。 |
| 226 | Could not delete exercise. Please try again. | 運動を削除できませんでした。もう一度お試しください。 |

---

### User Profile (UserProfileView)

#### Section Headers
| # | English | Japanese |
|---|---|---|
| 227 | Personal Information | 個人情報 |
| 228 | Health Conditions | 健康状態 |
| 229 | About | アプリについて |
| 230 | Settings | 設定 |
| 231 | Share | 共有 |
| 232 | Data Management | データ管理 |
| 233 | Demo Data | デモデータ |

#### Personal Information
| # | English | Japanese |
|---|---|---|
| 234 | Age | 年齢 |
| 235 | Sex | 性別 |
| 236 | Male | 男性 |
| 237 | Female | 女性 |
| 238 | Other | その他 |
| 239 | Height (cm) | 身長（cm） |
| 240 | Height (ft-in) | 身長（フィート-インチ） |
| 241 | Weight (kg) | 体重（kg） |
| 242 | Weight (lbs) | 体重（ポンド） |

#### Health Conditions
| # | English | Japanese |
|---|---|---|
| 243 | Diabetes | 糖尿病 |
| 244 | Diabetes Type | 糖尿病の種類 |
| 245 | Type 1 | 1型 |
| 246 | Type 2 | 2型 |
| 247 | Gestational | 妊娠糖尿病 |
| 248 | This app is NOT for Type 1 diabetics or anyone using insulin bolus therapy. It does not calculate insulin dosage and must not be used for that purpose. | このアプリは1型糖尿病の方やインスリンボーラス療法を使用している方には対応していません。インスリン用量の計算は行わず、その目的での使用は禁止されています。 |
| 249 | COPD | COPD |
| 250 | Heart Disease | 心臓病 |
| 251 | Tobacco Use | 喫煙状況 |
| 252 | Never | 非喫煙 |
| 253 | Former | 元喫煙者 |
| 254 | Current | 現在喫煙中 |
| 255 | Alcohol Units/Week | 飲酒量（週あたり） |

#### Settings / About
| # | English | Japanese |
|---|---|---|
| 256 | BMI | BMI |
| 257 | N/A | 該当なし |
| 258 | Underweight | 低体重 |
| 259 | Normal | 普通体重 |
| 260 | Overweight | 過体重 |
| 261 | Obese | 肥満 |
| 262 | Offset Exercise | 運動オフセット |
| 263 | HbA1c Units | HbA1c単位 |
| 264 | Weight Units | 体重単位 |
| 265 | Height Units | 身長単位 |
| 266 | Version | バージョン |

#### Actions
| # | English | Japanese |
|---|---|---|
| 267 | Quick GMI Text Summary | GMIテキストサマリー |
| 268 | Export All Data | 全データをエクスポート |
| 269 | Import Data from JSON | JSONからデータをインポート |
| 270 | Load Demo Data | デモデータを読み込む |
| 271 | Wipe All Data | 全データを消去 |
| 272 | Watch Onboarding Guide | スタートガイドを見る |
| 273 | Join the Discord Community | Discordコミュニティに参加 |
| 274 | Requires free Discord app for iPhone. Community can also be accessed on desktop from a browser. | iPhoneの無料Discordアプリが必要です。デスクトップからブラウザでもアクセスできます。 |
| 275 | Join the WhatsApp Community | WhatsAppコミュニティに参加 |
| 276 | Requires free WhatsApp app for iPhone. | iPhoneの無料WhatsAppアプリが必要です。 |
| 277 | Privacy Policy | プライバシーポリシー |
| 278 | Save | 保存 |
| 279 | Done | 完了 |

#### Alerts
| # | English | Japanese |
|---|---|---|
| 280 | Validation Error | 入力エラー |
| 281 | Profile Saved | プロフィールを保存しました |
| 282 | Your profile has been saved successfully. | プロフィールが正常に保存されました。 |
| 283 | Share Health Data? | 健康データを共有しますか？ |
| 284 | This will share your glucose and GMI data with a third party of your choosing (e.g. email, messaging app). This export contains sensitive personal health information. Are you sure you want to continue? | 血糖値とGMIデータを選択した相手（メール、メッセージアプリなど）と共有します。このエクスポートには個人の健康情報が含まれています。続行しますか？ |
| 285 | Export Health Data? | 健康データをエクスポートしますか？ |
| 286 | The export screen contains all your health data including glucose readings, meals, exercise sessions, and your personal profile. This data is sensitive — only share it with people you trust. | エクスポート画面には、血糖値、食事、運動セッション、個人プロフィールなど、すべての健康データが含まれます。このデータは機密性が高いため、信頼できる方にのみ共有してください。 |
| 287 | Continue | 続行 |
| 288 | Wipe All Data? | 全データを消去しますか？ |
| 289 | This will permanently delete all data including glucose readings, meals, exercise sessions, and GMI estimates. This cannot be undone. | 血糖値、食事、運動セッション、GMI推定値を含むすべてのデータが完全に削除されます。この操作は取り消せません。 |
| 290 | Wipe | 消去 |
| 291 | Data Wiped | データを消去しました |
| 292 | Demo Data Loaded | デモデータを読み込みました |

#### Validation Errors
| # | English | Japanese |
|---|---|---|
| 293 | Age must be between 1 and 120 years. | 年齢は1〜120歳の範囲で入力してください。 |
| 294 | Height must be between 50 and 250 cm. | 身長は50〜250cmの範囲で入力してください。 |
| 295 | Weight must be between 20 and 300 kg. | 体重は20〜300kgの範囲で入力してください。 |
| 296 | Weight must be between 44 and 660 lbs. | 体重は44〜660ポンドの範囲で入力してください。 |
| 297 | Please fill in all required fields. | 必須項目をすべて入力してください。 |

---

### Data Export (DataExportView)

| # | English | Japanese |
|---|---|---|
| 298 | Export Data | データをエクスポート |
| 299 | Data Summary | データサマリー |
| 300 | Export | エクスポート |
| 301 | Glucose Readings | 血糖値測定記録 |
| 302 | Meals | 食事記録 |
| 303 | Exercise Sessions | 運動セッション |
| 304 | GMI Estimates | GMI推定値 |
| 305 | User Profiles | ユーザープロフィール |
| 306 | Health Conditions | 健康状態 |
| 307 | Export All Data as JSON | 全データをJSONでエクスポート |
| 308 | Export for Doctor (Excel) | 医師用レポート（Excel） |
| 308b | Export for Doctor (HTML) *(v2-dev new)* | 医師用レポート（HTML） |
| 309 | Exports all app data as a single JSON file suitable for validation evidence or Apple Review submission. No data leaves the device until you choose where to share it. | 全データを1つのJSONファイルとしてエクスポートします。共有先を選択するまでデータはデバイス外に出ません。 |

---

### Data Import (DataImportView)

| # | English | Japanese |
|---|---|---|
| 310 | Import Data | データをインポート |
| 311 | Choose JSON File to Import | JSONファイルを選択 |
| 312 | Importing… | インポート中… |
| 313 | Import Summary | インポートサマリー |
| 314 | Warnings | 警告 |
| 315 | Total imported | 合計インポート数 |
| 316 | Already existed (skipped) | 既存データ（スキップ） |
| 317 | Import a JSON file previously exported from Diabetes Feast. Records with the same UUID as existing data will be skipped (no duplicates). New records are added to your existing data. | Diabetes Feastから以前エクスポートしたJSONファイルをインポートします。既存データと同じUUIDのレコードはスキップされます（重複なし）。新しいレコードは既存データに追加されます。 |
| 318 | No file selected. | ファイルが選択されていません。 |
| 319 | Delete Backup? | バックアップを削除しますか？ |
| 320 | This cannot be undone. | この操作は取り消せません。 |

---

### Similar Impact / What If? (SimilarImpactView)

| # | English | Japanese |
|---|---|---|
| 321 | Your Pattern with Similar Meals | 類似食事のパターン |
| 322 | Searching your meal history… | 食事履歴を検索中… |
| 323 | Planned Date & Time | 予定日時 |
| 324 | Eat Treat | ごちそうを食べる |
| 325 | Your meal history at a glance | 食事履歴の概要 |
| 326 | After a week of logging meals and glucose, Diabetes Feast will match new meals to similar ones you've eaten before — so you can review how your glucose responded to those past meals and use that information however you choose. | 1週間、食事と血糖値を記録すると、Diabetes Feastが新しい食事を過去の類似食事と照合します。過去の食事での血糖値の反応を確認し、参考にすることができます。 |
| 327 | Most recent similar meal | 最も最近の類似食事 |
| 328 | Glucose 60–120 min after eating | 食後60〜120分の血糖値 |
| 329 | Baseline | ベースライン |
| 330 | Not enough glucose readings in this window to show a chart. | このウィンドウにグラフを表示するのに十分な血糖値データがありません。 |
| 331 | Max increase over baseline | ベースラインからの最大上昇 |
| 332 | Personalised exercise offset | 個人化された運動オフセット |
| 333 | 14-day GMI trend | 14日間のGMIトレンド |
| 334 | Current GMI | 現在のGMI |
| 335 | Log more glucose readings over the next few days to see a trend chart. | トレンドグラフを表示するには、今後数日間、血糖値を記録し続けてください。 |
| 336 | Not enough glucose data yet to calculate GMI. Keep logging daily readings. | GMIを計算するのに十分な血糖データがまだありません。毎日の記録を続けてください。 |
| 337 | Feast treats this week | 今週のごちそう |
| 338 | You have logged 3 or more feast treats this week. | 今週3件以上のごちそうを記録しました。 |

---

### Welcome Sheet (WelcomeSheetView)

| # | English | Japanese |
|---|---|---|
| 339 | Welcome to | ようこそ |
| 340 | Diabetes Feast | Diabetes Feast |
| 341 | Monitor your GMI & glucose trends, plan meals, treats, etc. | GMIと血糖トレンドを管理し、食事やごちそうを計画しましょう。 |
| 342 | Wellness App | ウェルネスアプリ |
| 343 | This app shows trends from your own historical data for personal wellness tracking. It is not a medical device and does not diagnose, treat, or predict health conditions. The estimated GMI is not a substitute for a laboratory HbA1c test. Always consult your healthcare provider for medical advice. | このアプリは個人のウェルネス管理のために、ご自身の履歴データからトレンドを表示します。医療機器ではなく、健康状態の診断、治療、予測は行いません。推定GMIは血液検査によるHbA1cの代替ではありません。医療アドバイスは必ず医療専門家にご相談ください。 |
| 344 | Watch the Guide | ガイドを見る |
| 345 | Get Started | 始める |

---

### Paywall (PaywallView)

| # | English | Japanese |
|---|---|---|
| 346 | Diabetes Feast | Diabetes Feast |
| 347 | Your personal blood sugar journal | あなたの血糖管理日記 |
| 348 | Blood glucose charts and history | 血糖値グラフと履歴 |
| 349 | Meal logging with GI and carb tracking | GIと糖質の食事記録 |
| 350 | Exercise session tracking | 運動セッション記録 |
| 351 | Weight trend indicators | 体重トレンド指標 |
| 352 | GMI (Glucose Management Indicator) | GMI（血糖管理指標） |
| 353 | Export data as JSON or Excel | JSONまたはExcelでデータをエクスポート |
| 354 | Apple Health integration | Apple Health連携 |
| 355 | Annual Subscription | 年間サブスクリプション |
| 356 | after your free trial ends | 無料トライアル終了後 |
| 357 | Start 1 Month Free Trial | 1ヶ月無料トライアルを開始 |
| 358 | Cancel anytime in Settings > Apple ID > Subscriptions. | 設定 > Apple ID > サブスクリプションからいつでもキャンセルできます。 |
| 359 | Restore Purchases | 購入を復元 |
| 360 | Privacy Policy | プライバシーポリシー |
| 361 | Terms of Use | 利用規約 |
| 362 | Subscription Error | サブスクリプションエラー |

---

### Demo Data Banner (DemoDataBannerView)

| # | English | Japanese |
|---|---|---|
| 363 | Demo data | デモデータ |
| 364 | — explore the app, then clear to start logging your own. | — アプリを体験後、クリアして自分のデータを記録できます。 |
| 365 | Clear | クリア |
| 366 | Clear demo data? | デモデータをクリアしますか？ |
| 367 | This will remove all demo data so you can start logging your own glucose, meals, and exercise. This cannot be undone. | すべてのデモデータが削除され、自分の血糖値、食事、運動を記録できるようになります。この操作は取り消せません。 |

---

### Feast Mode Banner (FeastModeBannerView)

| # | English | Japanese |
|---|---|---|
| 368 | Feast Mode | ごちそうモード |
| 369 | Planning a feast or just a special treat? Review how similar past meals appeared in your glucose and GMI trends. | ごちそうや特別なお食事を計画中ですか？過去の類似食事が血糖値とGMIトレンドにどう影響したか確認しましょう。 |

---

### Online Food Search (OnlineFoodSearchSheet)

| # | English | Japanese |
|---|---|---|
| 370 | Online Search | オンライン検索 |
| 371 | Close | 閉じる |
| 372 | Search Online? | オンラインで検索しますか？ |
| 373 | We can look it up in the USDA nutrition database. | USDA栄養データベースで検索できます。 |
| 374 | Search Online | オンライン検索 |
| 375 | No thanks | いいえ |
| 376 | Search Failed | 検索失敗 |
| 377 | Please check your connection and try again. | 接続を確認してもう一度お試しください。 |
| 378 | Try Again | もう一度試す |
| 379 | No Matches Found | 一致する食品が見つかりません |
| 380 | Try a more specific name (e.g. "chicken pad thai" instead of "pad thai"). | より具体的な名前で検索してください（例：「pad thai」の代わりに「chicken pad thai」）。 |
| 381 | Data: USDA FoodData Central | データ：USDA FoodData Central |
| 382 | Low | 低 |
| 383 | Med | 中 |
| 384 | High | 高 |
| 385 | + Add | ＋追加 |
| 386 | Added | 追加済み |

---

### Multi-Select Food Search (MultiSelectFoodSearchView)

#### Search / Toolbar
| # | English | Japanese |
|---|---|---|
| 387 | Search foods... | 食品を検索... |
| 388 | Cancel | キャンセル |
| 389 | Done | 完了 |
| 390 | Add Treat | ごちそうを追加 |
| 391 | Add Foods | 食品を追加 |

#### Category Chips
| # | English | Japanese |
|---|---|---|
| 392 | All | すべて |
| 393 | My Menu | マイメニュー |
| 394 | Recent | 最近 |
| 395 | Asian | アジア料理 |
| 396 | Baked | 焼き物 |
| 397 | Bakery | パン・菓子 |
| 398 | Breakfasts | 朝食 |
| 399 | British | イギリス料理 |
| 400 | Burgers/Dogs | バーガー・ドッグ |
| 401 | Deli | デリ |
| 402 | European | ヨーロッパ料理 |
| 403 | Fast | ファストフード |
| 404 | Sea | 海鮮 |
| 405 | Frozen | 冷凍食品 |
| 406 | Grains | 穀物 |
| 407 | Beans | 豆類 |
| 408 | Meat | 肉類 |
| 409 | Nuts | ナッツ |
| 410 | Italian | イタリア料理 |
| 411 | Noodles | 麺類 |
| 412 | Oven | オーブン料理 |
| 413 | Finger Food | フィンガーフード |
| 414 | Sweets/Candies | お菓子 |
| 415 | Soups | スープ |
| 416 | Grills | グリル料理 |

#### Empty / Error States
| # | English | Japanese |
|---|---|---|
| 417 | No Meals Yet | 食事がまだありません |
| 418 | Long-press any food to add it to My Menu for quick access. | 食品を長押しするとマイメニューに追加できます。 |
| 419 | No Foods Found | 食品が見つかりません |
| 420 | Try a different keyword, or search online | 別のキーワードで検索するか、オンライン検索をお試しください |
| 421 | Tap a meal to add all its foods | 食事をタップするとすべての食品が追加されます |

---

### Planned Meal / What If? Entry (PlannedMealView)

| # | English | Japanese |
|---|---|---|
| 422 | What If? | もしも？ |
| 423 | Before You Eat | 食べる前に |
| 424 | Build your feast treat and review your glucose and GMI trends from previous meals with similar GI, as well as how to offset it, before taking a single bite. | 一口食べる前に、ごちそうを作成して、GIが類似した過去の食事の血糖値とGMIトレンド、および運動でのオフセット方法を確認しましょう。 |
| 425 | What you'll see | 確認できること |
| 426 | Your glucose history | 血糖値履歴 |
| 427 | See how your glucose responded to similar meals in the past | 過去の類似食事で血糖値がどう反応したかを確認 |
| 428 | Your GMI trend | GMIトレンド |
| 429 | Review your 14-day GMI trend alongside similar past meals | 類似食事と14日間のGMIトレンドを確認 |
| 430 | Personalised exercise plan | 個人化された運動プラン |
| 431 | Minutes & distance for your chosen activity | 選択した活動の時間と距離 |
| 432 | Compared to your typical meal | 普段の食事との比較 |
| 433 | Ranks this feast against your last 30 days | 過去30日間のデータとこのごちそうを比較 |
| 434 | Feast frequency is high | ごちそうの頻度が高い |
| 435 | Second feast this week | 今週2回目のごちそう |
| 436 | Plan Feast Treat | ごちそうを計画 |
| 437 | Feast Frequency Notice | ごちそう頻度のお知らせ |
| 438 | Continue Anyway | このまま続ける |

---

### Plan Meal Dashboard Card (PlanMealDashboardCard)

| # | English | Japanese |
|---|---|---|
| 439 | Next Planned Meal | 次の予定食事 |
| 440 | Plan Your Next Meal | 次の食事を計画 |
| 441 | Review your glucose & GMI history before you eat | 食べる前に血糖値とGMIの履歴を確認 |

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

## Translation Notes

1. **App name** — "Diabetes Feast" remains untranslated (brand name)
2. **Feast** — translated as **ごちそう** (gochisou — a feast, a special/celebratory meal). Feast Mode = ごちそうモード; Feast Saved = ごちそうを保存しました; Plan Feast Treat = ごちそうを計画
3. **Wellness** — ウェルネス (widely understood in Japan)
4. **Plurals** — Japanese has no grammatical plurals; format strings with %d work naturally (e.g. "3件" for 3 items)
5. **Formal register** — です/ます form used throughout
6. **Units** — Japan uses mg/dL (same as US); no unit changes needed
7. **暁現象** — correct Japanese clinical term for "dawn effect"
8. **持続血糖モニター** — standard Japanese term for CGM
9. **指先採血** — standard Japanese term for finger-stick blood glucose test

---

## xcstrings File Notes

- **File:** `Localizable.xcstrings` (String Catalog, Xcode 15+)
- **Total unique keys:** 408 (some English strings appear in multiple screens but only one entry needed per unique string)
- **Format:** JSON, UTF-8, `sourceLanguage: "en"`, translations under `"ja"` locale
- **Format strings:** `%d`, `%@`, `%lld` preserved as-is — Japanese word order accommodated in translation
