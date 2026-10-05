# B4JAppium Example

A working B4J project that drives an Android (or iOS) app through [Appium](https://appium.io/) and produces a pass/fail HTML report — without writing any Java/Selenium code by hand. Test flows are authored as flat **JSON "recipes"** (tap this, wait for that, type here, screenshot, swipe...), and a single generic B4J module (`RecipeRunner.bas`) reads and executes any recipe for any app.

It uses the [B4XAppium](https://github.com/walterf25/B4XAppiumLibrary) library (a B4X wrapper around the Appium Java client + Selenium's W3C Actions API) for the actual device/driver communication.

## What this project actually does

1. **`B4XMainPage.bas`** runs on startup. It figures out which app-under-test to run (see [Choosing the app under test](#choosing-the-app-under-test)), loads that app's config JSON via `AppConfig.bas`, and uses it to start an Appium session (`B4XAppium.Initialize`) and an HTML report (`TestReport.Initialize`).
2. When you click the button on the main form, it loops over the recipe filenames listed in that app's config and, for each one, calls `RecipeRunner.RunRecipeFromJson(jsonText)`.
3. **`RecipeRunner.bas`** parses the recipe JSON and walks its `steps` array **in order**, dispatching each step's `"action"` to a small handler (tap, type, wait, assert, screenshot, swipe, scroll, back, sleep...). Every handler ultimately calls into `B4XAppium` (e.g. `driver.tryFindElementByText(...)`, `el.Click`, `driver.takeScreenShot(...)`), which talks to the real Appium server, which talks to the real device.
4. Every step is logged to the console and to the `TestReport` (pass/fail + screenshot). When a step fails, a failure screenshot is taken automatically and the recipe either aborts or continues, depending on the failure policy (see [Failure handling](#failure-handling)).
5. After every recipe in the app's list has run, `report.EndReport` writes out `test-report.html` (and `screenshots/` folder) next to the executable.

In short: **the JSON recipe *is* the test script.** You never touch B4J source code to add, change, or reorder test steps — only to add a genuinely new *kind* of step.

## Project layout

```
B4JAppium_Example/
├── B4XMainPage.bas          ← orchestrates one run: load config → start driver/report → run recipes
└── B4J/
    ├── AppiumTest.b4j       ← the B4J project file (libraries, modules, startup)
    ├── AppConfig.bas        ← loads Files/<appId>.json, builds Appium DesiredCapabilities
    ├── RecipeRunner.bas     ← parses a recipe JSON and executes its steps (the test engine)
    ├── AutomotiveTest.bas   ← legacy module, not used by the current flow (kept for reference only)
    └── Files/
        ├── active-app.json              ← which appId runs when no launch argument is given
        ├── ble-observer.json            ← example app config (read directly from Files/, by filename)
        ├── ble-observer-full-navigation.json  ← example recipe for that app
        ├── automotive-demo.json / login-and-wizard.json  ← a second example app + recipe
        └── apps/, recipes/              ← same example files, organized by subfolder (not yet
                                            wired into the loader below — see note in AppConfig.bas)
```

> **Note:** `AppConfig.LoadFromFile` and `B4XMainPage.ResolveAppId` currently read app-config and recipe files **directly from `Files/`** by filename (e.g. `ble-observer.json`), not from `Files/apps/...json`. The `apps/` and `recipes/` subfolders contain identical copies for organization, but if you add a new app you only need to drop its files into `Files/` itself (see below).

## 1. Install Appium

You need: **Node.js**, the **Appium server**, a platform driver (**UiAutomator2** for Android or **XCUITest** for iOS), and the Android SDK platform-tools (`adb`) if you're testing Android.

1. **Install Node.js** (LTS) from [nodejs.org](https://nodejs.org/). Verify with `node -v` / `npm -v`.
2. **Install the Appium server** globally:
   ```
   npm install -g appium
   ```
   Full official instructions: [appium.io — Installing Appium](https://appium.io/docs/en/latest/quickstart/install/)
3. **Install the driver** for the platform you're testing:
   ```
   appium driver install uiautomator2
   appium driver install xcuitest      # only if you're also testing iOS
   ```
4. **Android only** — install the [Android SDK command-line tools / platform-tools](https://developer.android.com/studio/releases/platform-tools) and make sure `adb devices` lists your device/emulator before you continue. Enable **Developer Options → USB debugging** on a physical device.
5. **(Optional but very useful)** install [Appium Inspector](https://github.com/appium/appium-inspector/releases) — a GUI that connects to a running Appium session and lets you click elements in a live screenshot of your app to read back their `text`, `resource-id`, `content-desc`, etc. This is the fastest way to find the exact locator values to put in a recipe (see below).
6. **Start the server** before running any B4J test:
   ```
   appium
   ```
   By default it listens on `http://127.0.0.1:4723`, which matches this project's default `appiumHost`/`appiumPort`.
7. Sanity-check your setup with `appium-doctor`/`appium driver doctor uiautomator2` if anything above fails — it tells you exactly what's missing (ANDROID_HOME, Java, etc.).

## 2. Set up the B4J project

1. Install **B4J** itself if you haven't: [b4x.com](https://www.b4x.com/b4j.html).
2. Build (or download) the **B4XAppium** library — see [B4XAppiumLibrary](https://github.com/walterf25/B4XAppiumLibrary) for the jar/xml and the full list of jar dependencies it needs (Selenium, java-client, guava, ExtentReports).
3. Put `B4XAppium.jar` + `B4XAppium.xml`, all of that library's dependency jars, **and** this project's own `#AdditionalJar` dependencies into your B4J **Additional Libraries Folder** (`Tools > Configure Paths` in the B4J IDE). This project's `AppiumTest.b4j` declares:
   ```
   #AdditionalJar: failsafe-3.3.2.jar
   #AdditionalJar: guava-32.1.2-jre.jar
   #AdditionalJar: selenium-json-4.32.0.jar
   #AdditionalJar: extentreports-5.1.2.jar
   #AdditionalJar: freemarker-2.3.34.jar
   #AdditionalJar: rxjava-3.1.10.jar
   #AdditionalJar: reactive-streams-1.0.4.jar
   ```
   `b4xpages`, `jcore`, `jfx`, `json`, `byteconverter`, and `jokhttputils2` are standard B4X libraries — most ship with the B4J IDE already; any missing ones are available through B4J's own library manager / the [B4X forum](https://www.b4x.com/android/forum/).
4. Open `B4J/AppiumTest.b4j` in B4J. Confirm the IDE resolves `Library1=b4xappium` without an error — if it's red/missing, step 3 wasn't completed correctly.
5. Edit `Files/active-app.json` (or one of the per-app config files) to point at your real device name and APK/`.app` path — see the next section.

## 3. Write an app config JSON

Each app-under-test gets one config file directly under `Files/`, named `<appId>.json`. Example (`Files/ble-observer.json`):

```json
{
  "appId": "ble-observer",
  "displayName": "Observer BLE",
  "platformName": "Android",
  "automationName": "UiAutomator2",
  "appPackage": "sei.observerble2",
  "appPath": "C:\\Users\\Walter\\...\\BLE_Observer.apk",
  "deviceName": "R3GL105QLNZ",
  "appiumHost": "http://127.0.0.1",
  "appiumPort": 4723,
  "basePath": "",
  "extraCapabilities": { "autoGrantPermissions": true, "noReset": true },
  "recipes": ["ble-observer-full-navigation.json"],
  "reportName": "ble-observer-report.html",
  "stopOnRecipeFailure": true
}
```

| Field | Meaning |
|---|---|
| `appId` | Matches `active-app.json`'s `appId`, or a launch argument. Also used as the filename (`<appId>.json`). |
| `platformName` / `automationName` | `"Android"`/`"UiAutomator2"` or `"iOS"`/`"XCUITest"`. |
| `appPath` | Full path to the `.apk` (or `.app`/`.ipa`) Appium should install/launch. |
| `deviceName` | The `adb devices` serial (Android) or simulator/device name (iOS). |
| `appiumHost` / `appiumPort` / `basePath` | Where your Appium server is listening. |
| `extraCapabilities` | Any extra Appium capability as a flat key/value map — merged in as-is, no `appium:` prefix needed (this project's `AppConfig.BuildCapabilities` adds that for you). |
| `recipes` | One or more recipe JSON filenames (see below) to run, in order, each session. |
| `reportName` | Output HTML report filename, written to the app's output folder. |
| `stopOnRecipeFailure` | If `true`, a failed recipe stops the whole run; if `false`, the next recipe still runs. |

Then point `Files/active-app.json` at it:
```json
{ "appId": "ble-observer" }
```
...or skip `active-app.json` entirely and pass the appId as a command-line launch argument — `B4XMainPage.ResolveAppId` checks `Main.StartupArgs(0)` first.

**Onboarding a new app under test never requires editing B4J source** — just add a new `<appId>.json` + recipe file(s) under `Files/` and point `active-app.json` at the new id.

## 4. Write a recipe JSON

A recipe is one JSON file with a `steps` array, run top-to-bottom by `RecipeRunner.RunRecipeFromJson`:

```json
{
  "schema": 2,
  "name": "Example Login Flow",
  "onFailure": "stop",
  "steps": [
    { "name": "Wait for login screen", "action": "waitFor", "locatorType": "text", "locator": "Sign In", "timeoutSec": 15 },
    { "name": "Type username", "action": "type", "locatorType": "text", "locator": "Enter username", "text": "demo_user" },
    { "name": "Tap sign in", "action": "tap", "locatorType": "text", "locator": "Sign In" },
    { "name": "Confirm dashboard loaded", "action": "assertVisible", "locatorType": "text", "locator": "Dashboard", "timeoutSec": 10 },
    { "action": "screenshot", "name": "Dashboard" },
    { "action": "sleep", "ms": 500 },
    { "action": "back" }
  ]
}
```

### Step fields

Every step can have a `"name"` (shown in logs/report) and `"screen"` (for your own bookkeeping — not used by the engine). The required fields depend on `"action"`:

| `action` | Required fields | What it does |
|---|---|---|
| `waitFor` | `locatorType`, `locator`, `timeoutSec` | Polls every 350ms until the element appears, or fails after `timeoutSec`. |
| `tap` | `locatorType`, `locator` | Finds the element and clicks it. Fails the step if not found. |
| `tapIfPresent` | `locatorType`, `locator` | Like `tap`, but a missing element is **not** a failure — useful for menu items that self-exclude when you're already on that screen. |
| `type` | `locatorType`, `locator`, `text` | Clears the field and sends keystrokes. |
| `assertVisible` | `locatorType`, `locator`, `timeoutSec` | Same polling as `waitFor`, logged explicitly as a pass/fail assertion. |
| `assertText` | `locatorType`, `locator`, `expectedText` | Reads the element's text and compares it; logs pass/fail. Never taps anything. |
| `screenshot` | `name` | Saves `screenshots/<stepIndex>_<name>.png` and attaches it to the report. |
| `sleep` | `ms` | Plain pause. |
| `back` | — | Native back navigation (`driver.Back`). |
| `swipe` | `direction` (`up`/`down`), `durationMs` | Swipes by screen percentage — works across device resolutions. |
| `scrollToText` | `value`, `maxSwipes` | Swipes up repeatedly until text is found (or gives up). |
| `closeMenuIfOpen` | `marker`, `locatorType`, `locator` | Pairs with `tapIfPresent`: if a drawer/menu is still open because the matching tap above was skipped, this closes it. |

### `locatorType` values

| `locatorType` | Resolves to |
|---|---|
| `text` | `driver.tryFindElementByText(locator)` — matches visible text / `content-desc` (Android) or `name`/`label` (iOS). Covers most buttons/labels. |
| `id` | `driver.tryFindElementById(locator)` — a real Android resource-id. |
| `accessibilityId` | `driver.tryFindElementByAccessibilityId(locator)`. |
| `uiSelector` | `driver.tryFindElementByAndroidUIAutomator(locator)` — a raw `new UiSelector()...` expression string, e.g. `new UiSelector().textContains("Ranger")`. Android only. |
| `xpath` | `driver.findElementByXPathRaw(locator)` — a raw XPath expression, for anything the above can't express (e.g. matching a specific icon by its position in the layout tree). |

**How do you find the right `locator` value for your app?** Run `appium` (step 1 above), launch your app on the device, open **Appium Inspector**, connect it to the running session, and click the element you want — it shows you its exact `text`, `resource-id`, and `content-desc`. That's the value you put in the recipe.

### Failure handling

- A failed step aborts the recipe **unless** that step sets `"continueOnFailure": true`, or the recipe's root sets `"onFailure": "continue"` (default is `"stop"`).
- Any failed step automatically takes a `FAILED_step_<n>.png` screenshot and logs it to the report, regardless of the policy above.
- `RecipeRunner` never calls `report.EndReport` itself — `B4XMainPage.Button1_Click` owns that, once, after every recipe in the app's `recipes` list has finished (success or failure), so multiple recipes can share one report.

### Legacy schema 1

Older recipes using `waitForText` / `tapText` / `waitForId` / `tapId` / `typeId` / `tapUi` are automatically normalized to the schema-2 actions above by `NormalizeStep` — you don't need to rewrite them, but new recipes should use schema 2 directly (set `"schema": 2`).

## 5. Run it

1. Start `appium` and confirm your device is reachable (`adb devices`, or the simulator is booted).
2. Open `AppiumTest.b4j` in B4J, hit Run.
3. Click the button on the form — it runs every recipe listed for the active app, in order.
4. Check the console log for a live play-by-play, and open the generated `test-report.html` (next to the built executable, in the output folder) for the full pass/fail report with embedded screenshots.

## License

No license file is included — ask the repo owner before reusing this outside personal/internal use.
