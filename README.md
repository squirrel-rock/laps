# laps

A small, standalone iPhone app that helps Richard keep up his daily indoor walking circuit.

**One lap** = down the stairs (holding the handrail), back up. (The spin around the living room is now an anytime activity.)
**One set** = 3 laps. **Daily goal** = 10 walking credits: each lap is one, and each walk down to the car and back is one (a turquoise dot). On a day with a car walk, 9 laps reach the goal; without one, 10. After 10, a gold ring and 3 gold dots offer a bonus up to **13**, never required.

## What it does

- **Laps:** one big "Completed a lap!" button, a progress ring toward 10, and dots: turquoise for car walks, teal sets of 3, then gold bonus dots once he reaches 10. Below it: "Finished for now" or "Remind me later" (30 min), then "Walked to the car" (a walking credit, with an 8-second Undo), and "Undo last lap" (asks first). No bathroom-break button: he just takes one.
- **Activities:** a violet ring and pills toward a daily goal of 10 activities (adjustable on the Reminders tab), with face washes in cream and extras past the goal in gold. Every activity is recorded with a single tap (honor system: it counts when he gets up from sitting to do it), with an 8-second Undo. Four sections:
  - **Daily activities:** morning face wash and lotion (large; amber if not done by noon), evening face wash, dishwasher check or unload, heel raises, kitchen squats, stand-ups. Once he reaches his goal, unfinished heel raises, squats and stand-ups turn amber.
  - **Extra accomplishments:** balance exercises and floor stretches. Never amber; finishing one gets a big cheer.
  - **Anytime:** repeatable, alphabetical by subject, each with today's count: bathroom, clap overhead, fire, laundry, living room spin, march in place, rain gauge, shower, squirrels, teeth, water glass, and "Something else".
  - **Completed today:** everything done today with its time and an Undo. Checked items move here.
- **This Week:** two stacked Swift Charts bar charts of the last 7 days. Walking: car walks (turquoise), laps up to 10 (teal), then gold, with a goal line at 10. Activities: face washes (cream), activities to the goal (violet), then gold, with a goal line at the activity goal. Shows weekly totals. Tap any day to fix mistakes.
- **Picture** (optional): each day a photo from his own collection is uncovered a tile at a time as he walks and does activities, in a scattered order. 16, 20 or 25 tiles; **Determined** (10 walking, the rest activities, gold laps count) or **Flexible** (any mix). The celebration banner shows each new tile. Finished pictures go to a gallery by date, with the challenge and what he did that day. Photos are added, cropped to 4:5, skipped, removed and reordered in Reminders → Manage photos, so upcoming ones stay hidden.
- **Reminders:** walk reminder times (default 7:30 AM, 1:00 PM, 4:00 PM), half-hourly activity reminders ("Time to get up, Richard!", face wash first until it's done; tapping opens Activities), pause for today, the picture reward settings, and a sounds on/off switch.

Taps on the lap and car buttons within 0.6 seconds of each other count once, and on the Activities screen any two taps within a second count once (so a row sliding up can't be hit by mistake). This helps with a hand tremor.
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
