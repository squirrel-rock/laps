# laps

A small, standalone iPhone app that helps Richard keep up his daily indoor walking circuit.

**One lap** = down the stairs (holding the handrail), back up, once around the living room.
**One set** = 3 laps. **Daily goal** = 3 sets (9 laps). **4 sets (12 laps)** is gently encouraged and never required.

## What it does

- **Today:** one big "Completed a lap!" button, a progress ring toward 9, and set dots (the 4th set is dashed: there if he wants it). Includes "Bathroom break" (pauses and reminds after 10 min), "Finished for now", "Remind me later" (30 min), and "Undo last lap" (asks first).
- **This Week:** a Swift Charts bar chart of the last 7 days, with a goal line at 9 and a dashed line at 12. Shows the weekly total, sets, and best day. Tap any day to fix mistakes.
- **Everyday:** "Walked to the car" or a custom note. Kept separate from laps.
- **Reminders:** editable times (default 7:30 AM, 1:00 PM, 4:00 PM), pause for today, and a sounds on/off switch.

Taps on the lap button within 2.5 seconds of each other count once, which helps with a hand tremor.
After 9 laps, the rest of that day's reminders invite a bonus set. After 12, they stay quiet for the rest of the day.

## Build

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml` is the source of truth).

```bash
xcodegen generate
open laps.xcodeproj
```

Run tests:

```bash
xcodebuild test -project laps.xcodeproj -scheme laps -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

## Data

Everything is stored on the phone in `Application Support/walks.json`. There's no account, cloud, or HealthKit.
