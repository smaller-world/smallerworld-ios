# Hotwire-Native iOS — Nuances & Gotchas

Notes on the parts of [`hotwire-native-ios`](https://github.com/hotwired/hotwire-native-ios) that aren't obvious from the public API but matter for this app. Source paths refer to that repo (cloned at `~/Projects/hotwire-native-ios`).

## Architecture: two sessions, two webviews

`Navigator` owns **two** `Session` instances, each with its own `WKWebView`:

- `session` — drives the main navigation stack (the root `UINavigationController`).
- `modalSession` — drives the modal navigation stack (a separate `UINavigationController` that gets `present()`ed when needed).

`Navigator.activeWebView` switches between them based on whether a modal is currently presented:

```swift
// Source/Turbo/Navigator/Navigator.swift
public var activeWebView: WKWebView {
    if activeNavigationController == rootViewController {
        return session.webView
    }
    return modalSession.webView
}

// Source/Turbo/Navigator/NavigationHierarchyController.swift
var activeNavigationController: UINavigationController {
    navigationController.presentedViewController != nil
        ? modalNavigationController
        : navigationController
}
```

Implications:

- **Any** presented modal flips `activeWebView` to `modalSession.webView` — even a custom non-`Visitable` view controller (e.g. our QR scanner). Hotwire only checks `presentedViewController != nil`; it doesn't care what the modal *is*.
- `modalSession` is created once in `Navigator.init` and **never reset on modal dismissal**. Its `webView` retains whatever URL it last loaded across modal open/close cycles. So if a modal showed `/foo` and got dismissed, then later a custom-controller modal (scanner, picker, etc.) is presented, `activeWebView.url` reads as `/foo` — stale leftover from the previous modal. (Search `Source/Turbo/Navigator/Navigator.swift` for `modalSession =` — the only reassignment is on webview-process termination recovery.)

**Lesson:** never trust `activeWebView.url` if any modal is currently presented, especially a non-Visitable one.

## `path-configuration.json` shapes routing

Path properties drive the routing decisions HotwireNative makes for each visit proposal. The relevant keys we use:

| Property | Effect |
|---|---|
| `presentation: "replace_root"` | The match clears the main nav stack and becomes the root. Used for `/home`, `/session/new`. |
| `context: "modal"` | Visit is routed to `modalSession` and presented via `modalNavigationController`. |
| `pull_to_refresh_enabled: false` | Disables PTR on the visitable view. |
| `interactive_content_pop_gesture_enabled: false` | Disables iOS swipe-back gesture on the visitable. **Nothing to do with routing decisions** — purely a VC gesture flag. Don't confuse with `unroutable`. |
| `unroutable: true` | App-specific marker (we set this, not HotwireNative). Read in `SceneController.routeSegments` to skip a depth during incremental routing. |
| `view_controller: "..."` | Identifier the `NavigatorDelegate.handle` switch matches against to return a custom VC via `acceptCustom`. |

## Visit lifecycle: `requestDidFinish` vs `visitDidComplete`

A single Turbo JS-driven visit fires these stages in order:

```
visitStarted
visitRequestStarted
visitRequestFinished   ← Visit.finishRequest() → Session.sessionDidFinishRequest
                                              → NavigatorDelegate.requestDidFinish(at:)
visitRequestCompleted
visitRendered          ← Visit.complete() → SessionDelegate.visitDidComplete
visitCompleted         ← page is now actually displayed; webView.url updates here
```

`requestDidFinish(at:)` (the only "something landed" callback exposed on `NavigatorDelegate`) fires when the **HTTP response** arrives — *before* the page is rendered. The underlying `WKWebView.url` doesn't update until `visitRendered`/`visitCompleted`, one render cycle later.

**Lesson:** inside `requestDidFinish(at: url)`, the `url` parameter is the URL of the visit that just finished. **Use it instead of `activeWebView.url`** when deciding the next routing step. The webview is still painting the previous page.

### Also: `finishRequest` is called on cancellation

```swift
// Source/Turbo/Visit/JavaScriptVisit.swift
override func cancelVisit() {
    log("cancelVisit")
    bridge.cancelVisit(withIdentifier: identifier)
    finishRequest()   // ← still calls our delegate!
}
```

So every cancelled visit *also* fires `requestDidFinish`. If your delegate re-issues a route based on stale state, you can get a runaway cancel→re-route→cancel loop. Using the URL parameter (which is the URL of the cancelled visit, i.e. the logical "where we are") instead of `activeWebView.url` keeps the chain coherent.

### Why not hook a later callback?

`visitDidComplete` / `visitDidRender` are not exposed on `NavigatorDelegate` — only the internal `SessionDelegate`/`VisitDelegate`. Reaching them requires subclassing or a custom delegate shim. Not worth it: for routing decisions, the logical URL hop (`requestDidFinish`'s `url` param) is exactly the right signal; waiting for paint adds latency without changing the answer. Reach for render-time callbacks only if you need pixel-accurate timing (animations, screenshots, layout measurements).

## `dismiss(animated:)` and CATransaction

```swift
// DOES NOT WORK as expected:
CATransaction.begin()
CATransaction.setCompletionBlock { /* runs immediately, before dismiss completes */ }
controller.dismiss(animated: true)
CATransaction.commit()
```

`dismiss(animated:)` runs its animation in its **own internal** CATransaction. The outer transaction we begin/commit has no animations of its own, so its completion fires synchronously at commit time — before the modal is actually gone.

**Lesson:** use `dismiss(animated:completion:)` instead. The completion handler genuinely fires after dismissal finishes.

This matters especially with the modal-session quirk above: if you route immediately after a wrapped-but-not-really-awaited dismiss, the modal is still presented, `activeWebView` still resolves to `modalSession.webView`, and you read its stale URL.

## Server redirects on visits

When a visit's response is a same-origin redirect (e.g. `/world_key_grants/{token}` 302s to `/worlds/kai-s-world-…`), Hotwire handles it via `session(_:didProposeVisit:)` with `proposal.isRedirect == true` (`Source/Turbo/Navigator/Navigator.swift:174-182`):

```swift
public func session(_ session: Session, didProposeVisit proposal: VisitProposal) {
    if proposal.isRedirect {
        let animatePop = session === modalSession && proposal.context == .default
        pop(animated: animatePop)
    }
    route(proposal)
}
```

The default behavior pops the originating visitable and re-routes to the redirect destination. The redirect proposal is re-evaluated against the path configuration, so **a redirect from a modal path to a default-context path crosses session boundaries** — modal gets popped, redirected URL lands in the main session.

### ColdBootVisit vs JavaScriptVisit handle redirects differently

This is a subtle and confusing fork:

- **`ColdBootVisit`** (the *first* visit in a session, before Turbo's JS is loaded) detects a same-origin redirect during the initial HTML load and **swaps the URL inline** — same view, just shows the redirect target. No second `visitProposed` fires. Log marker: `[ColdBootVisit] Same-origin redirect detected: A -> B`.
- **`JavaScriptVisit`** (every subsequent visit) routes through Turbo's JS, which proposes a **new visit** for the redirect target with `action: replace` and `response.redirected: true`. This goes through `session(_:didProposeVisit:)` → pop + re-route.

So a flow can "work" on the first visit (modal stays open showing redirected URL) and break on the second (modal pops, redirected URL replaces main stack top). If you see "first time works, second time doesn't" with a redirect involved, this is almost certainly why.

### Turbo's default action for redirected proposals is `.replace`

The intent is "don't keep the trampoline URL in your history." That's the right default for in-session redirects.

But when the redirect *crosses* sessions (modal → main) it replaces whatever's on top of the main stack — including `/home`. If `/home` is a `replace_root` page, this strands the user with no back affordance.

### Mitigation: guard `replace_root` pages in `NavigatorDelegate.handle`

We can't modify `VisitProposal.options` from `handle`, but we *can* reject and re-issue:

```swift
if proposal.options.action == .replace,
    let top = navigator.rootViewController.topViewController as? Visitable,
    Self.isRootPath(top.currentVisitableURL)
{
    DispatchQueue.main.async {
        navigator.route(proposal.url, options: VisitOptions(action: .advance))
    }
    return .reject
}
```

`navigator.route(url, options:)` builds a fresh `VisitProposal` with no `response.redirected`, so `isRedirect` is false on the re-issue, no pop/re-route loop, action=advance pushes onto `/home` cleanly. The `DispatchQueue.main.async` lets the original `route(proposal)` flow unwind (handle returns `.reject`, no visit happens) before the new route fires.

This is implemented in `SceneController.handle(proposal:from:)` for our app.

## `requestDidFinish`'s `url` source

```swift
// Source/Turbo/Navigator/Navigator.swift
public func sessionDidFinishRequest(_ session: Session) {
    guard let url = session.activeVisitable?.initialVisitableURL else { return }
    Task { @MainActor in
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: url)
        delegate?.requestDidFinish(at: url)
    }
}
```

A few things to note:

- The `url` is the **initial** visitable URL (i.e. the URL the visit was *started* with), not necessarily the final rendered URL after redirects. For a `/world_key_grants/{token}` → `/worlds/…` redirect, `requestDidFinish` fires with `/world_key_grants/{token}` for the original visit, then again (after the redirect proposal re-routes) with the redirect destination.
- Both sessions (main and modal) call into the same delegate. The delegate doesn't know which session originated the call without checking. If that matters, you can inspect `navigator.session` vs `navigator.modalSession`.
- The dispatch is hopped through a `Task { @MainActor in … }` for cookie sync. That's an additional async hop between Hotwire's internal "request finished" and our delegate firing — usually negligible but means the delegate is not strictly synchronous with the visit lifecycle.

## Useful entry points in the source

When in doubt, these are the highest-signal files to read:

- `Source/Turbo/Navigator/Navigator.swift` — public API, session ownership, `SessionDelegate` glue.
- `Source/Turbo/Navigator/NavigationHierarchyController.swift` — modal vs main stack decisions, presentation context logic.
- `Source/Turbo/Navigator/NavigatorDelegate.swift` — the consumer-facing delegate protocol (limited surface).
- `Source/Turbo/Session/Session.swift` — visit ownership per session, `topmostVisitable` / `activeVisitable`.
- `Source/Turbo/Visit/Visit.swift` — `finishRequest()` vs `complete()` distinction.
- `Source/Turbo/Visit/JavaScriptVisit.swift` — the Turbo JS bridge events (`visitRequestFinished`, `visitRendered`, `visitCompleted`) mapping to `Visit` methods.
