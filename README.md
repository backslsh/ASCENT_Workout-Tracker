# Ascend — gamified lifting tracker (iOS, sideload-ready)

A native SwiftUI iPhone app: log gym **and** home workouts, run workout and rest timers, and earn ranks
(Iron → Bronze → Silver → Gold → Platinum → Diamond → Master → Grandmaster → Legend, each with
divisions III/II/I) for every exercise and muscle group.

No account, no server, and no paid Apple services. Everything stays on your phone.

## Features
- **Profile**: name, age, bodyweight, overall rank, streak, weekly goal ring, a **Showcase** of up to 5 lift ranks, and **Quick Start** from pinned routines and recent workouts.
- **Workout**: routines with sets, reps and weight; pin, duplicate, edit. A library of 80+ exercises (barbell, dumbbell, machine, cable, kettlebell, bodyweight, core such as Russian twists, planks and V-ups) plus custom exercises. Each exercise shows a muscle-group icon.
- **Live workout**: elapsed timer, auto-start rest timer with a progress ring (−15/+15/skip), a lock-screen alert when rest ends, the "previous" column, warm-up sets, live PR detection and haptics. You can minimize it to a floating glass bar.
- **Ranks**: muscle groups sorted highest to lowest. Tap a group to see every exercise's rank, progress bar and what you need for the next division. Tap an exercise to see its rank ladder, progress chart and history.
- **History**: an 8-week chart (workouts or volume), all sessions by month, session detail, repeat a workout, and save a workout as a routine.
- **Finish summary**: rank-ups, PRs and confetti.
- **Settings**: lb/kg, default rest, weekly goal, male/female rank standards, and JSON backup export/import.
- Dark mode, a **Liquid Glass** tab bar and controls (real iOS 26 glass, with a frosted-material fallback on iOS 17–18), and spring animations.

## How ranks are scored
- Weighted lifts: estimated 1RM (Epley) ÷ bodyweight.
- Bodyweight moves: reps, boosted by any added weight.
- Holds: seconds.

Each score is compared with an "elite" standard per exercise. Warm-up sets don't count. A muscle group's
rank is its best lift's rank. Overall rank is the average across the muscle groups you've trained.

---

## Building the .ipa (no Mac needed)
You're on Windows and Xcode only runs on macOS, so a free **GitHub Actions** macOS machine does the build.

1. Create a free GitHub account, then a **new repository** (public gives unlimited free build minutes;
   private still gets enough for dozens of builds a month).
2. Upload this whole folder to it. The easiest way is **GitHub Desktop** → *Add existing repository* →
   choose `G:\New App` → *Publish*. Make sure the hidden `.github` folder is included.
3. On GitHub, open the **Actions** tab → *Build IPA*. It runs on every push, or you can click **Run workflow**. It takes about 5–8 minutes.
4. When it turns green, open the run → **Artifacts** → download `Ascend-ipa` → unzip it → `Ascend.ipa`.

## Installing with Sideloadly
1. Install **Sideloadly** and **iTunes (the Apple website version, not the Microsoft Store one)** on your PC.
2. Plug in your iPhone, then drag `Ascend.ipa` into Sideloadly.
3. Enter your normal (free) Apple ID and click **Start**.
4. On the iPhone:
   - Go to *Settings → General → VPN & Device Management* and trust your Apple ID.
   - On iOS 16+, also go to *Settings → Privacy & Security → Developer Mode* → On (this needs a restart).

**Free Apple ID limits:** the app must be re-signed every **7 days** (Sideloadly can auto-refresh). You
can have at most 3 sideloaded apps at once. Re-installing over the top **keeps your data**, but deleting the app wipes it, so use
*Settings → Export Backup* now and then.

## Project layout
```
project.yml                 XcodeGen spec (the CI generates the .xcodeproj from this)
.github/workflows/build.yml GitHub Actions: build unsigned .ipa
Ascend/App                  App entry, root view, glass tab bar
Ascend/Models               Data models, exercise library, rank engine, store/persistence
Ascend/UI                   Theme, liquid-glass modifier, reusable components
Ascend/Views                Profile, Workout, Active workout, Ranks, History, Settings, Onboarding
```
