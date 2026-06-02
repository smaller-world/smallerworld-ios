# Postmortem: Cold Start Notification Crash

## Incident
**Date:** 2026-01-30
**Build:** 0.5 (21)
**Exception:** `EXC_BREAKPOINT` - Index out of range in `currentTab()`

## Summary
App crashed within 90ms of cold start when user tapped a push notification. Race condition between async tab initialization and synchronous notification delegate callback caused array index out of bounds.

## Root Cause
When the app launches from a notification tap:

1. `scene(_:willConnectTo:options:)` starts an async `Task` to call `loadTabs()`
2. Before `loadTabs()` completes, iOS delivers the notification via `userNotificationCenter(_:didReceive:withCompletionHandler:)`
3. Notification handler calls `routeTowards()` → `currentTab()`
4. `currentTab()` accesses `HotwireTab.all[tabBarController.selectedIndex]`
5. `selectedIndex` returns `NSNotFound` (`Int.max`) when tab bar has no view controllers
6. Array access with index `Int.max` crashes

## The Fix
Moved `UNUserNotificationCenter.current().delegate = self` from top of `scene(_:willConnectTo:options:)` to end of `loadTabs()`. This ensures the delegate only receives callbacks after tabs are initialized.

The notification is still handled correctly via `connectionOptions.notificationResponse`, which stores `targetURL` for later routing through `requestDidFinish()`.

## Android Implications
Similar race condition possible on Android:

- `onCreate()` with notification intent
- Async UI initialization (fragments, view pager)
- Early access to `viewPager.currentItem` or fragment manager before setup completes

**Recommendation:** Guard against accessing UI state before initialization completes, or defer notification intent processing until UI is ready.

## Code Reference
- Fix: `smallerworld/SceneController.swift:72`
- Crash site: `smallerworld/SceneController.swift:42`
