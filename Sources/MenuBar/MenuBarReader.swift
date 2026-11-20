import AppKit
import ApplicationServices

public struct MenuTitleItem: Equatable {
    public enum Kind {
        case apple
        case appName
        case normal
    }

    public let title: String
    public let frame: CGRect // global CG coordinates (top-left origin)
    public let kind: Kind
    public let selected: Bool
    public let enabled: Bool

    public init(title: String, frame: CGRect, kind: Kind, selected: Bool, enabled: Bool) {
        self.title = title
        self.frame = frame
        self.kind = kind
        self.selected = selected
        self.enabled = enabled
    }
}

private func axCopyValue(_ el: AXUIElement, _ attr: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success ? v : nil
}

private func axGetPoint(_ v: CFTypeRef?) -> CGPoint? {
    guard let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var p = CGPoint.zero
    return AXValueGetValue(v as! AXValue, .cgPoint, &p) ? p : nil
}

private func axGetSize(_ v: CFTypeRef?) -> CGSize? {
    guard let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var s = CGSize.zero
    return AXValueGetValue(v as! AXValue, .cgSize, &s) ? s : nil
}

private let menuBarObserverCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon = refcon else { return }
    Unmanaged<MenuBarReader>.fromOpaque(refcon).takeUnretainedValue().scheduleRefresh()
}

public final class MenuBarReader {
    public var onChange: (() -> Void)?
    public private(set) var items: [MenuTitleItem] = []

    private var appElement: AXUIElement?
    private var observer: AXObserver?
    private var isPendingRefresh = false

    /// True when every menu title is available and non-empty.
    /// If false, the overlay MUST NOT cover the system menu bar so native buttons are never hidden.
    public var isDrawable: Bool {
        !items.isEmpty && items.dropFirst().allSatisfy { !$0.title.isEmpty }
    }

    public init() {}

    deinit {
        detach()
    }

    public func attach(to app: NSRunningApplication?) {
        detach()
        guard let app = app, AXIsProcessTrusted() else {
            update([])
            return
        }

        let pid = app.processIdentifier
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(el, 0.25)
        appElement = el

        var obs: AXObserver?
        if AXObserverCreate(pid, menuBarObserverCallback, &obs) == .success, let obs = obs {
            let ref = Unmanaged.passUnretained(self).toOpaque()
            let notifications = [
                kAXMenuOpenedNotification,
                kAXMenuClosedNotification,
                kAXMenuItemSelectedNotification,
                kAXTitleChangedNotification,
                kAXUIElementDestroyedNotification,
                kAXCreatedNotification
            ]
            for n in notifications {
                AXObserverAddNotification(obs, el, n as CFString, ref)
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
            observer = obs
        }

        refresh()
    }

    public func detach() {
        if let obs = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        }
        observer = nil
        appElement = nil
    }

    public func scheduleRefresh() {
        guard !isPendingRefresh else { return }
        isPendingRefresh = true
        DispatchQueue.main.async { [weak self] in
            self?.isPendingRefresh = false
            self?.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.refresh()
            }
        }
    }

    public func refresh() {
        guard let el = appElement, AXIsProcessTrusted() else {
            update([])
            return
        }

        guard let barRef = axCopyValue(el, kAXMenuBarAttribute),
              CFGetTypeID(barRef) == AXUIElementGetTypeID() else {
            update([])
            return
        }

        let bar = barRef as! AXUIElement
        guard let children = axCopyValue(bar, kAXChildrenAttribute) as? [AXUIElement] else {
            update([])
            return
        }

        let attrs = [
            kAXTitleAttribute,
            kAXPositionAttribute,
            kAXSizeAttribute,
            kAXSelectedAttribute,
            kAXEnabledAttribute
        ] as CFArray

        var results: [MenuTitleItem] = []
        for (i, child) in children.enumerated() {
            var values: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(child, attrs, [], &values) == .success,
                  let arr = values as? [AnyObject], arr.count == 5 else {
                continue
            }

            let title = arr[0] as? String ?? ""
            guard let pos = axGetPoint(arr[1]), let size = axGetSize(arr[2]), size.width > 1, size.height > 1 else {
                continue
            }

            let kind: MenuTitleItem.Kind = (i == 0) ? .apple : ((i == 1) ? .appName : .normal)
            let selected = (arr[3] as? Bool) ?? false
            let enabled = (arr[4] as? Bool) ?? true

            results.append(MenuTitleItem(title: title, frame: CGRect(origin: pos, size: size), kind: kind, selected: selected, enabled: enabled))
        }

        update(results)
    }

    private func update(_ newItems: [MenuTitleItem]) {
        guard newItems != items else { return }
        items = newItems
        onChange?()
    }
}
