# Food page proposal for laps

November 28, 2026 · Kelly Durkin

## Summary

A new Food page lets Richard record what he eats in a few big taps, and fills an apple pie toward his 2,000-calorie goal. Today Kelly does all the counting. The page puts Richard in charge of it, with the sounds, buzzes and animations he loves from phone games.

- **Two taps for most foods:** he taps what he ate, taps in the calories, then taps Add.
- **One tap for Kate Farms:** 455 calories goes straight in, with a big cha-ching.
- **The app works out protein and fiber** from the food he picked, so neither of them has to.
- **Food is not an activity.** He eats sitting down, so it never counts toward his activity ring or the picture reward. It has its own reward: the pie.
- **Kelly gets notes, charts and exports** to see the trend and share it with his care team.

## How Richard records food

The Food page shows a grid of big food buttons, one per food or recipe Kelly makes. Recording takes three steps:

1. **He taps the food,** for example "Smoothie". A large panel opens with that food's name at the top.
2. **He taps in the calories** with four big buttons: **+100, +50, +10, +5**.
    - Each tap clicks and buzzes, and the running total rolls up in large numbers. For 230: two taps on +100, three on +10.
    - **Take away** and **Start over** buttons fix extra taps from his tremor. Nothing counts until he taps Add.
3. **He taps Add.** Cha-ching, the total goes onto today's scoreboard, and the pie updates.

For the one-tap foods, the steps are shorter:

- **Kate Farms** skips step 2: one tap adds 455 calories with the biggest cheer. Its button shows "1 of 2 today", then "2 of 2".
- **Scrambled eggs** shows three buttons instead of the calorie panel: **1 egg, 2 eggs, 3 eggs**.

Other details:

- **Undo:** an Undo bar for 8 seconds after each Add, plus Undo on every entry in today's list, the same as Activities.
- **Taps:** the calorie buttons accept fast repeat taps on purpose. Add and the food buttons keep the double-tap guard, so a shaky second tap doesn't record twice.

**Idea to discuss: portion buttons.** Richard doesn't know how to calculate calories, which is the problem we're solving. For a batch with known numbers, like a Huel mix, the panel could offer **A quarter, Half, Three quarters, All of it** above the calorie buttons. He picks how much he drank and the app does the arithmetic. The calorie buttons stay underneath for anything else, or for a number Kelly tells him.

## The pie and rewards

Each day is one whole apple pie of 2,000 calories, cut into 8 slices of 250 calories each.

- **The pie:** it sits at the top of the Food page, made from Kelly's own pie photo. Empty slices show as a faint outline. Each time his total passes another 250, a slice drops into place with a sound.
- **Under the pie:** today's total in big numbers ("1,340 of 2,000"), with protein and fiber in smaller type.
- **A whole pie** gets the big celebration: fanfare, confetti and a strong buzz, like reaching the activity goal.
- **Past 2,000 is gold.** In cancer treatment more is better, so the app never warns about too many calories. Extra calories show as gold, the same way extra activities do.
- **Sounds:** a soft click on each calorie tap, a cha-ching on Add, a slice sound, and the fanfare for a whole pie. The cha-ching is new; the others can reuse or adapt the sounds the app already has.
- **No pressure:** an unfinished pie never turns amber and never nags. Tomorrow starts a fresh pie.

## Protein and fiber, worked out automatically

Richard enters only calories; the app works out protein and fiber in proportion, from the food he picked.

Each food or recipe stores its calories, protein and fiber for one full serving. When he records part of it, the app scales the protein and fiber by the same share.

- **Example:** Huel with half and half is about 560 calories and 44 g protein per batch. If he enters 140 calories (a quarter), the app records about 11 g protein.
- **Estimates:** these are estimates, as good as the recipe numbers behind them. That matches how Kelly counts today.
- **Who sees what:** Richard sees calories and the pie. Protein and fiber show smaller, mainly for Kelly, and in the charts and exports.
- **Changing recipes:** Kelly can edit them in the app (see Build phases). Past days keep the numbers they were recorded with.

## Daily notes

Each day gets a free-text notes box, which Kelly can dictate into using the microphone on the iPhone keyboard.

- **Where:** at the bottom of the Food page for today, and on each past day's detail page.
- **For things like:** "Struggled with the Huel, only drank a quarter by 3 pm" or "Ate all the mashed potatoes."
- **Dictation** is built into iOS, so it needs no extra setup or permissions.
- **Notes are included in the export,** next to that day's numbers.
- **Question:** should notes cover the whole day (energy, walks, mood), or just food? One box per day can hold both.

## Charts and exporting the data

Yes, the data can be exported: a Share button sends a spreadsheet file or a printable summary through the normal iPhone share sheet.

**Charts in the app:**

- **This Week:** a bar chart of calories per day, with the 2,000 goal as a line and gold above it. He likes charts.
- **Each past day's detail page:** its pie, total, protein, fiber, the list of foods, and the notes.

**Export (Share button):**

- **Spreadsheet (CSV):** one row per entry, with date, time, food, calories, protein, fiber, plus that day's notes. It opens in Numbers, Excel or Google Sheets.
- **Printable summary (PDF):** daily totals for a chosen range (last 7 days, last 30 days, or all), for the oncologist or dietitian.
- **Sending it:** by email, Messages, AirDrop to the Mac, or saving to Files. The phone sends it only when Kelly or Richard taps Share.
- **Activities and laps** could go in the same export, so the care team sees movement and food side by side.

## Where it goes in the app

The iPhone tab bar shows only five tabs; a sixth hides the rest behind a confusing "More" button. So one existing tab has to move.

Today's tabs are Laps, Activities, This Week, Reminders and Picture.

| Option | New tabs | Trade-off |
| --- | --- | --- |
| A (recommended) | Laps, Activities, Food, This Week, Picture | Reminders moves behind a gear button on the Laps page. Kelly sets reminders; Richard rarely changes them. |
| B | Laps, Activities, Food, Reminders, Picture | This Week moves inside Food as a Charts section. Charts are harder for Richard to find. |
| C | Laps, Activities, Food, This Week, Reminders | Picture moves inside This Week. Hides a reward he enjoys. |

## Starting food list

These are the food buttons Richard would see, built from Kelly's labels and recipes; numbers marked ≈ are my estimates and need checking.

| Food button | One serving | Calories | Protein (g) | Fiber (g) | Built from |
| --- | --- | --- | --- | --- | --- |
| Kate Farms | 1 carton | 455 | ? | ? | One tap, no calorie entry |
| Huel, plain | 2 scoops (90 g) with hot water | 400 | 40 | 9 vanilla, 11 chocolate | Label |
| Huel, whole milk | 2 scoops + 1½ cups whole milk | 640 | 52 | 9 / 11 | Label + milk |
| Huel, half and half | 2 scoops + 8 tbsp half and half | ≈560 | ≈44 | 9 / 11 | Label + half and half (≈20 cal, ≈0.5 g protein per tbsp) |
| Steel-cut oats | ¼ cup dry + 1 cup whole milk + banana | ≈415 | ≈14 | ≈7 | Labels + a medium banana (≈105 cal, 1 g protein, 3 g fiber) |
| Oatmeal | ½ cup dry + 1 cup whole milk | 320 | 14 | 4 | Labels |
| Smoothie | Greek yogurt + berries + soy milk | ? | ? | ? | Amounts needed |
| Scrambled eggs | Per egg, + ½ tbsp butter + ½ tbsp olive oil | ≈180 | ≈6 | 0 | Shown as 1, 2 or 3 eggs |
| Mashed potatoes | ¾ cup + 1½ tbsp butter + 1 tbsp half and half | ≈270 | ≈3 | ≈2 | Estimate until the powdered package arrives |
| Chicken soup (puréed) | 1 serving (size?) | 190 | 9 | 2 | Kelly's numbers |
| Applesauce, unsweetened | ⅔ cup | 90 | 0 | 3 | Label |
| Cranberry sauce | ¼ cup | ? | 0 | ? | Label (calories unclear) |
| Greek yogurt, whole milk | ¾ cup | 170 | ? | <1 | Label (protein unclear) |
| Ricotta, whole milk | ¼ cup | ? | 5 | 0 | Label (calories missing) |
| Something else | Any amount | Tap-up | 0 | 0 | No protein or fiber counted |

**Ingredients behind the recipes** (these need no buttons of their own):

| Ingredient | Serving | Calories | Protein (g) | Fiber (g) |
| --- | --- | --- | --- | --- |
| Whole milk | 1 cup | 160 | 8 | 0 |
| Soy milk (Your Good Foods) | 1 cup | 84 | 8 | 1 |
| Berry mix | 1 cup | ≈70 | ≈2 | ≈5 |
| Cream cheese, whole | 2 tbsp (1 oz) | 90 | 1 | 0 |
| Liquid egg whites | 3 tbsp | 25 | 5 | 0 |
| Collagen powder | 1 scoop (21 g) | 80 | 19 | 0 |

**Numbers to check:**

- **Kate Farms:** protein and fiber per carton.
- **Cranberry sauce:** the label reads "calories 952" for ¼ cup. Probably 95 or 110?
- **Greek yogurt:** protein reads "1315 g". Probably 15 g?
- **Ricotta:** calories per ¼ cup are missing.
- **Smoothie:** the usual amount of yogurt, berries and soy milk. The notes say Silk; the soy milk label says Your Good Foods. Which one?
- **Steel-cut oats:** today's banana size, and whether the earlier ½ cup or the ¼ cup dry is right (the label numbers given are for ¼ cup).
- **Chicken soup:** the serving size.
- **Collagen, egg whites, cream cheese:** do these go into the smoothie, eggs or oatmeal? If so, which recipe and how much?
- **Trader Joe's white bread** is discontinued. Leave bread off, or add a generic "Toast"?
- **Pea-potato soup** is off the menu.

## Build phases

Three builds, each tested on Richard before the next starts:

1. **Food page and pie.** The food buttons, calorie panel, Kate Farms one-tap, eggs by count, today's scoreboard with Undo, the pie from Kelly's photo, the sounds, and the new tab layout. The starting food list is built in.
2. **Notes, charts and export.** The daily notes box, calories on This Week and on each day's detail, and the CSV and PDF export.
3. **Food list editing.** A screen for Kelly to add, change or retire foods and recipes on the phone, without waiting for a new build. Useful as the Huel experiments change and the powdered potatoes arrive. It sits behind a Kelly-only gear so Richard can't change it by accident.

Portion buttons, if chosen, go in phase 1. Until phase 3, food list changes come through Kelly, then me, then a new TestFlight build.

## Open questions

- [ ] Portion buttons (a quarter, half, all) for batches like Huel: yes or no?
- [ ] Huel: one button per mix with the flavor set by Kelly, or a vanilla/chocolate choice each time? Six buttons is a lot.
- [ ] Tab layout: option A (Reminders behind a gear) or another?
- [ ] Does his dietitian give a protein goal? If so, show it under the pie.
- [ ] Daily notes: food only, or the whole day?
- [ ] A reminder notification for each Kate Farms (for example 10 am and 3 pm)?
- [ ] Should the export include activities and laps too?
- [ ] Richard's choice of reward: is the pie enough, or does he want something more?
- [ ] Kelly's pie photo, dropped into the laps folder.
