import Cocoa
import ApplicationServices

// Clicking the Dock icon of the app that is already frontmost hides it (like ⌘H).
// Hold any modifier key to get the normal Dock behaviour.
//
// The tap sits in front of every left click on the system, so the click path runs the
// cheapest checks first and only talks to the Dock for clicks near a screen edge.

/// How far from a display's bottom/left/right edge a Dock icon can reach. Covers the
/// largest Dock size and magnification System Settings allows.
let dockReach: CGFloat = 300
let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]

var eventTap: CFMachPort?
var swallowNextMouseUp = false
var displays: [CGRect] = []
var dock: (app: NSRunningApplication, element: AXUIElement)?

/// Display bounds in global top-left coordinates, the same space as event locations.
func refreshDisplays() {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    displays = ids.prefix(Int(count)).map(CGDisplayBounds)
}

func nearDockEdge(_ p: CGPoint) -> Bool {
    displays.contains { d in
        d.contains(p) && (p.y > d.maxY - dockReach || p.x < d.minX + dockReach || p.x > d.maxX - dockReach)
    }
}

/// The Dock's accessibility element, recreated only when the Dock restarts.
func dockElement() -> AXUIElement? {
    if let dock, !dock.app.isTerminated { return dock.element }
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
    let element = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(element, 0.1)
    dock = (app, element)
    return element
}

/// Bundle path of the app whose Dock icon is under `point`, if any.
func dockItemPath(at point: CGPoint) -> String? {
    guard let dockElement = dockElement() else { return nil }
    var hit: AXUIElement?
    let error = AXUIElementCopyElementAtPosition(dockElement, Float(point.x), Float(point.y), &hit)
    if error == .invalidUIElement || error == .cannotComplete { dock = nil }
    var values: CFArray?
    guard error == .success, let item = hit,
          AXUIElementCopyMultipleAttributeValues(item, [kAXSubroleAttribute, kAXURLAttribute] as CFArray, [], &values) == .success,
          let pair = values as? [Any], pair.count == 2,
          pair[0] as? String == "AXApplicationDockItem",
          let url = pair[1] as? NSURL
    else { return nil }
    return (url as URL).standardizedFileURL.path
}

/// Whether the app has at least one normal on-screen window. With none, the Dock
/// click should go through so the app can open a new window as usual.
func hasVisibleWindow(_ app: NSRunningApplication) -> Bool {
    guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return true }
    return windows.contains {
        ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier &&
        ($0[kCGWindowLayer as String] as? Int) == 0
    }
}

let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
    case .leftMouseDown:
        let point = event.location
        guard event.flags.intersection(modifiers).isEmpty,
              nearDockEdge(point),
              let front = NSWorkspace.shared.frontmostApplication,
              let frontPath = front.bundleURL?.standardizedFileURL.path,
              dockItemPath(at: point) == frontPath,
              hasVisibleWindow(front)
        else { break }
        front.hide()
        swallowNextMouseUp = true
        return nil
    case .leftMouseUp:
        if swallowNextMouseUp {
            swallowNextMouseUp = false
            return nil
        }
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

func installTap() -> Bool {
    let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                      eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: nil)
    else { return false }
    eventTap = tap
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    fputs("\(Date()) listening for Dock clicks\n", stderr)
    return true
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

refreshDisplays()
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                       object: nil, queue: .main) { _ in refreshDisplays() }

// Ask for Accessibility once, then wait until it is granted.
let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(prompt) || !installTap() {
    fputs("\(Date()) waiting for Accessibility permission\n", stderr)
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
        if AXIsProcessTrusted() && installTap() { timer.invalidate() }
    }
}

app.run()
