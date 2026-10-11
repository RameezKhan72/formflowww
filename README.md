# FormFlow

AI-based real-time exercise form correction and fitness coaching app for Android, built in Flutter from **PRD v2.0 (Flutter Edition)**.

## What is in this build

| Area | Status |
|---|---|
| 5-tab app: Routines, Exercises, Workout (home), Nutrition, Progress | Done |
| Onboarding: splash, 3 slides, 18+ gate, readiness questions, privacy note | Done |
| Sign up / log in with validation (shake + haptic), guest mode | Done (local; Firebase hook-up needs your `google-services.json`) |
| Profile setup + "Checking your phone" benchmark → Lite / Standard / High | Done |
| 20 exercises, data-driven from `assets/data/exercises.json` | Done |
| Realistic anatomical muscle map (front/back, rendered from the Z-Anatomy 3D atlas), tappable, red recovery tint | Done |
| Mini muscle chips cropped from the realistic map | Done |
| Realistic 3D exercise animations for all 20 exercises (anatomical figure, worked muscles red, props), plus a 2D demonstrator for Lite phones | Done |
| Pose detection: Google ML Kit (33 BlazePose landmarks, **base** model, bundled, offline) behind a `PoseEstimator` interface | Done |
| Engine: confidence gating, One Euro smoothing, 4-phase rep state machine with hysteresis and 0.6 s minimum, rule persistence (4 frames), view awareness, left/right naming, severity-weighted scores, attempts vs clean reps, timed holds | Done |
| Feedback: priority, 3 s / 4 s cooldowns, correction loop ("Good, that's right"), repeat-once-then-haptic, rep tone and spoken counts | Done |
| Voice: recorded-clip → system TTS → on-screen + haptic fallback chain | TTS live; clip slots ready (`assets/audio/en/<cue>.ogg`) |
| Guided workout: camera setup checks, tracking HUD, depth meter, rest 45/60 s with +15 / Skip, skip exercise, summary with "Fix next time", auto-save and resume | Done |
| Demo mode: synthetic landmarks from the demonstrator drive the real engine (works without a camera) | Done |
| Routines: My Routines / Explore, filters, presets, create / edit / duplicate / delete, rule-based Routine Creator | Done |
| Nutrition: Mifflin-St Jeor, activity factor, % deficit/surplus, macros, floors, low-BMI guard, water, meal plan, vitamins by sex/age, timeline, weekly schedule | Done |
| Progress: profile card, calendar, streak, target ring, form chart, finished workouts, Recover figure, Fresh Muscle Workout, share as image | Done |
| Rule-based Coach insights (on-device) | Done |
| Accuracy Test Lab: Right/Wrong labels, confusion matrix, precision/recall/F1, CSV export | Done |
| Body Profile scan (5 poses, ratios, symmetry, quality score) | Done |
| Settings: voice, volume, rep speech, haptics, camera, performance mode, reduce motion, units, export, delete account | Done |

### Choices that differ from the PRD defaults (to keep the app light and buildable)
- **Storage:** a JSON store on `shared_preferences` instead of Drift (no code generation). Full history with per-rep records is kept.
- **Navigation:** Flutter `Navigator` + `IndexedStack` instead of go_router.
- **Charts:** a small custom painter instead of fl_chart.
- **Cloud:** Firebase is not wired in because it needs your Firebase project files. The auth screen validates input and never stores passwords.

## Run it

```bash
flutter pub get
# first time only, if the android/ folder is missing:
flutter create --project-name formflow --org com.formflow --platforms android .
python3 tool/patch_android.py
flutter run
```

## Tests

```bash
flutter test                     # unit + widget + replay tests
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart   # screenshot tour on a device/emulator
```

Unit tests cover angle maths, smoothing, the rep state machine, rules and persistence, feedback cooldowns and the correction loop (TC-21, TC-22), replay of all 20 exercise demonstrations through the engine, timed holds, auto-pause (TC-32), fuzzing (TC-20), nutrition (TC-29), vitamins, recovery, coach, lab metrics, routines, the guided workout and resume (TC-24), body scan, validators and the local store.

## Editing exercises
Edit `tool/build_exercises.py` and run `python3 tool/build_exercises.py` to regenerate `assets/data/exercises.json`. No Dart changes are needed to add an exercise.

## Licences
See [ASSETS.md](ASSETS.md).
