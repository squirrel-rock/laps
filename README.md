# laps

A small, standalone iPhone app that helps Richard keep up his daily indoor walking circuit.

**One lap** = down the stairs (holding the handrail), back up. (The spin around the living room is now one of the stand-up choices.)
**One set** = 3 laps. **Daily goal** = 10 walking credits: each lap is one, and each walk down to the car and back is one (a turquoise dot). On a day with a car walk, 9 laps reach the goal; without one, 10. After 10, a gold ring and 3 gold dots offer a bonus up to **13**, never required.

## What it does

- **Today:** one big "Completed a lap!" button, a progress ring toward 10, and dots: turquoise for car walks, teal sets of 3, then gold bonus dots once he reaches 10. Includes "Bathroom break" (pauses and reminds after 10 min), "Finished for now", "Remind me later" (30 min), and "Undo last lap" (asks first).
- **This Week:** two stacked Swift Charts bar charts of the last 7 days. Walking: car walks (turquoise), laps up to 10 (teal), then gold, with a goal line at 10. Standing up: face lotion (cream), times up to the goal (violet), then gold, with a goal line at the standing goal. Shows weekly totals. Tap any day to fix mistakes.
- **Standing up** (on Today, below the laps): a violet ring and pills toward a daily goal of 10 (adjustable on the Reminders tab). A big "I stood up" button, "Give me an idea" for suggestions, and the face lotion as a cream pill that counts once a day. Extras past the goal are gold.
- **Everyday:** "Walked to the car" (earns a walking credit, with Undo) or a custom note (doesn't).
- **Picture** (optional): each day a photo from his own collection is uncovered a tile at a time as he walks and stands up, in a scattered order. 16, 20 or 25 tiles; **Determined** (10 walking, the rest standing up, gold laps count) or **Flexible** (any mix). The celebration banner shows each new tile. Finished pictures go to a gallery by date, with the challenge and what he did that day. Photos are added, cropped to 4:5, skipped, removed and reordered in Reminders → Manage photos, so upcoming ones stay hidden.
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

Everything is stored on the phone: activity in `Application Support/walks.json`, the picture reward in `Application Support/Pictures/` (its own file, so it can never change activity records). There's no account, cloud, or HealthKit.
