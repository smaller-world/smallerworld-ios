# Agent Instructions

## Building

**Never build for the simulator. Always build for the connected physical device.**

```sh
xcodebuild -scheme smallerworld -destination 'platform=iOS,name=cowphone' build
```

List connected devices with `xcrun devicectl list devices` and target one whose
state is `connected`.
