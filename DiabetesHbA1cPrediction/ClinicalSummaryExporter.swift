//
//  ClinicalSummaryExporter.swift
//  DiabetesHbA1cPrediction
//
//  Generates a self-contained HTML clinical summary for sharing with a doctor.
//  Produces a 6-panel scrollable document covering the last 3 months of CGM,
//  meal, and exercise data, rendered via Chart.js in any web browser.
//

import Foundation
import CoreData

struct ClinicalSummaryExporter {

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case encodingFailed
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:       return "Failed to encode panel data as JSON."
            case .writeFailed(let e):   return "Failed to write HTML file: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Public Entry Point

    /// Generates the 3-month scrollable HTML and returns a URL to a temp file.
    /// Call from the main thread (or wrap the Core Data access yourself).
    static func generateHTML(
        glucoseReadings: [GlucoseReadingEntity],
        meals:           [MealEntity],
        exercises:       [ExerciseSessionEntity],
        predictions:     [GmiEstimateEntity],
        userProfiles:    [UserDemographicsEntity]
    ) throws -> URL {

        // CGM / fingerstick only — exclude "Hospital Lab Test" HbA1c rows
        let cgm = glucoseReadings.filter { $0.source != "Hospital Lab Test" }

        let panels = buildPanels(glucose: cgm, meals: meals, exercises: exercises)

        // ── Overall 3-month stats ─────────────────────────────────────────
        let allVals = panels.flatMap { $0.glucoseData.map { Double($0.y) } }
        let ovAvg   = allVals.isEmpty ? 0.0 : allVals.reduce(0, +) / Double(allVals.count)
        let ovTir   = allVals.isEmpty ? 0   : Int(round(
            Double(allVals.filter { $0 >= 70 && $0 <= 180 }.count) / Double(allVals.count) * 100))
        let ovGmi   = allVals.isEmpty ? 0.0 : (round((3.31 + 0.02392 * ovAvg) * 10) / 10)
        let ovPeak  = allVals.map { Int($0) }.max() ?? 0
        _ = allVals.map { Int($0) }.min() ?? 0   // ovLow unused; suppress warning
        let ovMeals = panels.reduce(0) { $0 + $1.stats.meals }
        let ovEx    = panels.reduce(0) { $0 + $1.stats.exercise }

        // Most recent Bergenstal GMI from stored predictions
        let labGmi  = predictions
            .filter { $0.modelVersion == "Bergenstal2018-NGSP" }
            .sorted { ($0.predictionDate ?? .distantPast) < ($1.predictionDate ?? .distantPast) }
            .last.map { round($0.predictedValue * 10) / 10 } ?? ovGmi

        // ── Encode panels ─────────────────────────────────────────────────
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let panelsData = try encoder.encode(panels)
        guard let panelsJSON = String(data: panelsData, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }

        // ── Generate HTML ─────────────────────────────────────────────────
        let html = htmlString(
            panelsJSON:  panelsJSON,
            dateRange:   dateRangeLabel(panels: panels),
            patientInfo: formatPatientInfo(profiles: userProfiles),
            ovAvg:    String(format: "%.1f", ovAvg),
            ovTir:    "\(ovTir)",
            ovGmi:    String(format: "%.1f", ovGmi),
            labGmi:   String(format: "%.1f", labGmi),
            ovPeak:   "\(ovPeak)",
            ovMeals:  "\(ovMeals)",
            ovEx:     "\(ovEx)",
            tirColor: ovTir >= 70 ? "#27ae60" : "#e74c3c"
        )

        // ── Write to temp file ────────────────────────────────────────────
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmm"
        let filename = "DiabetesFeast_ClinicalSummary_\(df.string(from: Date())).html"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailed(error)
        }
        return url
    }

    // MARK: - Panel Building

    private static func buildPanels(
        glucose:   [GlucoseReadingEntity],
        meals:     [MealEntity],
        exercises: [ExerciseSessionEntity]
    ) -> [PanelJSON] {

        let tz  = TimeZone.current
        var cal = Calendar.current
        cal.timeZone = tz

        // Exclusive upper bound = midnight at start of tomorrow (local tz)
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        let todayMidnight = cal.date(from: comps)!
        let upper = cal.date(byAdding: .day, value: 1, to: todayMidnight)!

        return (0..<6).map { i in
            let panelEnd   = cal.date(byAdding: .day, value: -14 * i,       to: upper)!
            let panelStart = cal.date(byAdding: .day, value: -14 * (i + 1), to: upper)!
            return buildOnePanel(start: panelStart, end: panelEnd,
                                 glucose: glucose, meals: meals, exercises: exercises,
                                 tz: tz, cal: cal)
        }
    }

    private static func buildOnePanel(
        start:     Date,
        end:       Date,
        glucose:   [GlucoseReadingEntity],
        meals:     [MealEntity],
        exercises: [ExerciseSessionEntity],
        tz:        TimeZone,
        cal:       Calendar
    ) -> PanelJSON {

        let startMs = msFromDate(start)
        let endMs   = msFromDate(end)

        // ── Glucose points ────────────────────────────────────────────────
        let gPts: [PanelJSON.GlucosePoint] = glucose.compactMap { r in
            guard let ts = r.timestamp, ts >= start, ts < end else { return nil }
            var val = r.value
            if (r.unit ?? "").contains("mmol") { val *= 18.0182 }   // mmol/L → mg/dL
            return .init(x: msFromDate(ts), y: Int(val.rounded()))
        }.sorted { $0.x < $1.x }

        // ── Meals ─────────────────────────────────────────────────────────
        var mealGreen:  [PanelJSON.MealBubble] = []
        var mealYellow: [PanelJSON.MealBubble] = []
        var mealRed:    [PanelJSON.MealBubble] = []
        var mealCount = 0

        for meal in meals {
            guard let ts = meal.timestamp, ts >= start, ts < end else { continue }
            mealCount += 1
            let items  = (meal.foodItems as? Set<MealFoodItemEntity>) ?? []
            let carbs  = items.reduce(0.0) { $0 + $1.carbsPerServing * $1.quantity }
            let foods  = items.compactMap { $0.foodName }.sorted().joined(separator: ", ")
            let bubble = PanelJSON.MealBubble(
                x:        msFromDate(ts),
                y:        0,    // positioned dynamically in JS
                r:        min(max(5.0, 5.0 + carbs / 4.0), 19.0),
                carbs:    (carbs * 10).rounded() / 10,
                name:     meal.name ?? "Meal",
                calories: Int(meal.calories.rounded()),
                foods:    foods
            )
            if carbs < 30      { mealGreen.append(bubble) }
            else if carbs < 60 { mealYellow.append(bubble) }
            else               { mealRed.append(bubble) }
        }

        // ── Exercise bars ─────────────────────────────────────────────────
        var exBars:  [PanelJSON.ExerciseBar] = []
        var exCount = 0

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "M/d HH:mm"
        timeFmt.timeZone   = tz
        let tzLabel = tz.abbreviation() ?? tz.identifier

        for ex in exercises {
            guard let exStart = ex.startDate, let exEnd = ex.endDate,
                  exStart < end, exEnd > start else { continue }
            exCount += 1
            let x1   = max(msFromDate(exStart), startMs)
            let x2   = min(msFromDate(exEnd),   endMs)
            exBars.append(.init(
                x1:           x1,
                x2:           x2,
                xMid:         (x1 + x2) / 2,
                startLabel:   "\(timeFmt.string(from: exStart)) \(tzLabel)",
                exerciseType: ex.type ?? "Walking",
                duration:     Int(ex.duration.rounded()),
                calories:     Int(ex.caloriesBurned.rounded()),
                distance:     (ex.distance * 100).rounded() / 100,
                steps:        extractSteps(from: ex.notes)
            ))
        }

        // ── Day ticks (midnight local) ────────────────────────────────────
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "MMM d"
        dayFmt.timeZone   = tz
        var ticks: [PanelJSON.DayTick] = []
        var d = start
        while d < end {
            ticks.append(.init(ms: msFromDate(d), label: dayFmt.string(from: d)))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        // ── Panel label ───────────────────────────────────────────────────
        let startFmt = DateFormatter(); startFmt.dateFormat = "MMM d";  startFmt.timeZone = tz
        let endFmt   = DateFormatter(); endFmt.dateFormat   = "MMM d, yyyy"; endFmt.timeZone = tz
        let lastSec  = cal.date(byAdding: .second, value: -1, to: end)!
        let label    = "\(startFmt.string(from: start)) – \(endFmt.string(from: lastSec))"

        return PanelJSON(
            label:        label,
            startMs:      startMs,
            endMs:        endMs,
            glucoseData:  gPts,
            mealGreen:    mealGreen,
            mealYellow:   mealYellow,
            mealRed:      mealRed,
            exerciseData: exBars,
            dayTicks:     ticks,
            stats:        computeStats(vals: gPts.map { Double($0.y) },
                                       mealCount: mealCount, exCount: exCount)
        )
    }

    // MARK: - Helpers

    private static func msFromDate(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private static func computeStats(vals: [Double], mealCount: Int, exCount: Int) -> PanelJSON.PanelStats {
        guard !vals.isEmpty else {
            return .init(count: 0, avg: nil, tir: nil, peak: nil, low: nil, gmi: nil,
                         meals: mealCount, exercise: exCount)
        }
        let avg  = vals.reduce(0, +) / Double(vals.count)
        let tir  = Int(round(Double(vals.filter { $0 >= 70 && $0 <= 180 }.count) / Double(vals.count) * 100))
        let gmi  = (round((3.31 + 0.02392 * avg) * 10) / 10)
        return .init(
            count:    vals.count,
            avg:      (avg  * 10).rounded() / 10,
            tir:      tir,
            peak:     Int(vals.max()!),
            low:      Int(vals.min()!),
            gmi:      gmi,
            meals:    mealCount,
            exercise: exCount
        )
    }

    private static func extractSteps(from notes: String?) -> String? {
        guard let notes = notes else { return nil }
        guard let r = notes.range(of: "Steps: ", options: .caseInsensitive) else { return nil }
        let digits = notes[r.upperBound...].prefix(while: { $0.isNumber })
        return digits.isEmpty ? nil : String(digits)
    }

    private static func formatPatientInfo(profiles: [UserDemographicsEntity]) -> String {
        guard let p = profiles.first else { return "Patient" }
        var parts: [String] = []
        if let sex  = p.sex,          !sex.isEmpty   { parts.append(sex.capitalized) }
        if p.age > 0                                   { parts.append("\(Int(p.age)) yrs") }
        if let dtype = p.diabetesType, !dtype.isEmpty  { parts.append(dtype) }
        if p.height > 0                                { parts.append("\(Int(p.height)) cm") }
        if p.weight > 0 {
            parts.append("\(Int(p.weight)) kg")
            let bmi = p.weight / pow(p.height / 100.0, 2)
            parts.append(String(format: "BMI %.1f", bmi))
        }
        return parts.joined(separator: " · ")
    }

    private static func dateRangeLabel(panels: [PanelJSON]) -> String {
        guard let oldest = panels.last, let newest = panels.first else { return "" }
        let tz = TimeZone.current
        let sf = DateFormatter(); sf.dateFormat = "MMM d";      sf.timeZone = tz
        let ef = DateFormatter(); ef.dateFormat = "MMM d, yyyy"; ef.timeZone = tz
        let s  = Date(timeIntervalSince1970: Double(oldest.startMs) / 1000)
        let e  = Date(timeIntervalSince1970: Double(newest.endMs)   / 1000 - 1)
        return "\(sf.string(from: s)) – \(ef.string(from: e))"
    }

    // MARK: - Codable Data Models (match JS expectations exactly)

    private struct PanelJSON: Codable {
        let label:        String
        let startMs:      Int64
        let endMs:        Int64
        let glucoseData:  [GlucosePoint]
        let mealGreen:    [MealBubble]
        let mealYellow:   [MealBubble]
        let mealRed:      [MealBubble]
        let exerciseData: [ExerciseBar]
        let dayTicks:     [DayTick]
        let stats:        PanelStats

        struct GlucosePoint: Codable { let x: Int64; let y: Int }

        struct MealBubble: Codable {
            let x: Int64; var y: Int; let r: Double
            let carbs: Double; let name: String; let calories: Int; let foods: String
        }

        struct ExerciseBar: Codable {
            let x1: Int64; let x2: Int64; let xMid: Int64
            let startLabel: String; let exerciseType: String
            let duration: Int; let calories: Int; let distance: Double; let steps: String?
            enum CodingKeys: String, CodingKey {
                case x1, x2, xMid, startLabel
                case exerciseType = "type"
                case duration, calories, distance, steps
            }
        }

        struct DayTick:   Codable { let ms: Int64; let label: String }

        struct PanelStats: Codable {
            let count: Int
            let avg:   Double?; let tir: Int?; let peak: Int?; let low: Int?; let gmi: Double?
            let meals: Int;     let exercise: Int
        }
    }

    // MARK: - HTML Template

    // swiftlint:disable function_body_length
    private static func htmlString(
        panelsJSON:  String,
        dateRange:   String,
        patientInfo: String,
        ovAvg:    String, ovTir: String, ovGmi: String, labGmi: String,
        ovPeak:   String, ovMeals: String, ovEx: String,
        tirColor: String
    ) -> String {

        let genDate: String = {
            let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
            return df.string(from: Date())
        }()

        return """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Diabetes Feast — 3-Month Clinical Summary</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f0f3f7;color:#2c3e50}
.page{max-width:1320px;margin:0 auto;padding:12px 16px}
.header{background:linear-gradient(135deg,#1a5276,#2471a3);color:white;border-radius:12px;
  padding:18px 26px;margin-bottom:14px;display:flex;justify-content:space-between;align-items:center}
.header h1{font-size:1.25rem;font-weight:700;letter-spacing:-.2px}
.header .sub{font-size:.76rem;opacity:.8;margin-top:4px}
.header .meta{font-size:.78rem;opacity:.88;line-height:1.7;text-align:right}
.summary-grid{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin-bottom:14px}
.stat{background:white;border-radius:10px;padding:12px 16px;box-shadow:0 1px 4px rgba(0,0,0,.07)}
.stat .lbl{font-size:.62rem;color:#95a5a6;text-transform:uppercase;letter-spacing:.6px;margin-bottom:2px}
.stat .val{font-size:1.5rem;font-weight:700;line-height:1}
.stat .unt{font-size:.65rem;color:#aaa;margin-top:2px}
.controls{background:white;border-radius:10px;padding:12px 18px;margin-bottom:12px;
  box-shadow:0 1px 4px rgba(0,0,0,.07);display:flex;align-items:center;
  justify-content:space-between;flex-wrap:wrap;gap:8px}
.controls-label{font-size:.78rem;font-weight:600;color:#666;text-transform:uppercase;letter-spacing:.4px}
.trace-toggle{display:flex;gap:2px;background:#e8ecf0;border-radius:20px;padding:3px}
.tpill{border:none;background:transparent;border-radius:16px;padding:5px 16px;
  font-size:.73rem;font-weight:600;cursor:pointer;color:#666;transition:all .15s;letter-spacing:.3px}
.tpill.active{background:white;color:#2c3e50;box-shadow:0 1px 3px rgba(0,0,0,.15)}
.panel{background:white;border-radius:12px;padding:16px 18px 12px;
  box-shadow:0 1px 5px rgba(0,0,0,.08);margin-bottom:14px}
.panel-header{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:10px}
.panel-title{font-size:.9rem;font-weight:700;color:#2c3e50}
.panel-sub{font-size:.68rem;color:#999;margin-top:2px}
.panel-stats{display:flex;gap:18px;flex-wrap:wrap;margin-bottom:10px}
.pstat{text-align:center}
.pstat .pv{font-size:1.1rem;font-weight:700}
.pstat .pu{font-size:.62rem;color:#999;text-transform:uppercase}
.no-data{display:flex;align-items:center;justify-content:center;height:100px;
  color:#bbb;font-size:.88rem;border:2px dashed #e0e0e0;border-radius:8px;margin:8px 0}
.data-source{display:inline-block;font-size:.65rem;padding:2px 8px;border-radius:10px;font-weight:600;letter-spacing:.3px}
.src-hk{background:#e8f4fd;color:#2471a3}
.src-ll{background:#eafaf1;color:#1e8449}
.src-gap{background:#fef9e7;color:#b7950b}
.legend{display:flex;gap:14px;flex-wrap:wrap;margin-top:10px;font-size:.72rem;color:#555;align-items:center}
.li{display:flex;align-items:center;gap:5px}
.sw-line{width:22px;height:3px;border-radius:2px}
.sw-dot{width:11px;height:11px;border-radius:50%}
.sw-rect{width:10px;height:14px;border-radius:2px}
#exPopover{display:none;position:fixed;z-index:9999;background:white;border-radius:10px;
  box-shadow:0 4px 20px rgba(0,0,0,.22);min-width:210px;max-width:270px;
  font-size:.82rem;pointer-events:none}
.pop-header{padding:10px 14px 8px;border-radius:10px 10px 0 0;font-weight:700;font-size:.9rem;color:white}
.pop-body{padding:10px 14px 12px;line-height:2.1;color:#2c3e50}
.footer{font-size:.65rem;color:#bbb;text-align:center;margin-top:10px;padding-bottom:8px}
</style>
</head>
<body>
<div class="page">

<div class="header">
  <div>
    <h1>&#128202; Diabetes Feast &mdash; 3-Month Clinical Summary</h1>
    <div class="sub">Blood Glucose &middot; Meals &middot; Exercise &nbsp;|&nbsp; \(dateRange)</div>
  </div>
  <div class="meta">\(patientInfo)<br>Generated: \(genDate)</div>
</div>

<div class="summary-grid">
  <div class="stat"><div class="lbl">Mean Glucose</div><div class="val" style="color:#e67e22">\(ovAvg)</div><div class="unt">mg/dL (CGM days only)</div></div>
  <div class="stat"><div class="lbl">Time in Range</div><div class="val" style="color:\(tirColor)">\(ovTir)%</div><div class="unt">70&#8211;180 mg/dL target</div></div>
  <div class="stat"><div class="lbl">GMI Estimate</div><div class="val" style="color:#8e44ad">\(labGmi)%</div><div class="unt">Bergenstal 2018</div></div>
  <div class="stat"><div class="lbl">Peak Glucose</div><div class="val" style="color:#e74c3c">\(ovPeak)</div><div class="unt">mg/dL</div></div>
  <div class="stat"><div class="lbl">Meals Logged</div><div class="val" style="color:#16a085">\(ovMeals)</div><div class="unt">over 3 months</div></div>
  <div class="stat"><div class="lbl">Exercise Sessions</div><div class="val" style="color:#2980b9">\(ovEx)</div><div class="unt">walking &amp; activity</div></div>
</div>

<div class="controls">
  <span class="controls-label">Glucose trace &mdash; all panels</span>
  <div class="trace-toggle" id="globalToggle">
    <button class="tpill active" data-mode="raw">Raw</button>
    <button class="tpill" data-mode="trend">Trend</button>
    <button class="tpill" data-mode="both">Both</button>
  </div>
</div>

<div id="panelsContainer"></div>

<div id="exPopover">
  <div class="pop-header" id="popHeader"></div>
  <div class="pop-body"  id="popBody"></div>
</div>

<div class="footer">
  Diabetes Feast app &middot; Data sources: HealthKit, FreeStyle Libre 2, Dexcom G7, manual entry<br>
  Not a clinical measurement &middot; For informational discussion with a healthcare provider only
</div>
</div>

<script>
const PANELS = \(panelsJSON);

const EX_COLORS = {
  'Walking': {fill:'rgba(41,128,185,.4)', stroke:'rgba(41,128,185,.85)',header:'#2471a3',icon:'\\u{1F6B6}'},
  'Cycling': {fill:'rgba(142,68,173,.4)', stroke:'rgba(142,68,173,.85)',header:'#7d3c98',icon:'\\u{1F6B4}'},
  'Running': {fill:'rgba(39,174,96,.4)',  stroke:'rgba(39,174,96,.85)', header:'#1e8449',icon:'\\u{1F3C3}'},
  'Swimming':{fill:'rgba(22,160,133,.4)', stroke:'rgba(22,160,133,.85)',header:'#17a589',icon:'\\u{1F3CA}'},
  'default': {fill:'rgba(127,140,141,.4)',stroke:'rgba(127,140,141,.85)',header:'#717d7e',icon:'\\u{1F3CB}'},
};
function exColor(t){return EX_COLORS[t]||EX_COLORS['default'];}

function computeSmoothed(data,bwMs){
  if(data.length<3) return data.map(p=>Object.assign({},p));
  return data.map(pt=>{
    let wSum=0,vSum=0;
    for(const d of data){
      const dt=(pt.x-d.x)/bwMs,w=Math.exp(-.5*dt*dt);
      if(w<.001) continue;
      wSum+=w; vSum+=w*d.y;
    }
    return{x:pt.x,y:Math.round(vSum/wSum*10)/10};
  });
}

const popover=document.getElementById('exPopover');
let curHover=null;
function showPopover(e,cx,cy){
  if(curHover===e){posPopover(cx,cy);return;}
  curHover=e;
  const c=exColor(e.type);
  document.getElementById('popHeader').style.background=c.header;
  document.getElementById('popHeader').textContent=c.icon+' '+e.type;
  let rows=`<div>&#128197; ${e.startLabel}</div><div>&#9203; ${e.duration} min</div><div>&#128293; ${e.calories} kcal</div>`;
  if(e.distance>0) rows+=`<div>&#128205; ${e.distance.toFixed(2)} km</div>`;
  if(e.steps)      rows+=`<div>&#128099; ${e.steps} steps</div>`;
  document.getElementById('popBody').innerHTML=rows;
  popover.style.display='block'; posPopover(cx,cy);
}
function posPopover(cx,cy){
  const pw=270,ph=170;
  let l=cx+16,t=cy-20;
  if(l+pw>window.innerWidth-8)  l=cx-pw-16;
  if(t+ph>window.innerHeight-8) t=window.innerHeight-ph-8;
  popover.style.left=l+'px'; popover.style.top=t+'px';
}
function hidePopover(){popover.style.display='none';curHover=null;}

function makeOverlayPlugin(pd){
  return{
    id:'ovl_'+pd.startMs,
    beforeDatasetsDraw(chart){
      const{ctx,chartArea:a,scales:{x:xs,y:ys,y2:y2s}}=chart;
      const y70=ys.getPixelForValue(70),y180=ys.getPixelForValue(180);
      ctx.fillStyle='rgba(39,174,96,.08)';
      ctx.fillRect(a.left,y180,a.width,y70-y180);
      ctx.strokeStyle='rgba(39,174,96,.35)';ctx.lineWidth=1;ctx.setLineDash([5,4]);
      [70,180].forEach(v=>{const py=ys.getPixelForValue(v);ctx.beginPath();ctx.moveTo(a.left,py);ctx.lineTo(a.right,py);ctx.stroke();});
      ctx.setLineDash([]);
      if(pd.glucoseData.length===0){
        ctx.save();ctx.fillStyle='rgba(189,195,199,.35)';ctx.fillRect(a.left,a.top,a.width,a.bottom-a.top);
        ctx.fillStyle='#95a5a6';ctx.font='600 13px -apple-system,sans-serif';
        ctx.textAlign='center';ctx.textBaseline='middle';
        ctx.fillText('CGM data unavailable during this period',(a.left+a.right)/2,(a.top+a.bottom)/2);
        ctx.restore();
      } else if(pd.glucoseData.length<10){
        ctx.save();ctx.fillStyle='rgba(243,156,18,.1)';ctx.fillRect(a.left,a.top,a.width,a.bottom-a.top);
        ctx.fillStyle='#b7950b';ctx.font='500 11px -apple-system,sans-serif';
        ctx.textAlign='left';ctx.textBaseline='top';
        ctx.fillText('\\u26A0 Limited CGM data \\u2014 sensor connection interrupted',a.left+10,a.top+10);
        ctx.restore();
      }
      (pd.dayTicks||[]).forEach(t=>{
        const px=xs.getPixelForValue(t.ms);
        if(px<a.left||px>a.right) return;
        ctx.strokeStyle='rgba(0,0,0,.06)';ctx.lineWidth=1;
        ctx.beginPath();ctx.moveTo(px,a.top);ctx.lineTo(px,a.bottom);ctx.stroke();
      });
      if(!y2s) return;
      pd.exerciseData.forEach(e=>{
        const xc=xs.getPixelForValue(e.xMid);
        if(xc<a.left-5||xc>a.right+5) return;
        const c=exColor(e.type);
        const yTop=y2s.getPixelForValue(e.duration),yBot=a.bottom;
        ctx.fillStyle=c.fill;ctx.strokeStyle=c.stroke;ctx.lineWidth=1.5;
        ctx.fillRect(xc-5,yTop,10,yBot-yTop);ctx.strokeRect(xc-5,yTop,10,yBot-yTop);
        e._px=xc;
      });
    },
    afterDraw(chart){
      const{ctx,chartArea:a}=chart;
      ctx.save();ctx.translate(a.right+68,(a.top+a.bottom)/2);ctx.rotate(-Math.PI/2);
      ctx.fillStyle='#2980b9';ctx.font='500 9px -apple-system,sans-serif';
      ctx.textAlign='center';ctx.textBaseline='middle';
      ctx.fillText('Exercise Duration (min)',0,0);ctx.restore();
    }
  };
}

const charts=[];

function buildPanel(idx){
  const pd=PANELS[idx];
  const gdata=pd.glucoseData;
  const vals=gdata.map(d=>d.y);
  const G_MIN=vals.length?Math.floor((Math.min(...vals)-15)/10)*10:60;
  const G_MAX=vals.length?Math.ceil( (Math.max(...vals)+25)/10)*10:280;
  const MEAL_Y=G_MIN+20;
  [...pd.mealGreen,...pd.mealYellow,...pd.mealRed].forEach(m=>m.y=MEAL_Y);
  const smoothed=computeSmoothed(gdata,90*60000);
  const MAX_DUR=pd.exerciseData.length?Math.max(...pd.exerciseData.map(e=>e.duration),60):120;
  const Y2_MAX=MAX_DUR*6;
  const dummy=[{x:pd.startMs,y:0},{x:pd.endMs,y:Y2_MAX}];
  const ovlPlugin=makeOverlayPlugin(pd);
  const chart=new Chart(document.getElementById('chart_'+idx),{
    type:'line',plugins:[ovlPlugin],
    data:{datasets:[
      {label:'Blood Glucose',data:gdata,yAxisID:'y',
        borderColor:'#e67e22',backgroundColor:'rgba(230,126,34,.04)',
        borderWidth:1.6,pointRadius:0,pointHoverRadius:0,tension:.3,fill:false,order:1},
      {label:'Glucose Trend',data:smoothed,yAxisID:'y',
        borderColor:'#d4ac0d',backgroundColor:'rgba(212,172,13,.05)',
        borderWidth:2.5,pointRadius:0,pointHoverRadius:0,tension:.3,fill:false,order:1,hidden:true},
      {label:'Meal <30g', type:'bubble',data:pd.mealGreen, yAxisID:'y',
        backgroundColor:'rgba(39,174,96,.75)', borderColor:'#1e8449',borderWidth:1,order:2},
      {label:'Meal 30-59g',type:'bubble',data:pd.mealYellow,yAxisID:'y',
        backgroundColor:'rgba(241,196,15,.85)',borderColor:'#b7950b',borderWidth:1,order:2},
      {label:'Meal >=60g', type:'bubble',data:pd.mealRed,   yAxisID:'y',
        backgroundColor:'rgba(231,76,60,.8)',  borderColor:'#922b21',borderWidth:1,order:2},
      {label:'_ex',type:'scatter',data:dummy,yAxisID:'y2',
        pointRadius:0,borderColor:'transparent',backgroundColor:'transparent',order:99},
    ]},
    options:{
      responsive:true,layout:{padding:{right:76}},
      interaction:{mode:'nearest',intersect:false},
      scales:{
        x:{type:'linear',min:pd.startMs,max:pd.endMs,
          ticks:{maxTicksLimit:16,font:{size:10},
            callback(val){const t=(pd.dayTicks||[]).find(d=>Math.abs(d.ms-val)<3600000*12);return t?t.label:'';}},
          grid:{display:false}},
        y:{min:G_MIN,max:G_MAX,position:'left',
          title:{display:true,text:'Blood Glucose (mg/dL)',font:{size:10}},
          ticks:{font:{size:10}},grid:{color:'rgba(0,0,0,.05)'}},
        y2:{min:0,max:Y2_MAX,position:'right',title:{display:false},
          ticks:{stepSize:30,font:{size:9},color:'#2980b9',callback:v=>(v===0||v>MAX_DUR)?'':String(v)},
          grid:{drawOnChartArea:false}}
      },
      plugins:{legend:{display:false},tooltip:{enabled:false}}
    }
  });
  charts[idx]=chart;

  const canvas=document.getElementById('chart_'+idx);
  canvas.addEventListener('mousemove',e=>{
    const r=canvas.getBoundingClientRect(),lx=e.clientX-r.left,ly=e.clientY-r.top;
    for(const ex of pd.exerciseData){
      if(ex._px===undefined) continue;
      const{chartArea:a,scales:{y2:y2s}}=chart;
      if(!a||!y2s) continue;
      const yTop=y2s.getPixelForValue(ex.duration);
      if(Math.abs(lx-ex._px)<=9&&ly>=yTop&&ly<=a.bottom){
        canvas.style.cursor='pointer';showPopover(ex,e.clientX,e.clientY);return;
      }
    }
    for(const grp of [pd.mealRed,pd.mealYellow,pd.mealGreen]){
      for(const m of grp){
        const{scales:{x:xs,y:ys}}=chart;
        if(!xs||!ys) continue;
        const px=xs.getPixelForValue(m.x),py=ys.getPixelForValue(m.y);
        if(Math.hypot(lx-px,ly-py)<=m.r*1.4){
          canvas.style.cursor='pointer';
          document.getElementById('popHeader').style.background='#16a085';
          document.getElementById('popHeader').textContent='\\u{1F37D} '+m.name;
          document.getElementById('popBody').innerHTML=`<div>${m.foods||'&#8212;'}</div><div>&#127838; ${m.carbs}g carbs &middot; ${m.calories} kcal</div>`;
          popover.style.display='block';posPopover(e.clientX,e.clientY);return;
        }
      }
    }
    canvas.style.cursor='';hidePopover();
  });
  canvas.addEventListener('mouseleave',()=>{canvas.style.cursor='';hidePopover();});
}

function statColor(key,val){
  if(key==='tir')  return val>=70?'#27ae60':val>=50?'#e67e22':'#e74c3c';
  if(key==='avg')  return val<140?'#27ae60':val<180?'#e67e22':'#e74c3c';
  if(key==='gmi')  return val<7.0?'#27ae60':val<8.0?'#e67e22':'#e74c3c';
  if(key==='peak') return val<=180?'#27ae60':val<=250?'#e67e22':'#e74c3c';
  return '#2c3e50';
}

function dataSourceBadge(pd){
  if(pd.stats.count===0) return '<span class="data-source src-gap">No CGM data</span>';
  const s=new Date(pd.startMs);
  if(s>=new Date('2026-06-18T00:00:00Z')) return '<span class="data-source src-ll">FreeStyle Libre 2 / Dexcom G7</span>';
  if(s<new Date('2026-05-20T00:00:00Z'))  return '<span class="data-source src-hk">HealthKit CGM</span>';
  return '<span class="data-source src-gap">Limited data</span>';
}

const container=document.getElementById('panelsContainer');
PANELS.forEach((pd,idx)=>{
  const s=pd.stats,hasData=s.count>0,panelNum=PANELS.length-idx;
  const statsHTML=hasData?`
    <div class="panel-stats">
      <div class="pstat"><div class="pv" style="color:${statColor('avg',s.avg)}">${s.avg}</div><div class="pu">Avg mg/dL</div></div>
      <div class="pstat"><div class="pv" style="color:${statColor('tir',s.tir)}">${s.tir}%</div><div class="pu">Time in Range</div></div>
      <div class="pstat"><div class="pv" style="color:${statColor('gmi',s.gmi)}">${s.gmi}%</div><div class="pu">GMI Est.</div></div>
      <div class="pstat"><div class="pv" style="color:${statColor('peak',s.peak)}">${s.peak}</div><div class="pu">Peak mg/dL</div></div>
      <div class="pstat"><div class="pv" style="color:#2980b9">${s.low}</div><div class="pu">Min mg/dL</div></div>
      <div class="pstat"><div class="pv" style="color:#16a085">${s.meals}</div><div class="pu">Meals</div></div>
      <div class="pstat"><div class="pv" style="color:#2980b9">${s.exercise}</div><div class="pu">Exercise</div></div>
      <div class="pstat"><div class="pv" style="color:#666">${s.count}</div><div class="pu">Readings</div></div>
    </div>`:`
    <div class="panel-stats">
      <div class="pstat"><div class="pv" style="color:#16a085">${s.meals}</div><div class="pu">Meals</div></div>
      <div class="pstat"><div class="pv" style="color:#2980b9">${s.exercise}</div><div class="pu">Exercise</div></div>
    </div>`;
  const div=document.createElement('div');
  div.className='panel';
  div.innerHTML=`
    <div class="panel-header">
      <div><div class="panel-title">Panel ${panelNum}: ${pd.label}</div>
      <div class="panel-sub">${dataSourceBadge(pd)}</div></div>
    </div>${statsHTML}
    ${hasData
      ?`<canvas id="chart_${idx}" height="170"></canvas>`
      :`<div class="no-data">&#128225; No CGM readings &mdash; sensor not active during this period</div>
        ${s.meals>0||s.exercise>0?`<canvas id="chart_${idx}" height="90"></canvas>`:''}`}
    ${hasData?`<div class="legend" id="legend_${idx}"></div>`:''}`;
  container.appendChild(div);
  if(document.getElementById('chart_'+idx)){
    buildPanel(idx);
    if(hasData){
      const exTypes=[...new Set(pd.exerciseData.map(e=>e.type))];
      let leg=`
        <div class="li"><div class="sw-line" style="background:#e67e22"></div> Blood Glucose (raw)</div>
        <div class="li"><div class="sw-line" style="background:#d4ac0d"></div> Glucose Trend</div>
        <div class="li"><div class="sw-rect" style="background:rgba(39,174,96,.15);border:1px solid rgba(39,174,96,.5)"></div> Target 70&#8211;180</div>
        <div class="li"><div class="sw-dot" style="background:rgba(39,174,96,.8)"></div> Meal &lt;30g</div>
        <div class="li"><div class="sw-dot" style="background:rgba(241,196,15,.9)"></div> Meal 30&#8211;59g</div>
        <div class="li"><div class="sw-dot" style="background:rgba(231,76,60,.8)"></div> Meal &#8805;60g</div>`;
      exTypes.forEach(t=>{
        const c=exColor(t);
        leg+=`<div class="li"><div class="sw-rect" style="background:${c.fill};border:1px solid ${c.stroke}"></div> ${c.icon} ${t}</div>`;
      });
      document.getElementById('legend_'+idx).innerHTML=leg;
    }
  }
});

let globalMode='raw';
function setAllTraceModes(mode){
  globalMode=mode;
  document.querySelectorAll('#globalToggle .tpill').forEach(b=>b.classList.toggle('active',b.dataset.mode===mode));
  charts.forEach(chart=>{
    if(!chart) return;
    const raw=chart.data.datasets[0],smo=chart.data.datasets[1];
    if(mode==='raw'){
      raw.hidden=false;raw.borderColor='#e67e22';raw.borderWidth=1.6;
      raw.backgroundColor='rgba(230,126,34,.04)';smo.hidden=true;
    } else if(mode==='trend'){
      raw.hidden=true;smo.hidden=false;smo.borderColor='#d4ac0d';smo.borderWidth=2.5;
      smo.backgroundColor='rgba(212,172,13,.05)';
    } else {
      raw.hidden=false;raw.borderColor='rgba(230,126,34,.35)';raw.borderWidth=1;
      raw.backgroundColor='rgba(230,126,34,.02)';smo.hidden=false;
      smo.borderColor='#d4ac0d';smo.borderWidth=2.5;smo.backgroundColor='rgba(212,172,13,.05)';
    }
    chart.update('none');
  });
}
document.getElementById('globalToggle').addEventListener('click',e=>{
  const btn=e.target.closest('.tpill');
  if(btn) setAllTraceModes(btn.dataset.mode);
});
</script>
</body>
</html>
"""
    }
    // swiftlint:enable function_body_length
}
