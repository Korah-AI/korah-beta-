# How to Add Files to Widget Extension Target in Xcode

## Step 2: Adding FocusTimerAttributes.swift to BOTH Targets

### Visual Step-by-Step Instructions:

#### 1. Locate the File
- In Xcode's **left sidebar** (Project Navigator)
- Navigate to: `Korah (Beta)` → `Models` folder
- Find `FocusTimerAttributes.swift`

#### 2. Select the File
- **Single click** on `FocusTimerAttributes.swift` to select it

#### 3. Open File Inspector
- Look at the **right sidebar** in Xcode
- If you don't see the right sidebar:
  - Click the **rightmost button** in the top-right toolbar (looks like a document icon)
  - Or press **⌘ + Option + 0** (Command + Option + Zero)

#### 4. Find Target Membership Section
In the right sidebar (File Inspector), scroll down to find **"Target Membership"**

You'll see checkboxes like:
```
Target Membership
☑️ Korah (Beta)
☐ FocusTimerWidget
```

#### 5. Check BOTH Boxes
- Make sure **BOTH** checkboxes are checked:
```
Target Membership
☑️ Korah (Beta)          ← Should already be checked
☑️ FocusTimerWidget      ← CHECK THIS ONE
```

#### 6. Verify
- Both targets should now show checkmarks
- The file is now included in both the app and the widget extension

---

## Alternative Method: Using Target Settings

If you can't find the File Inspector:

### Method 2:

1. Click on the **project name** at the very top of the left sidebar (blue icon)
2. In the main area, select the **FocusTimerWidget** target from the list
3. Go to the **Build Phases** tab
4. Expand **"Compile Sources"**
5. Click the **"+"** button
6. Find and select `FocusTimerAttributes.swift`
7. Click **Add**

---

## Step 3: Moving Widget-Only Files

The widget files (`FocusTimerWidgetBundle.swift` and `FocusTimerLiveActivity.swift`) are already in the `FocusTimerWidget` folder, so they should automatically be part of the widget target only.

### To Verify:

1. Click on `FocusTimerWidgetBundle.swift`
2. Check right sidebar → Target Membership
3. Should show:
```
Target Membership
☐ Korah (Beta)           ← Should be UNCHECKED
☑️ FocusTimerWidget      ← Should be CHECKED
```

4. Repeat for `FocusTimerLiveActivity.swift`

---

## Common Issues:

### "I don't see FocusTimerWidget in Target Membership"
**Solution:** You haven't created the widget extension target yet.
- Go back to Step 1: File → New → Target → Widget Extension

### "FocusTimerAttributes.swift is not in the Models folder"
**Solution:** The file exists in the project root. 
1. In Finder, move it to `Korah (Beta)/Models/` folder
2. In Xcode, right-click the `Models` folder → Add Files to "Korah (Beta)"
3. Select `FocusTimerAttributes.swift`
4. Make sure "Copy items if needed" is checked
5. Under "Add to targets", check **both** targets

### "I don't see the right sidebar"
**Solution:**
- Click the rightmost button in top-right toolbar (📄 icon)
- Or use menu: View → Inspectors → Show File Inspector
- Or press **⌘ + Option + 0**

### "Target Membership section is greyed out"
**Solution:** Make sure you've selected a **file**, not a folder.

---

## Quick Reference: Keyboard Shortcuts

- Show/Hide Project Navigator (left): **⌘ + 1**
- Show/Hide File Inspector (right): **⌘ + Option + 0**
- Show Project Settings: Click project name at top of navigator

---

## What Each File Should Have:

| File | Korah (Beta) | FocusTimerWidget |
|------|--------------|------------------|
| `FocusTimerAttributes.swift` | ✅ | ✅ |
| `FocusTimerWidgetBundle.swift` | ❌ | ✅ |
| `FocusTimerLiveActivity.swift` | ❌ | ✅ |
| `Info.plist` (widget) | ❌ | ✅ |

---

## Still Stuck?

### Take a Screenshot:
1. Show me your Xcode window with:
   - Left sidebar showing file structure
   - Right sidebar showing File Inspector
   - `FocusTimerAttributes.swift` selected

### Or Try This Quick Test:
1. Select `FocusTimerAttributes.swift`
2. Press **⌘ + Option + 0** to open File Inspector
3. Look for "Target Membership" section
4. Tell me what you see there

---

## Visual Layout Reference:

```
┌────────────────────────────────────────────────────────────┐
│  Xcode Window                                              │
├──────────────┬─────────────────────────┬──────────────────┤
│              │                         │  File Inspector  │
│  Project     │   Main Editor Area      │  ┌────────────┐  │
│  Navigator   │                         │  │ Target     │  │
│  ┌────────┐  │   (Code/Settings)       │  │ Membership │  │
│  │ Korah  │  │                         │  │            │  │
│  │ ├Models│  │                         │  │☑️ Korah    │  │
│  │ │└Focus│  │                         │  │☐ Widget   │  │
│  │ └Views │  │                         │  └────────────┘  │
│  │        │  │                         │                  │
│  └────────┘  │                         │                  │
│              │                         │                  │
└──────────────┴─────────────────────────┴──────────────────┘
         ⌘+1           (Main Area)              ⌘+Opt+0
```

The key is finding the **File Inspector** (right sidebar) and the **Target Membership** section within it!
