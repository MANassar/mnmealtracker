# MN Meal Tracker: Functional Analysis For Native iOS Rebuild

This document describes the current Flutter/PWA-style app so screenshots can be paired with implementation notes when rebuilding as a native Xcode app.

## Product Summary

MN Meal Tracker is a local-first meal, macro, calorie, and weight tracker with optional AI meal analysis. The main experience is three tabs:

- Home/Today: daily calorie ring, macro progress, today's meal cards.
- History: past meals and weight logs grouped by date, with import/export.
- Weight: trend chart, daily weight logging, goal weight.

There is also a full-screen Add/Edit Meal flow and a Settings modal.

## App Architecture

- Entry point: `mobile/lib/main.dart`.
- State management: Riverpod `StateNotifierProvider`s.
- Navigation: `go_router`.
- Persistence:
  - Meals and weights: Isar database in app documents directory.
  - Settings: JSON stored in `SharedPreferences` under `app_settings`.
  - Meal photos: copied into app documents under `meal_photos/{uuid}.jpg`.
- Network/AI: `Dio` calls to either the hosted Netlify server, Anthropic, or OpenAI.
- UI style: custom Material widgets that mimic the existing PWA.

## Navigation Map

- Initial route: `/today`.
- Shell tabs:
  - `/today` -> `TodayScreen`.
  - `/history` -> `HistoryScreen`.
  - `/weight` -> `WeightScreen`.
- Floating action button from shell: pushes `/add`.
- `/settings`: full-screen dialog outside shell.
- `/add`: full-screen add/edit/repeat meal screen outside shell.

Native iOS equivalent:

- Use a `TabView` or UIKit tab bar with three tabs.
- Add a centered or floating add button that presents Add Meal.
- Present Settings modally.
- Present Add/Edit Meal as a full-screen cover or pushed detail, matching current screenshots.

## Theme And Visual System

Fonts expected by the design:

- Primary body: DM Sans.
- Display/title: Playfair Display.
- Numeric/macros: DM Mono.

Dark palette:

- Background `#0C1A10`
- Surface `#111F15`
- Card `#18281C`
- Border `rgba(255,255,255,0.06)`
- Text `#F0ECE3`
- Muted `#556358`
- Accent `#C9A84C`
- Mint `#6DB87A`
- Sky `#7DA8D4`
- Peach `#D4886A`
- Plum `#A882C4`
- Danger `#D46A5A`
- OpenAI/server color `#74AA9C`

Light palette:

- Background `#F7F4EC`
- Surface `#FFFAF0`
- Card `#FFFFFF`
- Border `rgba(24,40,28,0.12)`
- Text `#152018`
- Muted `#667268`
- Accent `#9F7B19`
- Mint `#2F8A48`
- Sky `#3C76AD`
- Peach `#B85F3C`
- Plum `#8153A6`

Theme setting values:

- `auto`: system theme.
- `light`: light mode.
- `dark`: dark mode.

## Data Models

### Meal

Stored fields:

- `id`: local Isar auto-increment id.
- `uuid`: stable backup/import id.
- `date`: `yyyy-MM-dd`.
- `timestamp`: milliseconds since epoch.
- `mealName`
- `calories`
- `protein`
- `carbs`
- `fat`
- `fiber`
- `provider`: `anthropic`, `openai`, `server`, `manual`, nullable.
- `confidence`: `high`, `medium`, `low`, nullable.
- `portionNote`, nullable.
- `description`, nullable.
- `imagePath`, nullable local image path.
- `ingredients`: JSON-encoded string list, nullable.

Computed behavior:

- `isManual` is true when provider is null or `manual`.

Native equivalent:

- Core Data, SwiftData, or SQLite can hold the same fields.
- Keep `uuid` stable for imports.
- Store photos as files, not in the database.

### WeightEntry

Stored fields:

- `id`: local Isar auto-increment id.
- `uuid`: stable id.
- `date`: `yyyy-MM-dd`.
- `timestamp`: milliseconds since epoch.
- `weight`: always stored internally in kg.

Display behavior:

- If settings unit is `lbs`, display kg multiplied by `2.20462262`.
- When entering lbs, convert to kg by multiplying by `0.45359237`.

### AppSettings

Fields:

- `provider`: `server`, `anthropic`, or `openai`.
- `theme`: `auto`, `light`, or `dark`.
- `weightUnit`: `kg` or `lbs`.
- Daily goals: calories, protein, carbs, fat, fiber.
- `goalWeight`: stored in kg.
- API/server fields: `anthropicKey`, `openaiKey`, `serverToken`, `serverUrl`.

Defaults:

- Provider: `server`.
- Theme: `auto`.
- Weight unit: `kg`.
- Daily display fallbacks on Today/History when unset:
  - Calories 1800.
  - Protein 150g.
  - Carbs 180g.
  - Fat 60g.

## Shared UI Components

### PwaTopBar

Top safe-area header. Can show:

- An eyebrow label, used on Today for date.
- A title, used on Weight, Add Meal, Settings.
- Optional leading button.
- Optional trailing widget.
- Optional settings button.
- Optional bottom border.

Settings button action:

- Pushes/presents Settings.

### PwaButton

Custom text button:

- Filled mode: background equals action color, foreground dark background.
- Outline mode: transparent background, colored text and border.
- Disabled state: muted background and surface foreground.
- Height controls corner radius and text size.

### CalorieRing

Circular progress:

- 144x144.
- Track color is card.
- Fill is accent unless consumed exceeds target, then danger.
- Center text: consumed calories, then `/ target kcal`.
- Progress is clamped 0...1.

### MacroProgressBar

Displays a macro label, value in grams, and a thin progress bar.

- Over-goal state turns label/value/fill danger.
- Used on Today for Protein, Carbs, Fat.

### MealCard

Collapsed state:

- Left thumbnail: meal photo if available, otherwise plate placeholder.
- Meal name, max 2 lines.
- Calories at top right.
- Time.
- Provider badge if provider exists.
- Tiny macro row: protein, carbs, fat.

Tap anywhere on card:

- Toggles expanded/collapsed state.

Expanded state:

- Macro detail block for protein, carbs, fat, fiber.
- Estimated ingredients if present.
- Portion note if present.
- Description note if present.
- Buttons:
  - `Log again`: opens Add Meal prefilled from this meal but with today's date.
  - `Modify / re-analyze`: opens Add Meal in edit mode.
  - `Delete`: asks for confirmation, then deletes meal and image file.

Provider label/color:

- `anthropic`: label `Claude`, accent color.
- `openai`: label `GPT-4o`, OpenAI color.
- `server` or unknown: label `Server`, OpenAI/server color.
- `manual` or `user`: label `User`, plum.

## Screen: Today

Source: `TodayScreen`.

Purpose:

- Shows the current day summary and today's meals.

Data:

- Watches `todayMealsProvider`, which filters all meals where `meal.date == today`.
- Watches settings for goals.

Layout:

- Top bar eyebrow: current weekday and date, uppercase, like `TUESDAY, 2 JUN`.
- Settings icon on the right.
- Calorie ring.
- Remaining/over text.
- Macro progress row for protein, carbs, fat.
- Meal count header.
- Empty state or meal list.

Calculations:

- Total calories/protein/carbs/fat are sums of today's meals.
- Remaining calories = goal calories minus total calories.
- If remaining is negative, show `X kcal over target` in danger color.
- Meals are sorted newest first by timestamp.

Buttons/actions:

- Settings icon: present Settings.
- Floating add button: present Add Meal blank.
- Meal card tap: expand/collapse.
- Meal card `Log again`: present Add Meal with `repeatMeal`, return path `/today`.
- Meal card `Modify / re-analyze`: present Add Meal with `editingMeal`, return path `/today`.
- Meal card `Delete`: confirmation alert `Delete meal? Remove "{mealName}" from today?`; delete on confirm.

Empty state:

- Plate icon.
- Text: `Tap + to log your first meal`.

## Screen: Add/Edit Meal

Source: `AddMealScreen`.

Modes:

- Blank add: no meal passed.
- Edit: `editingMeal` passed.
- Repeat/log again: `repeatMeal` passed.

State machine:

- `idle`: input stage, show Analyze button.
- `analyzing`: AI request in progress, disable actions, button says `Analyzing...`.
- `review`: nutrition fields visible, show Re-analyze and Log/Save.
- `optimizing`: optimization request in progress.

Initialization:

- Default date is today.
- Edit mode uses original meal date and original timestamp.
- Repeat mode uses today's date and current save timestamp.
- Edit/repeat prefill name, calories, protein, carbs, fat, fiber, description, image, and a `MealAnalysis` object.
- If original image path exists, load the file.

Top bar:

- Title: `Add Meal` or `Edit Meal`.
- Leading back arrow: returns to `returnPath`.
- Trailing provider pill: current selected provider label.

Photo picker:

- Tapping photo area opens bottom sheet.
- Bottom sheet options:
  - `Camera`: pick from camera.
  - `Photo library`: pick from gallery.
- Picked image options:
  - Quality 80, max width/height 1200.
  - Further compressed to JPEG quality 72, min 800x800, temporary file.
- After picking image:
  - Store temp image file.
  - Reset status to idle.
  - Clear previous analysis and optimization.

Description field:

- Multiline text box, 3 lines.
- Hint: `Describe the meal, portions, ingredients, or restaurant...`
- A photo is optional if description is provided.

Previous meals panel:

- Shown only in add mode, idle state, when previous meals exist.
- Shows up to 6 unique previous meals.
- Uniqueness key combines lowercase name and nutrition values.
- Each tile shows meal name, calories, P/C/F, add-circle icon.
- Tapping a previous meal:
  - Prefills fields.
  - Sets date to today.
  - Copies existing image if file exists.
  - Enters review state.

Analyze button:

- Visible in idle/analyzing state at bottom.
- Validation: if no image and no description, show error `Add a photo or description first.`
- Calls selected AI provider.
- On success:
  - Fills editable nutrition fields.
  - Stores `MealAnalysis`.
  - Enters review state.
- On failure:
  - Shows user-friendly error.
  - Returns to idle.

Analysis editor:

- Editable meal name.
- Editable calories.
- Editable protein, carbs, fat, fiber.
- Numeric fields allow digits and decimal points only.
- Calories are shown in a surface row.
- Macros are four equal tiles.
- Portion note appears if provided.

Optimization panel:

- Shown in review state for new meals only, not edit mode.
- Text: asks AI for lower-calorie version before logging.
- Button:
  - `Optimize` before result.
  - `Optimizing...` while loading.
  - `Try Again` after result.
- Calls `AiService.optimize`.
- Displays optimized meal name, calories, optional calorie savings, optional portion note.
- Important: the current app does not apply optimization values to the meal automatically; it only displays them.

Meal date editor:

- Shown in review state.
- Tapping opens date picker.
- Initial date is current meal date.
- First date: Jan 1, 2020.
- Last date: today plus 365 days.
- Saves selected date as `yyyy-MM-dd`.

Bottom actions in review state:

- `Re-analyze`: calls analyze again using current image/description.
- `Log Meal ✓`: saves a new meal.
- `Save Meal ✓`: saves existing meal in edit mode.

Save behavior:

- Validates meal name is not empty.
- Parses blank/invalid numeric fields as 0.
- If image exists, copies it into documents/meal_photos with a new UUID filename.
- Existing edit timestamp is preserved.
- New/repeated meal timestamp is now.
- Provider is set to current settings provider.
- Description is stored only if non-empty.
- Portion note, confidence, and ingredients are taken from current analysis.
- On success, route goes back to `returnPath`.

Potential native parity note:

- Editing a meal with an existing image copies the existing image into a new file again on save. For exact compatibility, mimic this. For cleanup, native version could preserve same path unless image changes.

## Screen: History

Source: `HistoryScreen`.

Purpose:

- Shows meals and weight entries grouped by date, with filters and data backup tools.

State:

- `_filter`: `all`, `meals`, or `weight`.

Top layout:

- Title `History`.
- More menu.
- Filter pills: All, Meals, Weight.

More menu actions:

- `Export backup`: creates JSON backup and opens share sheet.
- `Import backup`: opens file picker for `.json`, imports, shows snack bar.
- `Clear all meals`: confirmation alert, deletes all meals only.

Filter behavior:

- All: date list includes meal dates and weight dates.
- Meals: date list includes meal dates only.
- Weight: date list includes weight dates only.
- Dates sort descending by `yyyy-MM-dd` string.

Per-day group:

- Date title formatted `EEE, d MMM`, e.g. `Tue, 2 Jun`.
- If meals exist:
  - Show meal count.
  - Show total kcal.
  - Show P/C/F totals.
  - Show thin calorie progress bar against daily calorie goal or 1800 fallback.
  - Over-goal kcal text and bar use danger.
- If weight exists:
  - Show first weight entry for that date.
- Meals sorted newest first.

Buttons/actions:

- Filter pills: update `_filter`.
- More menu: run selected data action.
- Weight card `Delete`: confirmation alert, delete weight.
- Meal card actions:
  - `Log again`: opens Add Meal repeat mode, return path `/today`.
  - `Modify / re-analyze`: opens Add Meal edit mode, return path `/history`.
  - `Delete`: confirmation alert, delete meal.

Empty state:

- History icon.
- Text: `Meals will appear here after you log them.`
- Note: despite the text, this empty state means both meals and weights are empty.

## Screen: Weight

Source: `WeightScreen`.

Purpose:

- Log body weight, visualize trend, set goal weight.

State:

- `_inputOpen`: shows/hides today's log input.
- `_goalOpen`: shows/hides goal input.
- `_weightCtrl`, `_goalCtrl`: text fields.

Top bar:

- Title `Weight`.
- Settings icon on right.

Conversions:

- Stored weight is always kg.
- `_toKg(v)`: if unit lbs, `v * 0.45359237`; otherwise `v`.
- `_fromKg(kg)`: if unit lbs, `kg * 2.20462262`; otherwise `kg`.

Trend card:

- Header `TREND · {unit}`.
- If fewer than 2 entries: show `Log at least 2 entries to see your trend`.
- Otherwise show line chart for last 30 entries sorted ascending by timestamp.
- Curved mint line, dots, subtle fill.
- Left axis labels only.
- If goal weight exists, draw horizontal dashed accent goal line.

Today card:

- Shows first weight entry whose date is today.
- If none, shows em dash.
- `Log Weight` button toggles input open.
- When input opens, goal input closes.
- Button changes to `Cancel`.
- Input has numeric field and `Save ✓`.
- Submit from keyboard also saves.

Log weight behavior:

- Parse text as double.
- Ignore null or <= 0.
- Create `WeightEntry` with UUID, today's date, current timestamp, converted kg.
- Save, clear field, close input.

Goal weight card:

- Shows current goal or `Not set`.
- Button label:
  - `Set goal` if no goal.
  - `Edit` if goal exists.
  - `Cancel` if editor open.
- Opening goal editor closes daily input.
- If goal exists, prefill field with converted display value.
- Save button runs `_setGoal`.

Set goal behavior:

- Parse text as double.
- If valid, store converted kg in settings.
- If invalid/empty, clear goal by setting null.
- Clear field and close editor.

Goal delta:

- If today's weight and goal exist, show `({diff} {unit} to lose)` when current > goal.
- Otherwise `to gain`.

All entries:

- If weights exist, show `ALL ENTRIES`.
- Current provider order is whatever `weightsProvider` gives: date descending, timestamp descending.
- Each tile shows display weight, date/time, delete icon.
- Delete icon opens confirmation alert and deletes entry.

Empty state:

- Scale icon.
- Text: `Tap Log Weight to record your first entry`.

## Screen: Settings

Source: `SettingsScreen`.

Purpose:

- Configure AI provider, appearance, weight unit, daily targets, and data backup.

Top bar:

- Title `Settings`.
- Leading close icon:
  - If navigation can pop, pop.
  - Else go to `/today`.
- Trailing `Save` text button.

Important save behavior:

- Provider/theme/unit segmented controls save immediately when tapped.
- API keys/server fields/daily target text fields save only when `Save` is tapped.
- On save, show snack bar `Settings saved`.

AI Provider section:

- Segmented options:
  - Server
  - Anthropic
  - OpenAI
- Tapping one updates `settings.provider`.
- Conditional fields:
  - Server:
    - `Server token (optional)`, obscured.
    - `Server URL (leave blank for default)`.
  - Anthropic:
    - `Anthropic API key`, obscured.
  - OpenAI:
    - `OpenAI API key`, obscured.

Theme section:

- Segmented options:
  - Auto
  - Light
  - Dark
- Tapping one updates `settings.theme`.

Weight Unit section:

- Segmented options:
  - kg
  - lbs
- Tapping one updates `settings.weightUnit`.

Daily Targets section:

- Fields:
  - Calories (kcal)
  - Protein (g)
  - Carbs (g)
  - Fat (g)
  - Fiber (g)
- Numeric fields allow digits and decimal points.
- Invalid/empty values save as null.

Data section:

- `Export backup`: creates JSON backup and opens share sheet.
- `Import backup`: opens `.json` picker, imports meals and weights, shows snack bar.

Target field sync:

- The screen listens to settings changes.
- If target text fields still match previous settings, they are overwritten with new settings.
- This avoids clobbering active user edits when unrelated settings change.

## Data Import/Export Contract

Export JSON shape:

```json
{
  "exportedAt": "2026-06-02T12:00:00.000",
  "meals": [],
  "weights": []
}
```

Meal export item:

```json
{
  "id": "uuid",
  "date": "yyyy-MM-dd",
  "timestamp": 1717339200000,
  "mealName": "Meal name",
  "calories": 450,
  "protein": 32.5,
  "carbs": 28,
  "fat": 18.5,
  "fiber": 4.2,
  "provider": "server",
  "confidence": "medium",
  "portionNote": "note",
  "description": "user description",
  "ingredients": ["ingredient"]
}
```

Photos are excluded from export.

Weight export item:

```json
{
  "id": "uuid",
  "date": "yyyy-MM-dd",
  "timestamp": 1717339200000,
  "weight": 80.5
}
```

Import behavior:

- Meals are deduplicated by UUID against existing meals.
- Weights are not deduplicated.
- Missing ids become new UUIDs.
- Date falls back to timestamp-derived local date.
- Timestamp accepts number, numeric string, or ISO date string.
- Weight import supports optional `unit: "lbs"` and converts to kg.

Native compatibility recommendation:

- Preserve the JSON format exactly so existing backups import into the native app.

## AI Contract

Provider choices:

- `server`: hosted Netlify function.
- `anthropic`: direct Anthropic Messages API.
- `openai`: direct OpenAI Chat Completions API.

Server defaults:

- URL: `https://mnmealtracker.netlify.app/.netlify/functions/analyze-meal`
- Header: `X-Meal-Tracker-Token`
- Body fields:
  - `mode`: `analyze` or `optimize`
  - `desc`: description string
  - `img`: optional `{ "b64": "...", "type": "image/jpeg|image/png|image/webp" }`
  - `analysis`: required for optimize
- Response expected: `{ "text": "raw JSON string" }`

Analyze expected JSON:

```json
{
  "mealName": "specific dish name",
  "calories": 450,
  "protein": 32.5,
  "carbs": 28.0,
  "fat": 18.5,
  "fiber": 4.2,
  "ingredients": ["visible component with estimated quantity"],
  "confidence": "high|medium|low",
  "portionNote": "brief estimation note"
}
```

Optimize expected JSON:

```json
{
  "mealName": "optimized dish name",
  "calories": 350,
  "protein": 30.0,
  "carbs": 24.0,
  "fat": 12.0,
  "fiber": 5.0,
  "ingredients": ["optimized item with estimated quantity"],
  "confidence": "high|medium|low",
  "portionNote": "brief note explaining changes",
  "suggestions": [
    {
      "text": "replace item with replacement",
      "caloriesDelta": -120,
      "proteinDelta": 5.0,
      "carbsDelta": 1.0,
      "fatDelta": -12.0,
      "fiberDelta": 0.0
    }
  ],
  "calorieSavings": 100
}
```

AI response parsing behavior:

- Trim whitespace.
- If response is fenced in ``` code block, strip fence.
- Try direct JSON decode.
- If direct decode fails, extract substring from first `{` to last `}` and decode.
- If still invalid, show friendly error.

Error copy:

- Missing input: `Add a photo or description first.`
- Missing provider keys:
  - Anthropic: `Anthropic API key is not set.`
  - OpenAI: `OpenAI API key is not set.`
- Invalid nutrition data: `The AI response was not valid nutrition data. Try again, or add a more specific meal description.`
- Invalid optimization data: `The AI response was not valid optimization data. Try again in a moment.`

Direct provider models in current code:

- Anthropic model string: `claude-opus-4-7`.
- OpenAI model string: `gpt-4o`.

Native rebuild note:

- These model strings may need updating during implementation.
- Prefer preserving the hosted server route to avoid shipping owner API keys.

## Full Button And Tap Inventory

- Shell floating add button: open Add Meal blank.
- Bottom tab Home: navigate `/today`.
- Bottom tab History: navigate `/history`.
- Bottom tab Weight: navigate `/weight`.
- Top settings icon on Today/Weight: open Settings.
- Today meal card: expand/collapse.
- Meal card Log again: open Add Meal repeat.
- Meal card Modify/re-analyze: open Add Meal edit.
- Meal card Delete: confirm then delete meal.
- Add Meal back arrow: return to caller path.
- Add Meal photo area: open picker sheet.
- Picker Camera: take/select camera photo.
- Picker Photo library: select gallery photo.
- Add Meal previous meal tile: prefill from previous meal.
- Add Meal Analyze Meal: validate input, call AI analyze.
- Add Meal Re-analyze: call AI analyze again.
- Add Meal Optimize/Try Again: call AI optimize.
- Add Meal meal date card: open date picker.
- Add Meal Log Meal/Save Meal: validate and persist.
- History filter All/Meals/Weight: change filter.
- History menu Export backup: create JSON and share.
- History menu Import backup: pick JSON and import.
- History menu Clear all meals: confirm then delete all meals.
- History weight card Delete: confirm then delete weight.
- Weight Log Weight: toggle weight input.
- Weight daily Save: log weight.
- Weight daily keyboard submit: log weight.
- Weight Set goal/Edit: toggle goal editor.
- Weight goal Save: set or clear goal.
- Weight entry delete icon: confirm then delete weight.
- Settings close: dismiss or go Today.
- Settings Save: save text-field settings and targets.
- Settings provider segments: save provider immediately.
- Settings theme segments: save theme immediately.
- Settings weight unit segments: save unit immediately.
- Settings Export backup: create JSON and share.
- Settings Import backup: pick JSON and import.

## Native iOS Implementation Checklist

- Preserve route/screen hierarchy and modal behavior.
- Preserve data model fields and JSON backup format.
- Store all weights in kg.
- Preserve the default goals and today/date formatting.
- Implement image picking and JPEG compression/resizing.
- Implement file-based meal photos.
- Implement local database and settings persistence.
- Implement AI request/response parser exactly enough to handle fenced or prefixed JSON.
- Implement share-sheet export and document-picker import.
- Implement confirmation alerts for destructive actions.
- Keep screenshots beside this document and map each screenshot to:
  - Screen name.
  - State: empty, populated, expanded, editing, error, loading.
  - Visible button actions from the inventory above.

## Xcode Size Spec

Use these values as iOS points. Flutter logical pixels map closely to iOS points for this kind of layout.

### Global Layout

- Page horizontal margin: 16.
- Standard vertical section gap: 12 or 14.
- Large section gap: 24.
- Bottom scroll padding above tab bar: 80 to 100.
- Large bottom empty-state clearance on Today: 120.
- Standard card corner radius: 14 or 16.
- Standard inner surface radius: 10.
- Small note/pill radius: 3, 8, or 20 depending on shape.
- Standard border width: 1.
- Emphasis border width: 1.5.
- Dotted/left note border width: 2.

### Typography

- Top-bar title: 24, Playfair Display.
- Top-bar eyebrow/date: 10, uppercase, letter spacing 1.8.
- Section headers: 10 to 12, uppercase/letter-spaced.
- Card title/meal name: 14 to 18, Playfair Display where prominent.
- Body text: 13 to 14.
- Muted helper text: 10 to 12.
- Tiny badges: 9 to 10.
- Macro/numeric small: 11 to 16, DM Mono.
- Large calories/weight numbers: 22, 28, or 36, DM Mono/Playfair depending on context.

### Top Bar

- Safe-area top bar padding: left 16, top 14, right 16, bottom 0.
- Optional leading button minimum hit size: 44 x 44.
- Leading-to-title gap: 12.
- Title font: 24.
- Eyebrow font: 10.
- Settings/close/back icons use standard `IconButton`, minimum 44 x 44.
- Border shown on Settings/Add Meal top bar: 1 bottom border.

### Bottom Tab Bar

- Tab bar height: 64 plus safe-area bottom.
- Tab cell padding: top 10, bottom 8.
- Tab icon/text symbol font: 17.
- Tab label font: 10, uppercase, letter spacing 1.2.
- Gap symbol to label: 4.
- Gap label to active indicator: 5.
- Active indicator: 18 wide x 2 high, radius 2.
- Top border: 1.
- Shadow: blur 20, y offset -8, black alpha 0.18.

### Floating Add Button

- Material circular FAB.
- Shape: circle.
- Icon: plus, size 30.
- Elevation: 8.
- Uses default Flutter FAB diameter, effectively about 56 x 56.

### PwaButton

- Default height: 46.
- Small height: 34, 38, or 40.
- Large bottom action height: 54.
- Corner radius: 14 when height >= 50, otherwise 10.
- Horizontal padding: 14 normally, 8 when height < 40.
- Font size: 13 normally, 11 when height < 40.
- Font weight: 700.

### Today Screen

- Top gap after top bar: 16.
- Calorie ring: 144 x 144.
- Ring stroke width: 9.
- Ring radius: 56.
- Ring consumed number font: 28.
- Ring target label font: 10.
- Gap inside ring number/target: 4.
- Gap ring to remaining text: 12.
- Remaining text font: 12, DM Mono.
- Macro row padding: left 16, top 18, right 16, bottom 24.
- Gap between macro progress bars: 14.
- Meal-count header padding: left 16, top 0, right 16, bottom 10.
- Meal-count font: 12, Playfair Display, letter spacing 1.2.
- P/C/F summary font: 10, DM Mono.
- Empty icon font: 36.
- Empty icon/text gap: 10.
- Empty text font: 14.
- Meal list padding: left 16, top 0, right 16, bottom 100.

### Macro Progress Bar

- Label font: 10, uppercase, letter spacing 1.
- Value font: 11, DM Mono.
- Label row to bar gap: 5.
- Progress bar height: 3.
- Progress bar radius: 2.

### Meal Card

- Card bottom margin: 10.
- Card corner radius: 14.
- Thumbnail: 80 x 80.
- Placeholder icon font: 26.
- Main content padding: left 12, top 10, right 12, bottom 10.
- Meal name font: 14, line height 1.3, max 2 lines.
- Calories font: 14, DM Mono, weight 700.
- Name-to-calories gap: 8.
- Name/time vertical gap: 4.
- Time font: 10.
- Provider badge left gap: 6.
- Provider badge padding: horizontal 6, vertical 2.
- Provider badge radius: 3.
- Provider badge font: 9, letter spacing 0.5.
- Time/badge-to-macros gap: 6.
- Tiny macro font: 11, DM Mono.
- Tiny macro gap: 8.
- Expanded area padding: 12.
- Expanded macro block padding: horizontal 8, vertical 10.
- Expanded macro block radius: 10.
- Expanded macro value font: 15.
- Expanded macro label font: 9, letter spacing 1.
- Ingredient header gap: 12.
- Ingredient header font: 9, letter spacing 1.2.
- Header-to-ingredient gap: 5.
- Ingredient text font: 12.
- Ingredient row bottom padding: 2.
- Portion note top gap: 8.
- Portion note padding: horizontal 10, vertical 8.
- Portion note radius: 8.
- Portion note font: 11 italic.
- Description note top gap: 8.
- Description note font: 11.
- Expanded button row top gap: 12.
- Expanded button height: 38.
- Expanded button horizontal gap: 10.
- Delete button fixed width: 78.

### Add/Edit Meal Screen

- Scroll content padding: left 16, top 14, right 16, bottom 16.
- Photo picker height without image: 160.
- Photo picker height with image: 220.
- Displayed image height: 240.
- Photo picker radius: 16.
- Photo picker border width: 2 without image, 1 with image.
- Empty camera icon size: 42.
- Empty photo title font: 15.
- Empty photo helper font: 12.
- Icon-to-title gap: 8.
- Title-to-helper gap: 3.
- Description top gap: 12.
- Description field max lines: 3.
- Description/input corner radius: 10.
- Error panel top gap: 12.
- Error panel padding: 12.
- Error panel radius: 10.
- Error font: 13.
- Review panel top gaps: 12.
- Bottom spacer inside scroll: 40.
- Bottom action bar padding: left 16, top 10, right 16, bottom safe area + 10.
- Bottom action row gap: 10.
- Bottom action buttons: 54 high.
- Re-analyze button width weight: 1.
- Log/Save button width weight: 2.

### Add Meal Analysis Editor

- Analysis card padding: 14.
- Analysis card radius: 16.
- Meal name editor font: 18, Playfair Display.
- Name-to-calories gap: 12.
- Calories row padding: horizontal 12, vertical 10.
- Calories row radius: 10.
- Calories label font: 12.
- Calories number field width: 72.
- Calories number font: 22, DM Mono.
- Calories unit font: 12.
- Calories number-to-unit gap: 8.
- Calories-to-macros gap: 12.
- Macro tile horizontal gap: 8.
- Macro tile padding: horizontal 4, vertical 8.
- Macro tile radius: 10.
- Macro number font: 16, DM Mono.
- Macro number-to-label gap: 5.
- Macro label font: 9, uppercase, letter spacing 1.
- Number field vertical content padding: 2.
- Portion note top gap: 12.
- Portion note padding: horizontal 10, vertical 8.
- Portion note radius: 8.
- Portion note left border: 2.
- Portion note font: 11 italic.

### Previous Meals Panel

- Panel padding: 12.
- Panel radius: 16.
- Header font: 10, letter spacing 1.
- Header-to-list gap: 8.
- Tile vertical padding: 8.
- Tile radius: 10.
- Meal name font: 14, weight 600.
- Meal name-to-macros gap: 3.
- Macro summary font: 11, DM Mono.
- Trailing icon gap: 10.
- Add-circle icon size: 22.

### Optimization Panel

- Panel padding: 14.
- Panel radius: 14.
- Header font: 10, letter spacing 1.
- Header-to-copy gap: 4.
- Copy font: 13, line height 1.35.
- Button left gap: 10.
- Optimize button height: 40.
- Result top gap: 12.
- Result padding: 12.
- Result radius: 12.
- Result meal name font: 17, Playfair Display.
- Result calories font: 20, DM Mono, weight 700.
- Savings top gap: 4.
- Savings font: 11, DM Mono.
- Portion note top gap: 10.
- Portion note font: 11 italic, line height 1.35.

### Meal Date Editor

- Card padding: 14.
- Card radius: 14.
- Header font: 10, letter spacing 1.
- Header-to-field gap: 8.
- Field padding: horizontal 10, vertical 13.
- Field radius: 10.
- Date font: 16.

### Provider Pill

- Padding: horizontal 10, vertical 5.
- Radius: 20.
- Font: 10, uppercase, weight 700.

### History Screen

- Header padding: left 16, top 14, right 16, bottom 10.
- Title font: 24, Playfair Display.
- Title-to-filter gap: 10.
- Filter pill height: 32.
- Filter gap: 8.
- Filter radius: 20.
- Filter border width: 1.
- Filter font: 11, uppercase, weight 700, letter spacing 0.8.
- Empty icon size: 48.
- Empty icon/text gap: 12.
- List padding: left 16, top 0, right 16, bottom 100.
- Day header padding: top 4, bottom 8.
- Date title font: 17, Playfair Display.
- Meal count font: 10, letter spacing 1.
- Day calories font: 16, DM Mono, weight 700.
- Day P/C/F font: 10, DM Mono.
- Day progress bar height: 2.
- Day progress radius: 1.
- Progress-to-content gap: 8.
- Day group bottom gap: 8.

### History Weight Card

- Card bottom margin: 10.
- Card padding: horizontal 14, vertical 12.
- Card radius: 14.
- Icon box: 44 x 44.
- Icon box radius: 10.
- Scale icon font: 20.
- Icon-to-content gap: 10.
- Weight value font: 22, DM Mono, weight 700.
- Unit font: 12.
- Value-to-time gap: 2.
- Time font: 10.
- Delete button height: 34.
- Delete button radius: 8.
- Delete button font: 11.

### Weight Screen

- Scroll content padding: 16 all sides.
- Card vertical gap: 14.
- Trend card padding: left 12, top 14, right 12, bottom 8.
- Trend card radius: 16.
- Trend header font: 10, letter spacing 1.
- Trend header-to-chart gap: 8.
- Chart container height: 120.
- Empty chart helper font: 11.
- Today card padding: 16.
- Today card radius: 16.
- Today header font: 10, letter spacing 1.
- Header-to-weight gap: 10.
- Today weight number font: 36, DM Mono, weight 700.
- Today weight unit font: 14.
- Log Weight button width: 126.
- Log Weight button height: 42.
- Goal text top gap: 4.
- Goal/delta font: 11.
- Input divider top gap: 12.
- Input content top padding after divider: 12.
- Input row gap: 8.
- Save button width: 86.
- Save button height: 46.
- Goal card padding: 14.
- Goal card radius: 16.
- Goal header font: 10, letter spacing 1.
- Goal header-to-value gap: 4.
- Goal value font: 15.
- Goal edit button width: 94.
- Goal edit button height: 34.
- Goal editor top gap: 10.
- Goal editor content top padding after divider: 10.
- All entries header top gap: 14.
- All entries header font: 10, letter spacing 1.
- Header-to-entries gap: 8.
- Empty weight state vertical padding: 40.
- Empty scale font: 32.
- Empty icon/text gap: 10.
- Empty helper font: 14.
- Bottom scroll spacer: 80.

### Weight Entry Tile

- Tile bottom margin: 8.
- Tile padding: horizontal 14, vertical 12.
- Tile radius: 12.
- Weight font: 16, weight 600.
- Date font: 12.
- Date-to-delete gap: 12.
- Delete icon size: 18.

### Weight Input

- Container padding: horizontal 12.
- Container radius: 10.
- Text field vertical content padding: 10.
- Number font: 22, DM Mono, weight 700.
- Unit font: 13.

### Weight Chart

- Chart height: 120 from parent.
- Left axis reserved width: 36.
- Axis label font: 10.
- Grid line stroke: 1.
- Goal line stroke: 1.5.
- Goal line dash pattern: 6 on, 4 off.
- Data line stroke: 2.5.
- Dot radius: 3.
- Dot stroke: 0.
- Area fill alpha: 0.08.
- Y padding: 15 percent of range, clamped from 0.5 to 5.0.

### Settings Screen

- List padding: 16 all sides.
- Section gap: 24.
- Final bottom spacer: 40.
- Section header bottom padding: 10.
- Section header font: 12, weight 600, letter spacing 0.6.
- Provider fields gap: 8.
- Provider segmented row bottom gap before fields: 12.
- Target field row gap: 8.
- Segmented item horizontal gap: 6.
- Segmented item vertical padding: 10.
- Segmented item radius: 10.
- Segmented selected border width: 1.5.
- Segmented label font: 14.
- Data action tile padding: horizontal 14, vertical 14.
- Data action tile radius: 12.
- Data action icon size: 20.
- Icon-to-label gap: 12.

### Theme Defaults For Text Inputs

- Filled input corner radius: 10.
- Border width: 1.
- Focused border color: accent.
- Elevated button default corner radius: 10.
