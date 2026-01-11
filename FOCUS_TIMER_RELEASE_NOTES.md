# Focus Timer with Live Activities - Testing Release

## 🎯 Overview
This testing release introduces the enhanced Focus Timer (formerly Pomodoro Timer) with iOS Live Activities support, bringing a more integrated and accessible focus session experience to Korah.

## ✨ New Features

### Focus Timer Enhancements
- **Renamed & Rebranded**: Pomodoro Timer is now "Focus Timer" throughout the app
- **Dedicated Tab**: Focus Timer now has its own navigation tab (positioned after Scan)
- **Compact Dropdown**: Quick-start timer directly from the Tasks page with a clean dropdown interface
  - Select 5, 15, or 25-minute sessions
  - Pause/Resume and Reset controls when active
  - No need to navigate away from your task list
- **Improved Task Selection**: Beautiful new UI for selecting which tasks to focus on
  - Visual feedback with checkboxes and highlighting
  - Shows selected count and quick "Clear All" option
  - Better empty states and navigation

### 📱 Live Activities Support (iOS 16.1+)
The Focus Timer now integrates with iOS Live Activities, providing persistent, at-a-glance timer visibility:

#### Lock Screen
- **Large, beautiful display** of your focus session
- **Time remaining** with progress circle visualization
- **Active status badge** (Active/Paused)
- **Task list** showing what you're focusing on (up to 3 tasks visible)
- **Percentage progress** indicator

#### Dynamic Island (iPhone 14 Pro+, 15 Pro+)
- **Compact view**: Timer icon and countdown in always-visible space
- **Expanded view** (long-press):
  - Full timer display with progress bar
  - Current tasks list
  - Interactive Pause/Resume and End buttons
  - Status indicators
- **Minimal view**: Simple timer icon when multiple activities are running

#### Interactive Controls
- **Pause/Resume**: Control your focus session directly from the Live Activity
- **End Session**: Stop the timer without opening the app
- **Real-time updates**: Timer counts down even when app is closed

## 🔧 Technical Requirements

### For Live Activities
- **iOS 16.1 or later** required
- **Physical device** required for testing (Live Activities don't work in simulator)
- **iPhone 14 Pro/Pro Max or 15 Pro/Pro Max** recommended for Dynamic Island experience
- Regular iPhones with iOS 16.1+ will show Lock Screen Live Activities

### Setup in Xcode
1. **Add Widget Extension Target**:
   - File → New → Target → Widget Extension
   - Name: "FocusTimerWidget"
   - Uncheck "Include Configuration Intent"

2. **Configure Info.plist** (in Widget Extension):
   ```xml
   <key>NSSupportsLiveActivities</key>
   <true/>
   ```

3. **Add to both app and widget extension targets**:
   - `FocusTimerAttributes.swift` (Models folder)
   - Enable ActivityKit framework

4. **Build and run** on a physical device

## 🧪 Testing Checklist

### Core Timer Functionality
- [ ] Start timer from Tasks tab dropdown
- [ ] Start timer from Focus tab
- [ ] Pause and resume timer
- [ ] Reset timer
- [ ] Timer completes naturally and shows completion alert
- [ ] Select tasks before starting session
- [ ] Task selection UI shows properly

### Live Activities (Physical Device Only)
- [ ] Live Activity appears when timer starts
- [ ] Timer counts down on Lock Screen
- [ ] Dynamic Island shows compact timer (Pro models)
- [ ] Long-press Dynamic Island shows expanded controls
- [ ] Tap Pause button in Live Activity → timer pauses in app
- [ ] Tap Resume button in Live Activity → timer resumes
- [ ] Tap End button in Live Activity → timer resets
- [ ] Timer completion dismisses Live Activity
- [ ] Manual reset dismisses Live Activity
- [ ] Selected tasks appear correctly in Live Activity
- [ ] Live Activity persists when app is closed/background

### Edge Cases
- [ ] Start timer, close app, reopen → timer still running
- [ ] Start timer, force quit app → Live Activity remains functional
- [ ] Multiple timers (shouldn't happen, but test behavior)
- [ ] No tasks selected → Live Activity shows without task list
- [ ] Long task names display correctly

## 🚀 Coming in Beta Release
These features are planned for the full beta version after this testing release:

### Screen Time Integration
- **App Blocking**: Block distracting apps during focus sessions
- **Usage Analytics**: See which apps interrupt your focus most
- **Smart Recommendations**: Get suggestions for apps to block based on your habits
- **Focus Score**: Track your focus quality over time

### Additional Enhancements
- **Focus Statistics**: View session history and analytics
- **Custom Timer Presets**: Save your favorite timer durations
- **Break Reminders**: Automated break suggestions between sessions
- **Streak Tracking**: Build focus session streaks

## 📝 Known Limitations (Testing Release)

1. **Live Activities**:
   - Only work on physical devices (iOS 16.1+)
   - Button interactions use NotificationCenter (will be improved with App Intents)
   - Maximum of ~8 hours runtime (iOS system limitation)

2. **Background Updates**:
   - Timer continues in background with iOS limitations
   - Live Activity updates every second while running
   - System may throttle updates if battery is low

3. **Widget Extension**:
   - Must be manually added to Xcode project
   - Requires proper code signing and provisioning
   - Info.plist configuration needed

## 🐛 Bug Reports
When reporting issues, please include:
- iOS version
- Device model
- Steps to reproduce
- Whether Live Activity was active
- Screenshots/screen recordings if possible

## 📞 Support
For questions or issues during testing:
- Check that iOS version is 16.1+ for Live Activities
- Verify testing on physical device (not simulator)
- Ensure Widget Extension is properly configured
- Check console logs for ActivityKit errors

---

**Version**: Testing Release 1.0  
**Date**: January 2026  
**Minimum iOS**: 16.1 (for Live Activities), 15.0 (for basic timer)  
**Target Devices**: iPhone 8 and later
