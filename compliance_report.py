#!/usr/bin/env python3
"""Generate App Store & HealthKit Compliance Audit Report as PDF."""

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.colors import HexColor, black, white
from reportlab.lib.units import inch
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.lib import colors
import datetime

OUTPUT = "/sessions/vibrant-lucid-ritchie/mnt/DiabetesHbA1cPrediction/DiabetesHbA1cPrediction_Compliance_Audit.pdf"

# Colors
DARK_BLUE = HexColor("#1a365d")
MED_BLUE = HexColor("#2b6cb0")
LIGHT_BLUE = HexColor("#ebf4ff")
CRITICAL_RED = HexColor("#c53030")
CRITICAL_BG = HexColor("#fff5f5")
HIGH_ORANGE = HexColor("#c05621")
HIGH_BG = HexColor("#fffaf0")
MEDIUM_YELLOW = HexColor("#975a16")
MEDIUM_BG = HexColor("#fffff0")
LOW_GREEN = HexColor("#276749")
LOW_BG = HexColor("#f0fff4")
PASS_GREEN = HexColor("#276749")
FAIL_RED = HexColor("#c53030")
WARN_ORANGE = HexColor("#c05621")
GRAY = HexColor("#718096")
LIGHT_GRAY = HexColor("#f7fafc")
BORDER_GRAY = HexColor("#e2e8f0")

styles = getSampleStyleSheet()

# Custom styles
styles.add(ParagraphStyle("ReportTitle", parent=styles["Title"],
    fontSize=22, textColor=DARK_BLUE, spaceAfter=4, alignment=TA_CENTER))
styles.add(ParagraphStyle("ReportSubtitle", parent=styles["Normal"],
    fontSize=11, textColor=GRAY, alignment=TA_CENTER, spaceAfter=20))
styles.add(ParagraphStyle("SectionHead", parent=styles["Heading1"],
    fontSize=15, textColor=DARK_BLUE, spaceBefore=18, spaceAfter=8,
    borderWidth=0, borderPadding=0))
styles.add(ParagraphStyle("FindingTitle", parent=styles["Heading2"],
    fontSize=11, textColor=black, spaceBefore=10, spaceAfter=4))
styles.add(ParagraphStyle("AuditBody", parent=styles["Normal"],
    fontSize=9.5, leading=13, spaceAfter=6, textColor=HexColor("#2d3748")))
styles.add(ParagraphStyle("SmallBody", parent=styles["Normal"],
    fontSize=8.5, leading=11, spaceAfter=4, textColor=HexColor("#4a5568")))
styles.add(ParagraphStyle("CodeText", parent=styles["Normal"],
    fontSize=8, leading=10, fontName="Courier", textColor=HexColor("#553c9a"),
    backColor=HexColor("#f7fafc"), spaceAfter=6, leftIndent=12, rightIndent=12,
    borderWidth=0.5, borderColor=BORDER_GRAY, borderPadding=6))
styles.add(ParagraphStyle("BulletItem", parent=styles["Normal"],
    fontSize=9.5, leading=13, leftIndent=18, bulletIndent=6,
    textColor=HexColor("#2d3748"), spaceAfter=3))
styles.add(ParagraphStyle("TableCell", parent=styles["Normal"],
    fontSize=8.5, leading=11, textColor=HexColor("#2d3748")))
styles.add(ParagraphStyle("TableHeader", parent=styles["Normal"],
    fontSize=8.5, leading=11, textColor=white, fontName="Helvetica-Bold"))
styles.add(ParagraphStyle("SeverityLabel", parent=styles["Normal"],
    fontSize=8, fontName="Helvetica-Bold", alignment=TA_CENTER))
styles.add(ParagraphStyle("PassFail", parent=styles["Normal"],
    fontSize=8.5, leading=11))


def severity_badge(level):
    color_map = {
        "CRITICAL": CRITICAL_RED,
        "HIGH": HIGH_ORANGE,
        "MEDIUM": MEDIUM_YELLOW,
        "LOW": LOW_GREEN,
        "INFO": MED_BLUE,
    }
    c = color_map.get(level, GRAY)
    return Paragraph(f'<font color="{c.hexval()}">[{level}]</font>',
                     styles["SeverityLabel"])


def status_text(status):
    if status == "PASS":
        return Paragraph(f'<font color="{PASS_GREEN.hexval()}"><b>PASS</b></font>', styles["PassFail"])
    elif status == "FAIL":
        return Paragraph(f'<font color="{FAIL_RED.hexval()}"><b>FAIL</b></font>', styles["PassFail"])
    else:
        return Paragraph(f'<font color="{WARN_ORANGE.hexval()}"><b>PARTIAL</b></font>', styles["PassFail"])


def make_finding(severity, title, location, issue, details, impact, recommendation):
    bg_map = {"CRITICAL": CRITICAL_BG, "HIGH": HIGH_BG, "MEDIUM": MEDIUM_BG, "LOW": LOW_BG}
    bg = bg_map.get(severity, LIGHT_GRAY)
    color_map = {"CRITICAL": CRITICAL_RED, "HIGH": HIGH_ORANGE, "MEDIUM": MEDIUM_YELLOW, "LOW": LOW_GREEN}
    border_color = color_map.get(severity, GRAY)

    elements = []
    elements.append(Paragraph(
        f'<font color="{border_color.hexval()}"><b>[{severity}]</b></font> {title}',
        styles["FindingTitle"]))

    data = []
    if location:
        data.append(["Location:", location])
    data.append(["Issue:", issue])
    if details:
        data.append(["Details:", details])
    if impact:
        data.append(["Impact:", impact])
    data.append(["Recommendation:", recommendation])

    table_data = []
    for label, val in data:
        table_data.append([
            Paragraph(f'<b>{label}</b>', styles["SmallBody"]),
            Paragraph(val, styles["SmallBody"])
        ])

    t = Table(table_data, colWidths=[1.1*inch, 5.4*inch])
    t.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BACKGROUND', (0, 0), (-1, -1), bg),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('BOX', (0, 0), (-1, -1), 0.5, border_color),
    ]))
    elements.append(t)
    elements.append(Spacer(1, 8))
    return KeepTogether(elements)


def build_pdf():
    doc = SimpleDocTemplate(OUTPUT, pagesize=letter,
        topMargin=0.7*inch, bottomMargin=0.7*inch,
        leftMargin=0.75*inch, rightMargin=0.75*inch)
    story = []

    # Title page content
    story.append(Spacer(1, 40))
    story.append(Paragraph("App Store &amp; HealthKit Compliance Audit", styles["ReportTitle"]))
    story.append(Paragraph("DiabetesHbA1cPrediction iOS Application", styles["ReportSubtitle"]))
    story.append(HRFlowable(width="60%", thickness=1, color=MED_BLUE, spaceAfter=12))

    # Meta info
    meta = [
        ["Audit Date:", datetime.date.today().strftime("%B %d, %Y")],
        ["Scope:", "46 Swift source files, Info.plist, entitlements, project configuration"],
        ["Frameworks:", "HealthKit, CoreData, SwiftUI"],
        ["App Purpose:", "Diabetes management with HbA1c prediction using glucose, meal, and exercise data"],
    ]
    meta_table = Table(
        [[Paragraph(f'<b>{r[0]}</b>', styles["AuditBody"]),
          Paragraph(r[1], styles["AuditBody"])] for r in meta],
        colWidths=[1.4*inch, 5.1*inch])
    meta_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BACKGROUND', (0, 0), (-1, -1), LIGHT_BLUE),
        ('BOX', (0, 0), (-1, -1), 0.5, MED_BLUE),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 16))

    # Executive Summary
    story.append(Paragraph("Executive Summary", styles["SectionHead"]))
    story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER_GRAY, spaceAfter=8))

    summary_data = [
        [Paragraph("<b>Severity</b>", styles["TableHeader"]),
         Paragraph("<b>Count</b>", styles["TableHeader"]),
         Paragraph("<b>Key Issues</b>", styles["TableHeader"])],
        [severity_badge("CRITICAL"), Paragraph("1", styles["TableCell"]),
         Paragraph("Invalid iOS deployment target (26.0)", styles["TableCell"])],
        [severity_badge("HIGH"), Paragraph("2", styles["TableCell"]),
         Paragraph("HealthKit write permission mismatch; extensive console logging of health data", styles["TableCell"])],
        [severity_badge("MEDIUM"), Paragraph("4", styles["TableCell"]),
         Paragraph("Missing medical disclaimer in main UI; no CoreData encryption; health data in share export; fatalError in production code", styles["TableCell"])],
        [severity_badge("LOW"), Paragraph("2", styles["TableCell"]),
         Paragraph("Realistic PII in preview/test data; glucose unit conversion lacks tests", styles["TableCell"])],
    ]
    summary_t = Table(summary_data, colWidths=[1.1*inch, 0.6*inch, 4.8*inch])
    summary_t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), DARK_BLUE),
        ('TEXTCOLOR', (0, 0), (-1, 0), white),
        ('ALIGN', (1, 0), (1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, BORDER_GRAY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, LIGHT_GRAY]),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(summary_t)
    story.append(Spacer(1, 6))
    story.append(Paragraph(
        "The app has a sound architecture with no network calls, no third-party analytics, and no advertising frameworks. "
        "All health data stays on-device. However, several configuration and compliance issues must be resolved before App Store submission.",
        styles["AuditBody"]))

    # ===== FINDINGS =====
    story.append(PageBreak())
    story.append(Paragraph("Detailed Findings", styles["SectionHead"]))
    story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER_GRAY, spaceAfter=8))

    # CRITICAL
    story.append(make_finding(
        "CRITICAL",
        "Invalid iOS Deployment Target",
        "project.pbxproj (6 occurrences across all build configurations)",
        "IPHONEOS_DEPLOYMENT_TARGET is set to 26.0 across all Debug and Release configurations. iOS 26.0 does not exist. The current latest is iOS 18.",
        "Found in all 6 build setting blocks in the Xcode project file. This will prevent archiving and App Store submission.",
        "App cannot be built for a real device or submitted to App Store Connect. Xcode will reject the configuration.",
        "Set the deployment target to a valid iOS version (e.g., 16.0 or 17.0). Update in Xcode under each target's General tab or directly in project.pbxproj."
    ))

    # HIGH #1
    story.append(make_finding(
        "HIGH",
        "HealthKit Write Permission Declaration Without Implementation",
        "Info.plist (line 23-24) and project.pbxproj INFOPLIST_KEY settings; HealthKitManager.swift (line 82)",
        'Info.plist declares NSHealthUpdateUsageDescription ("This app writes exercise and meal data to Apple Health...") but the code requests zero write permissions: toShare is an empty Set.',
        "The usage description string also appears in the project.pbxproj INFOPLIST_KEY_NSHealthUpdateUsageDescription for both Debug and Release. "
        "The HealthKitManager never calls healthStore.save() anywhere in the codebase. The declaration is misleading.",
        "Apple reviewers may reject the app for declaring a write permission it never uses, or users may be confused by the authorization prompt. "
        "This violates App Store Review Guideline 5.1.1 (Data Collection and Storage).",
        "Either (a) remove NSHealthUpdateUsageDescription from Info.plist and both INFOPLIST_KEY entries if write is not needed, or "
        "(b) implement actual HealthKit write operations and populate the toShare parameter with the relevant HKSampleTypes."
    ))

    # HIGH #2
    story.append(make_finding(
        "HIGH",
        "Extensive Console Logging of Health-Related Operations",
        "40+ print() statements across HealthKitManager.swift (11), HbA1cPredictionEngine.swift (13), GlucoseLogView.swift (3), "
        "ExerciseLogView.swift (3), MealLogView.swift (2), PersistenceController.swift (1), and others",
        "Health-related error messages and operational status are logged to the system console via print() without any conditional compilation guards.",
        'Examples: "Error fetching glucose readings: ...", "Successfully saved prediction result to Core Data", '
        '"Error fetching user demographics: ...". These appear in device console logs that can be read via Xcode, Console.app, or crash reports.',
        "Console logs may expose sensitive health operation details. While error messages themselves do not contain raw health values, "
        "they reveal the types of health data the user has and operational patterns. This is a privacy concern under GDPR and best-practice guidelines for health apps.",
        'Wrap all print() calls in #if DEBUG blocks, or replace with os_log() using appropriate privacy levels. '
        'For example: os_log("Glucose fetch error", log: .default, type: .error)'
    ))

    # MEDIUM #1
    story.append(make_finding(
        "MEDIUM",
        "Medical Disclaimer Only Visible in Share/Export Text",
        "PredictionView.swift (line 232)",
        'The disclaimer "This prediction is for informational purposes only and should not replace professional medical advice" '
        "appears only when the user exports/shares a prediction. It is not displayed in the Dashboard, PredictionView, or any primary UI.",
        "The app generates HbA1c predictions with risk categories and clinical recommendations. Users see these predictions prominently "
        "in the Dashboard and Prediction views without any accompanying disclaimer.",
        "App Store Review Guideline 1.4.1 requires health apps to clearly indicate they do not provide medical advice. "
        "Users may make health decisions based on predictions without understanding their limitations.",
        "Add a visible disclaimer footer or banner to the DashboardView and PredictionView wherever predictions or risk categories are displayed. "
        'Consider also adding a disclaimer during onboarding.'
    ))

    # MEDIUM #2
    story.append(make_finding(
        "MEDIUM",
        "No Data Protection on CoreData Storage",
        "PersistenceController.swift (lines 156-172)",
        "The CoreData persistent store is loaded with default settings and no NSFileProtection attributes are configured.",
        "container.loadPersistentStores() uses default options. No NSPersistentStoreDescription options are set for "
        "NSPersistentStoreFileProtectionKey. The SQLite database file on disk is not encrypted at rest beyond device-level encryption.",
        "If a device is compromised (jailbreak, forensic extraction), health data including glucose readings, meal logs, "
        "and HbA1c predictions could be read from the unprotected database file.",
        'Set NSFileProtection on the store description: '
        'description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, '
        'forKey: NSPersistentStoreFileProtectionKey) before loading.'
    ))

    # MEDIUM #3
    story.append(make_finding(
        "MEDIUM",
        "Health Data Shared Without User Warning via ShareSheet",
        "PredictionView.swift (lines 204-236)",
        "The prepareShareContent() function builds a detailed text summary including predicted HbA1c value, confidence level, "
        "risk category, and contributing factor values, then passes it to the system ShareSheet.",
        "The share content includes specific health metrics. Once shared via Messages, email, or social media, "
        "there is no way to retract it. No confirmation dialog warns the user that they are about to share personal health data.",
        "Sensitive health information could be inadvertently shared publicly, creating privacy and potential legal exposure.",
        "Add a confirmation alert before presenting the ShareSheet that explicitly states the user is about to share personal health information. "
        "Consider offering a summary-only option that omits detailed contributing factor values."
    ))

    # MEDIUM #4
    story.append(make_finding(
        "MEDIUM",
        "fatalError() Calls in Production Code Path",
        "PersistenceController.swift (lines 144, 170)",
        'Two fatalError() calls exist in code that runs in production: one in preview data seeding and one in the main '
        'persistent store loading: fatalError("Core Data store failed to load: ...")',
        "While the preview data fatalError may only trigger in SwiftUI previews, the store-loading fatalError on line 170 "
        "is in the production code path. If CoreData fails to load (e.g., migration issue, disk full), the app will crash immediately.",
        "App Store reviewers may flag immediate crashes. Users who encounter CoreData migration issues after an update will lose access to the app entirely.",
        "Replace fatalError with graceful error handling: show an alert to the user, attempt recovery, or present a read-only fallback state."
    ))

    # LOW #1
    story.append(make_finding(
        "LOW",
        "Preview/Test Data Contains Realistic Health Profiles",
        "PreviewData.swift (lines 54-94), PersistenceController.swift (lines 52-94)",
        "Test data includes a specific health profile (age 52, male, 175 cm, 82 kg, Type 2 Diabetes, heart disease) "
        "with realistic glucose values (95-172 mg/dL) and named meals.",
        None,
        "While preview data should not ship in production builds, if it does, it creates a realistic-looking health profile "
        "that could confuse testers or reviewers.",
        "Use clearly fictional/placeholder data (e.g., age 0, name 'Test User') and ensure preview code is excluded from Release builds."
    ))

    # LOW #2
    story.append(make_finding(
        "LOW",
        "Glucose Unit Conversion Without Unit Tests",
        "HealthKitManager.swift (lines 332-337)",
        "Blood glucose values are converted from mmol/L to mg/dL using a multiplication factor of 18.0. "
        "The HealthKit unit construction is complex (moleUnit with molarMass divided by liter).",
        None,
        "An error in this conversion could cause incorrect glucose values to be stored and used in HbA1c predictions, "
        "potentially leading to incorrect health guidance.",
        "Add unit tests in DiabetesHbA1cPredictionTests to verify glucose conversion accuracy across a range of known values."
    ))

    # ===== COMPLIANCE MATRIX =====
    story.append(PageBreak())
    story.append(Paragraph("Compliance Assessment Matrix", styles["SectionHead"]))
    story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER_GRAY, spaceAfter=8))

    # HealthKit Guidelines
    story.append(Paragraph("Apple HealthKit Guidelines (Section 27)", styles["FindingTitle"]))
    hk_data = [
        [Paragraph("<b>Guideline</b>", styles["TableHeader"]),
         Paragraph("<b>Status</b>", styles["TableHeader"]),
         Paragraph("<b>Notes</b>", styles["TableHeader"])],
        [Paragraph("27.1 Data Access &amp; Authorization", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("Proper HKHealthStore.isHealthDataAvailable() check; correct async authorization flow", styles["TableCell"])],
        [Paragraph("27.2 No Third-Party Data Sharing", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("No network calls; no external SDKs; all data stays on-device", styles["TableCell"])],
        [Paragraph("27.3 No Use for Advertising", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("No advertising or analytics frameworks detected", styles["TableCell"])],
        [Paragraph("27.4 Encrypted/Protected Storage", styles["TableCell"]),
         status_text("FAIL"),
         Paragraph("CoreData store has no NSFileProtection configured", styles["TableCell"])],
        [Paragraph("27.5 Device Availability Check", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("HKHealthStore.isHealthDataAvailable() called before authorization", styles["TableCell"])],
        [Paragraph("27.6 No Clinical Records", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("No HKClinicalType or health-records entitlement used", styles["TableCell"])],
    ]
    hk_t = Table(hk_data, colWidths=[2.2*inch, 0.8*inch, 3.5*inch])
    hk_t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), DARK_BLUE),
        ('GRID', (0, 0), (-1, -1), 0.5, BORDER_GRAY),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, LIGHT_GRAY]),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    story.append(hk_t)
    story.append(Spacer(1, 14))

    # App Store Review Guidelines
    story.append(Paragraph("App Store Review Guidelines", styles["FindingTitle"]))
    asr_data = [
        [Paragraph("<b>Check</b>", styles["TableHeader"]),
         Paragraph("<b>Status</b>", styles["TableHeader"]),
         Paragraph("<b>Notes</b>", styles["TableHeader"])],
        [Paragraph("Valid Deployment Target", styles["TableCell"]),
         status_text("FAIL"),
         Paragraph("iOS 26.0 is invalid; must be corrected", styles["TableCell"])],
        [Paragraph("No Private/Undocumented APIs", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("Only public Apple frameworks used", styles["TableCell"])],
        [Paragraph("No Hardcoded Credentials", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("No API keys, secrets, or tokens found", styles["TableCell"])],
        [Paragraph("No External Network Calls", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("No URLSession, Alamofire, or HTTP requests", styles["TableCell"])],
        [Paragraph("No Deprecated APIs", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("All APIs are current", styles["TableCell"])],
        [Paragraph("No Tracking Frameworks", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("No analytics, ads, or tracking SDKs", styles["TableCell"])],
        [Paragraph("Privacy Declarations Accurate", styles["TableCell"]),
         status_text("FAIL"),
         Paragraph("NSHealthUpdateUsageDescription declared but not used", styles["TableCell"])],
        [Paragraph("Medical Disclaimer (1.4.1)", styles["TableCell"]),
         status_text("PARTIAL"),
         Paragraph("Present in share text only; not in main UI", styles["TableCell"])],
        [Paragraph("Crash-Free Launch (2.1)", styles["TableCell"]),
         status_text("PARTIAL"),
         Paragraph("fatalError on CoreData load failure could crash on launch", styles["TableCell"])],
    ]
    asr_t = Table(asr_data, colWidths=[2.2*inch, 0.8*inch, 3.5*inch])
    asr_t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), DARK_BLUE),
        ('GRID', (0, 0), (-1, -1), 0.5, BORDER_GRAY),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, LIGHT_GRAY]),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    story.append(asr_t)
    story.append(Spacer(1, 14))

    # Privacy & Data Protection
    story.append(Paragraph("Privacy &amp; Data Protection", styles["FindingTitle"]))
    priv_data = [
        [Paragraph("<b>Check</b>", styles["TableHeader"]),
         Paragraph("<b>Status</b>", styles["TableHeader"]),
         Paragraph("<b>Notes</b>", styles["TableHeader"])],
        [Paragraph("No Off-Device Data Transmission", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("All data remains local on device", styles["TableCell"])],
        [Paragraph("CoreData File Protection", styles["TableCell"]),
         status_text("FAIL"),
         Paragraph("No NSFileProtection configured", styles["TableCell"])],
        [Paragraph("Minimal Permission Footprint", styles["TableCell"]),
         status_text("PASS"),
         Paragraph("Only HealthKit permissions; no camera/location/contacts", styles["TableCell"])],
        [Paragraph("No Health Data in Logs", styles["TableCell"]),
         status_text("FAIL"),
         Paragraph("40+ unguarded print() statements in production code", styles["TableCell"])],
        [Paragraph("Share Export Safety", styles["TableCell"]),
         status_text("PARTIAL"),
         Paragraph("Exports detailed health metrics without confirmation warning", styles["TableCell"])],
    ]
    priv_t = Table(priv_data, colWidths=[2.2*inch, 0.8*inch, 3.5*inch])
    priv_t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), DARK_BLUE),
        ('GRID', (0, 0), (-1, -1), 0.5, BORDER_GRAY),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, LIGHT_GRAY]),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    story.append(priv_t)

    # ===== REMEDIATION PRIORITY =====
    story.append(PageBreak())
    story.append(Paragraph("Remediation Priority", styles["SectionHead"]))
    story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER_GRAY, spaceAfter=8))

    # Priority 1
    story.append(Paragraph(
        f'<font color="{CRITICAL_RED.hexval()}"><b>Priority 1 - Must Fix Before App Store Submission</b></font>',
        styles["FindingTitle"]))
    for item in [
        "Fix iOS deployment target from 26.0 to a valid version (e.g., 16.0 or 17.0)",
        "Remove NSHealthUpdateUsageDescription from Info.plist and project.pbxproj, or implement HealthKit write functionality",
    ]:
        story.append(Paragraph(f"\u2022  {item}", styles["BulletItem"]))
    story.append(Spacer(1, 8))

    # Priority 2
    story.append(Paragraph(
        f'<font color="{HIGH_ORANGE.hexval()}"><b>Priority 2 - Should Fix Before Production Release</b></font>',
        styles["FindingTitle"]))
    for item in [
        "Wrap all print() statements in #if DEBUG or replace with os_log() with appropriate privacy levels",
        "Add NSFileProtection to CoreData persistent store description",
        "Add visible medical disclaimer to Dashboard and Prediction views",
        "Replace fatalError() in PersistenceController.swift with graceful error handling",
    ]:
        story.append(Paragraph(f"\u2022  {item}", styles["BulletItem"]))
    story.append(Spacer(1, 8))

    # Priority 3
    story.append(Paragraph(
        f'<font color="{MEDIUM_YELLOW.hexval()}"><b>Priority 3 - Recommended Improvements</b></font>',
        styles["FindingTitle"]))
    for item in [
        "Add confirmation dialog before sharing health data via ShareSheet",
        "Replace realistic PII in preview/test data with clearly fictional placeholders",
        "Add unit tests for glucose mmol/L to mg/dL conversion",
        "Consider adding a data privacy policy accessible within the app",
    ]:
        story.append(Paragraph(f"\u2022  {item}", styles["BulletItem"]))

    # Positive findings
    story.append(Spacer(1, 16))
    story.append(Paragraph("Positive Findings", styles["SectionHead"]))
    story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER_GRAY, spaceAfter=8))
    for item in [
        "No network calls or external data sharing detected - all health data stays on-device",
        "No advertising, analytics, or tracking frameworks integrated",
        "No private or undocumented Apple APIs used",
        "No hardcoded API keys, secrets, or credentials found",
        "HealthKit authorization follows Apple's recommended async/await pattern",
        "Proper HKHealthStore.isHealthDataAvailable() device check before authorization",
        "No clinical health records (HKClinicalType) accessed",
        "Minimal permission footprint - only HealthKit, no camera/location/contacts/etc.",
        "Clean, well-documented Swift codebase with proper separation of concerns",
        "CoreData deduplication logic prevents duplicate HealthKit imports",
    ]:
        story.append(Paragraph(f'<font color="{PASS_GREEN.hexval()}">\u2713</font>  {item}', styles["BulletItem"]))

    doc.build(story)
    print(f"PDF generated: {OUTPUT}")


if __name__ == "__main__":
    build_pdf()
