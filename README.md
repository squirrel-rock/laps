# laps

A small, standalone iPhone app that helps Richard keep up his daily indoor walking circuit.

**One lap** = down the stairs (holding the handrail), back up. (The spin around the living room is now one of the stand-up choices.)
**One set** = 3 laps. **Daily goal** = 10 walking credits: each lap is one, and each walk down to the car and back is one (a turquoise dot). On a day with a car walk, 9 laps reach the goal; without one, 10. After 10, a gold ring and 3 gold dots offer a bonus up to **13**, never required.

## What it does

- **Today:** one big "Completed a lap!" button, a progress ring toward 10, and dots: turquoise for car walks, teal sets of 3, then gold bonus dots once he reaches 10. Includes "Bathroom break" (pauses and reminds after 10 min), "Finished for now", "Remind me later" (30 min), and "Undo last lap" (asks first).
- **This Week:** a Swift Charts bar chart of the last 7 days, with a goal line at 9 and a dashed line at 12. Shows the weekly total, sets, and best day. Tap any day to fix mistakes.
- **Everyday:** "Walked to the car" (earns a walking credit, with Undo) or a custom note (doesn't).
- **Reminders:** editable times (default 7:30 AM, 1:00 PM, 4:00 PM), pause for today, and a sounds on/off switch.

Taps on the lap button within 0.6 seconds of each other count once, which helps with a hand tremor.
After 10 credits, the rest of that day's reminders invite a bonus. After 13, they stay quiet for the rest of the day.

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
