# Whoosh: product context and prototype plan

**Version:** 0.4 · **Date:** 10 October 2026  
**Status:** M0 complete on 10 October 2026; next is M1, starting with the provider choice (§14, task 6)  
**Confirmed by the founder:** macOS first; cloud AI; bring your own API key (BYOK); Whoosh observes whichever window the user is working in, or the whole screen they're working on if they choose (This window is the default); a Hush mode independent of macOS Focus ([§13.3](#133-founder-decisions))

## How to use this plan

This document carries the product context into a small, testable implementation. It is exhaustive about the prototype's boundaries and important failure cases; later commercial features have a defined place in the roadmap without becoming prerequisites for the first build.

Treat **confirmed** decisions as settled. **Adopted** choices were made during the plan review on 10 October 2026 and are what M0 builds; change them only by recording the reason. Treat **recommended** implementation choices and numerical defaults as starting hypotheses. Resolve **open** decisions at the milestone identified below. Update this document when a decision changes, including its reason and any affected tests.

The immediate objective is to build one complete interaction: **look at the window the user is working in, offer a grounded comment through an appealing overlay, accept a correction, and improve the next interaction.** Periodic background observation follows once that interaction works.

### Contents

1. [Product context and intended experience](#1-product-context-and-intended-experience)
2. [Decisions and scope](#2-decisions-and-scope)
3. [User experience and controls](#3-user-experience-and-controls)
4. [Technical architecture](#4-technical-architecture)
5. [Capture and request lifecycle](#5-capture-and-request-lifecycle)
6. [Model behavior and response contract](#6-model-behavior-and-response-contract)
7. [Memory and personalization](#7-memory-and-personalization)
8. [Privacy, credentials, and data boundaries](#8-privacy-credentials-and-data-boundaries)
9. [Reliability and failure behavior](#9-reliability-and-failure-behavior)
10. [Build milestones](#10-build-milestones)
11. [Validation and release gates](#11-validation-and-release-gates)
12. [Operating cost and commercial path](#12-operating-cost-and-commercial-path)
13. [Principal risks and decisions still open](#13-principal-risks-and-decisions-still-open)
14. [First implementation tasks](#14-first-implementation-tasks)
15. [Sources and decision history](#15-sources-and-decision-history)

## 1. Product context and intended experience

### 1.1 What Whoosh is

Whoosh is an ambient desktop companion that notices visible work, learns relevant context, and offers occasional encouragement, questions, suggestions, or candid opinions through small animated overlays.

Its appeal has two equally important parts:

- **Useful awareness:** comments connect to the actual work and the user's goals.
- **Enjoyable presence:** motion, visual personality, and tone make the companion pleasant to have around.

The intended feeling is: “It noticed something that mattered, and knew when to say it.” Helpful compliments are part of the product, alongside practical suggestions. Success does not require every interaction to increase productivity.

The initial audience hypothesis is people doing solo writing or visual design work. These activities give us a manageable environment for judging observations and presentation. Broader desktop use, including coding and spreadsheets, remains part of the longer-term direction.

### 1.2 Context preserved from the original idea and presentation

- Whoosh periodically looks at the window the user is currently working in, or, if the user chooses, the whole screen, at a user-controlled pace.
- It asks short contextual questions to learn what the user is doing and why.
- Questions can be answered in place or ignored; ignored messages disappear without demanding a reply.
- Suggestions and opinions generally require no response.
- Feedback can emphasize compliments, a balance of strengths and improvements, or direct criticism.
- Animation amount and visual creativity are independently adjustable.
- The system should remain quiet during work where interruption would be unwelcome.
- A compact text memory captures relevant background and recent work, approximately a week or month depending on the eventual retention setting.
- Whoosh should avoid keeping a screenshot archive.
- The commercial vision includes an open-source BYOK edition and an optional subscription that supplies hosted model access.

The presentation's “always knows what you are doing” language is an aspiration. The implementation maintains an approximate, time-limited understanding of visible activity. Intent, authorship, concentration, and work quality remain uncertain unless supported by evidence or user confirmation.

### 1.3 Core interaction loop

1. Observe the window the user is working in (or the whole screen, if chosen), unless Whoosh is paused or the app in use is excluded.
2. Interpret visible evidence together with a small amount of relevant context.
3. Decide whether silence, a question, or a comment is appropriate.
4. Apply local rules governing interruption and presentation.
5. Show one brief overlay when eligible.
6. Accept an optional reply or correction.
7. Use that information to improve later interactions under the memory rules.

Example: while someone edits a landing page, Whoosh asks whether it is intended for first-time visitors. After the person answers, a later suggestion recommends adding a concrete product example. The improvement should be traceable to the answer rather than merely sounding more familiar.

## 2. Decisions and scope

### 2.1 Decision baseline

| Decision | Status | Consequence |
|---|---|---|
| macOS first | Confirmed | Build and validate the desktop integration on one operating system. |
| Cloud AI | Confirmed | Captured window images and necessary context leave the device for the chosen provider; disclose this clearly. |
| BYOK first | Confirmed | The user supplies a provider key and pays that provider's usage charges. |
| Open-source product direction | Established product intent | Choose a license before publishing; keep credentials and user data out of source control. |
| Native Swift, SwiftUI, and AppKit | Recommended | Use native capture and window behavior with a small dependency footprint. |
| One vision-capable provider/model | Recommended | Validate the core loop before adding provider selection or model routing. |
| Follow the window in use | Confirmed | Whoosh observes whichever window the user is currently working in, across apps. Pause, Hush, and an app exclusion list control what it sees and says (§5.1). |
| Manual interaction before periodic observation | Recommended | Separate basic understanding and overlay problems from timing problems. |
| Predefined animation library | Recommended | The model selects an approved gesture; runtime animation generation is deferred. |
| Small local structured text memory | Recommended | Start with session context, then add inspectable persistent records. |
| Minimum macOS 15.0 | Adopted | Matches the only test machine. The capture APIs used need macOS 14.0+, but 14 stays unsupported until it has been tested. |
| Xcode app target plus a local `WhooshCore` Swift package | Adopted | See §4.4. |
| App Sandbox and Hardened Runtime from the first build | Adopted | See §4.4. |
| Menu-bar app without a Dock icon | Adopted | Whoosh stays out of the way; settings open from the menu. The menu-bar icon shows whether Whoosh is watching, paused, hushed, or skipping an excluded app. |
| Single-window capture filter | Adopted | In This window, only the window in use enters the image; Whoosh's overlay and neighbouring windows cannot (§5.1). |
| Two capture scopes | Confirmed | This window (default) or Whole screen (opt-in). Whole screen captures the display in use through a filter that removes excluded apps, Whoosh, and private system surfaces; the menu bar is included (§5.1, §13.3). |
| Screen Recording permission, not Apple's window picker | Adopted | Following the window in use across apps needs this permission; the picker only grants windows the user picks each session (§5.1). |
| Hush, independent of macOS Focus | Confirmed | Whoosh's quiet mode has its own name and switch; macOS Focus does not change it (§3.4). |
| No Accessibility or Input Monitoring permission | Adopted | Both are far broader than the stated behavior (§4.4, §5.1). |

### 2.2 Prototype stages

| Capability | Manual prototype | Ambient prototype | Memory prototype | Later product |
|---|---|---|---|---|
| Active-window capture, app exclusion list, and BYOK | Included | Retained | Retained | Site-level exclusions if validated |
| “Look now” interaction | Included | Retained | Retained | Retained |
| Short comments, questions, inline replies | Included | Retained | Retained | More polished presentation |
| Four personality/presentation controls | Included with small option sets | Frequency becomes operational | Retained | More styles and presets |
| Periodic capture and interruption limits | — | Included | Retained | Better timing heuristics |
| Session context | Included, held in memory | Included | Included | Retained |
| Persistent user/project memory | — | — | Included | Longer retention and improved retrieval |
| Hosted subscription and billing | — | — | — | Included after validation |
| Multiple providers or operating systems | — | — | — | Separate expansion decisions |

The first implementation excludes audio capture, microphone access, keyboard-content logging, autonomous computer actions, cloud memory sync, a full activity transcript, observing more than one display at a time (or more than one window in This window), and arbitrary generated animation code. Exact arrows attached to changing screen elements are also deferred. These exclusions keep the first proof of value small.

### 2.3 Deliberate changes from the presentation

The plan departs from the original presentation in these places. Public copy, onboarding text, and later presentations must follow the plan.

| Presentation | Plan | Reason |
|---|---|---|
| The image “becomes text, then it is discarded”; “Screenshots are never stored.” | The captured window's image is sent to the cloud provider, which may retain it under its own policy. Whoosh itself does not write screenshots to its files, caches, or logs (§8.2). | Cloud AI is confirmed, and converting the image to text first loses visual evidence needed for design feedback (§4.3). Never use the phrase “never stored”; use the §8.2 wording. |
| Detects deep focus automatically and stays silent. | A manual quiet switch (Hush, §3.4) in the prototype. Automatic timing heuristics come only after M2's deterministic rules work. | Inactivity and appearance are unreliable evidence that someone can be interrupted (§10, M2). |
| The user's own keys “for screen reading and your LLM of choice.” | One provider, one vision-capable model, one key. | Validate the core loop first. Provider choice is a later expansion (§2.2). |
| “You've had this draft open for an hour.” | Allowed only when the duration comes from Whoosh's own local record of observing that window during the current session, never from the model guessing from appearance (§6.3). Needs ambient observation, so not before M2. | Avoids inferring elapsed effort. |
| Four continuous sliders. | Three options per control (§3.2). | Small, testable option sets. |
| “It always knows what you are doing.” | An approximate, time-limited understanding of visible activity (§1.2). | Intent and quality remain uncertain without evidence or confirmation. |

## 3. User experience and controls

### 3.1 Initial onboarding

Explain what Whoosh observes (the window the user is working in, or the whole screen if they choose it, never an app on the exclusion list), let the user choose between the two, which provider receives data, what is saved locally, and the difference between Pause and Hush. Let the user enter their key, review the app exclusion list, grant the Screen Recording permission, and explicitly start the first observation.

Request the Screen Recording permission once, during onboarding, and explain its purpose. macOS grants it for the whole screen; Whoosh's own rules narrow it to the window in use, never an excluded app, and never while paused. Tell the user that macOS itself may periodically ask them to re-confirm the permission (§5.1), and that declining stops observation until it is granted again. Establish any additional permission needed for reliable active-window detection during the platform milestone; do not add it speculatively.

The permission, the key, and settings persist, so relaunching never repeats onboarding. Each launch starts paused, and one Resume action (menu or global shortcut) starts observation. Whoosh is designed to stay open, so this happens rarely. Launch at login is an opt-in setting added no earlier than M2, and it also starts paused.

### 3.2 The four independent controls

| Control | Original intent | Recommended prototype presentation | What it changes |
|---|---|---|---|
| Comment frequency | Rarely to often | Quiet / Occasional / Conversational | Maximum unsolicited messages and minimum spacing. |
| Feedback style | Compliments / both / hard criticism | Encouraging / Balanced / Challenging | Which grounded observations to emphasize and how directly to express them. |
| Animation amount | Minimal to lots | Still / Subtle / Expressive | Amount and duration of movement per eligible interaction. |
| Visual personality | Plain to creative | Understated / Playful / Imaginative | Shape, gesture, and visual treatment within approved assets. |

Feedback style is a product setting, not a model sampling-temperature control. Encouraging mode must not invent praise; challenging mode must not invent faults. Criticism concerns the work and offers a useful next step where possible.

Capture interval is a separate advanced setting. Looking more frequently does not imply speaking more frequently. Increasing visual intensity must not increase message frequency or override quiet modes.

### 3.3 Overlay behavior

- Begin with one bubble in a user-selectable screen corner, on the display containing the window in use. Default to the bottom-right corner, away from macOS notifications in the top-right.
- Keep comments to one or two short sentences. Questions should ask for information that would improve subsequent help.
- Show no more than one unsolicited bubble at a time. Do not stack missed messages or create a notification backlog.
- An unanswered question expires without a reminder. Silence does not mean agreement, satisfaction, or consent to remember an inference.
- Pause fading while the user hovers over, focuses, or replies to the bubble. Provide keyboard dismissal and a reduced-motion presentation. Escape dismisses only while Whoosh's reply field has focus. A bubble that never took focus cannot receive Escape, so it is dismissed with a global modifier shortcut (§4.4). Never register bare Escape globally: it would be taken from the user's app whenever a bubble is visible.
- Showing or animating a bubble must not redirect typing. Keyboard focus is acquired only after an explicit reply action; test returning focus afterward.
- Decorative areas should not block ordinary interaction. Keep the interactive footprint small and outside the work whenever possible.
- Use no audio in the prototype. During Hush, suppress both unsolicited text and decorative motion.
- Avoid repeated observations. Collect evidence about ignored messages during ambient testing. Adaptive throttling is deferred until the baseline policy is evaluated; a later implementation may only tighten the chosen preset's limits, must not silently change that preset, and must have a visible reset.

Start with two or three carefully designed gestures: question arrival, observation arrival, and brief acknowledgement. The final rendering is controlled by the app. Honor the system's reduced-motion preference even when the user has chosen an expressive style.

Implement Animation amount and Visual personality as parameters of those same gestures (amplitude, duration, colour, and shape treatment), not as separately drawn variants for each of the nine combinations.

### 3.4 Pause, Hush, and manual requests

| State/control | Capture and transmission | Comments and animation |
|---|---|---|
| Paused | No new capture or provider dispatch. Cancel active work where possible. | Clear pending output and close unsolicited overlays. |
| Hush enabled | Observation may continue if ambient observation is enabled. This must be stated in the UI. | Immediately dismiss visible unsolicited bubbles, stop their animations, and discard pending output. |
| Manual “Look now” (menu or global shortcut) | One deliberate observation, subject to the same capture and privacy rules. | One requested response; no unsolicited-message quota applies. |
| Ambient enabled | Eligible samples at the chosen interval, within request limits. | Only eligible, timely, useful proposals within local interruption limits. |

For the first implementation, disable “Look now” and reply submission while Paused or Hushed and explain which control to change. This keeps the initial semantics unambiguous. Preserve an active unsent reply draft in session memory until the user resumes or discards it; never submit it automatically on resume. Manual observations count toward API usage limits. The initial inline reply is a local context update and does not itself consume provider usage.

Pause prevents future dispatch; it cannot recall bytes already sent or guarantee that the provider will not charge for an interrupted request. Hush is an interruption control, not a privacy control.

Hush is independent of macOS Focus. Turning a macOS Focus on or off does not change Whoosh, and Hush does not change macOS. The different names keep users from expecting one to control the other.

### 3.5 Provisional defaults

These are starting values for testing, not agreed product promises.

| Setting | Initial hypothesis |
|---|---|
| Capture interval in ambient mode | 180 seconds |
| Occasional message setting | At most 3 unsolicited messages per rolling hour, at least 10 minutes apart |
| Automatic questions | At most 1 per 30 minutes; also counted in the overall message limit |
| Bubble fade time | 8 seconds, suspended during interaction |
| Response field limits | `message`: at most 240 characters, for unsolicited and requested responses alike. Internal fields: `observation` at most 300, `uncertainty` at most 200. `memory_candidates` is ignored before M3; from M3, at most 3 candidates of at most 160 characters each. Longer conversational explanations are deferred |
| Request cap | 50 provider attempts per rolling 24 hours from the first live request in M1. Manual observations, ambient observations, and retries all count. Set the ambient value before M2 |
| Bubble position | Bottom-right corner of the display containing the window in use |
| Request deadline | 20 seconds total, including any retry |
| Maximum snapshot age at display | 30 seconds, with context revalidation |
| Initial feedback and visuals | Balanced, Subtle motion, Playful personality |
| Recent-work memory retention | 7 days when explicitly enabled; evaluate 30 days later |

Quiet and Conversational caps should be set during ambient testing. Frequency is a ceiling, not a target: a valid session can contain no unsolicited comments.

## 4. Technical architecture

### 4.1 Implementation approach

Use a single native macOS application with clear internal components. A small app does not need microservices, a vector database, a background daemon, or a subscription server to prove this experience.

Recommended platform components:

- **SwiftUI:** settings, onboarding, memory inspection, and bubble content.
- **AppKit:** menu-bar presence and overlay window behavior.
- **ScreenCaptureKit / SCScreenshotManager:** filtered capture of individual frames of the window in use.
- **URLSession with ephemeral configuration:** provider requests without an application HTTP disk cache.
- **Keychain Services:** the user's provider credential.
- **Local JSON:** settings, persistent memory when enabled, and content-free usage counters.
- **Carbon `RegisterEventHotKey`:** global shortcuts for Look now, Pause/Resume, Hush, and bubble dismissal without the Accessibility or Input Monitoring permission.
- **`os.Logger`:** content-free diagnostics (§8.2).

Apple documents filtered screen capture and single-frame capture. AppKit supplies nonactivating panels, but reliable typing, click handling, and full-screen behavior remain integration tests rather than assumptions. See [Apple capture guidance](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos), [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager), and [nonactivating panels](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel).

### 4.2 Components and ownership

| Component | Responsibility |
|---|---|
| App coordinator | Owns observation mode, session identity, lifecycle, and cancellation. |
| Capture controller | Owns detection of the window in use, the app exclusion list, eligibility checks, image preparation, and temporary buffers. |
| Provider adapter | Sends the bounded image/context request to one approved provider endpoint and returns a typed result. |
| Context store | Maintains bounded session context and later persistent memory, including provenance and expiry. |
| Interruption policy | Enforces Hush, cooldowns, quotas, deduplication, and stale-result rejection. |
| Overlay controller | Displays validated text and predefined gestures without taking unintended focus. |
| Usage tracker | Counts attempts, provider-reported usage, latency, errors, and estimated cost without recording screen content. |

Only the app coordinator and local policy code can authorize capture, dispatch, display, or persistence. A model response is a proposal, never an authority over those operations.

### 4.3 Request path

```text
User request or eligible timer tick
    -> local capture and budget checks
    -> active-window screenshot in temporary memory
    -> image preparation + small relevant context
    -> direct HTTPS request to the user's model provider
    -> typed response validation
    -> context, age, mode, and interruption checks
    -> silence or one overlay
    -> optional reply and controlled context update
```

Use one model capable of understanding images and producing a structured response. A separate screen-description model can be evaluated later if measurements justify it. Converting an image into an early textual summary may lose spatial and visual evidence needed for design feedback.

### 4.4 Project structure and platform rules (adopted)

- **Xcode app target `Whoosh`:** a menu-bar app without a Dock icon that owns the app settings (Info.plist), entitlements, capture, overlay, and Keychain access. It must be a real app bundle. A command-line executable launched from Terminal would have macOS attribute the screen-capture permission to Terminal, which would invalidate the M0 permission tests.
- **Local Swift package `WhooshCore`:** interruption policy, request lifecycle, usage ledger, response-schema validation, session context, and later memory. It has no AppKit or ScreenCaptureKit dependency, so its tests run against the fake provider with an injectable clock.
- **Sandboxing and signing:** App Sandbox and Hardened Runtime are on from the first build, with only the outgoing-network entitlement added. Hardened Runtime is required for notarization in M4, and the sandbox is far harder to add later. Development builds are signed with a stable Apple Development identity, because ad-hoc signing gives the app a new identity on every build and macOS then stops matching the screen-capture grant. A free personal team is enough until M4.
- **Toolchain:** deployment target macOS 15.0 and the Swift 6 language mode.
- **Global shortcuts:** register only modifier combinations through `RegisterEventHotKey`, never bare keys. Never install global key-event monitors: they need the Accessibility or Input Monitoring permission and would contradict the exclusion of keyboard-content logging (§2.2). The M0 defaults are ⌃⌥⌘L (Look now), ⌃⌥⌘P (Pause/Resume), ⌃⌥⌘H (Hush), and ⌃⌥⌘D (dismiss bubble); they become user-remappable before the pilot.
- **Overlay window:** a nonactivating panel that joins all Spaces and can appear over full-screen apps. Verify both in M0.

## 5. Capture and request lifecycle

### 5.1 Capture eligibility

The target policy is **the window the user is currently working in**: the frontmost normal window of the frontmost application, when that application is not excluded and the window is eligible. Observation follows the user as they switch windows and apps. Validate the window's identity immediately before capture and again before dispatch. In This window, never fall back to full-display capture when detection or capture fails; Whole screen is a separate scope the user must choose.

**Eligibility.** A window is eligible only when all of these hold:

- Whoosh is not paused, and the window's application is not on the exclusion list.
- It is a normal on-screen window: not minimized, hidden, on another Space, or a system overlay, and not one of Whoosh's own.
- The screen is not locked and the machine is awake.
- No secure text entry is in progress. `IsSecureEventInputEnabled()` reports this, for example while a password field has focus; verify it in M0.

Skip the capture otherwise. Do not capture hidden or minimized content merely because the capture API can provide it.

**Finding the window in use.** Checking only the frontmost application is insufficient: the same application can have several windows. Candidate signals for M0 are the frontmost application (`NSWorkspace`) combined with the front-to-back order of on-screen windows and `SCWindow.isOnScreen`. Do not use `SCWindow.isActive` for this: Apple documents it as whether the window is [currently streaming](https://developer.apple.com/documentation/screencapturekit/scwindow/isactive), not whether it has focus. Do not request the Accessibility permission to find the focused window. It is far broader than the stated behavior (it allows controlling the computer), and matching its windows to capture windows relies on private API. Where the window in use cannot be determined reliably, skip capture and expose the limitation before enabling ambient observation.

M0 implementation (10 October 2026): the frontmost application from `NSWorkspace`, then that application's on-screen windows at the normal window level from the window server's front-to-back list (`CGWindowListCopyWindowInfo`), ignoring windows under 50 points on a side. While Whoosh's own window is in front, the application in use before it is used. Some applications float a toolbar or title strip as a separate normal-level window in front of the window it belongs to; Safari and Chrome do this in full screen, and the first build captured Safari's 119-point toolbar instead of the page. A front window with the same left edge and width as a larger window behind it, overlapping it, is treated as such a strip, and the larger window is captured (`WindowSelection` in `WhooshCore`, tested against the measured window stacks).

**Permission (adopted).** Whoosh uses the Screen Recording permission and builds its capture filter from `SCShareableContent` at each capture. Apple's system picker, [`SCContentSharingPicker`](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker), was considered and rejected: it grants only the windows or apps the user picks in a system dialog for that session, so it cannot follow the user across applications. macOS 15 periodically asks users to re-confirm the Screen Recording permission for apps that capture without the picker. Whoosh cannot suppress this. Onboarding must mention it, and M0 must record how each tested macOS release behaves.

**Capture mechanism (adopted).** Capture uses a single-window content filter (`SCContentFilter(desktopIndependentWindow:)`) with `SCScreenshotManager`. This makes two boundaries structural: Whoosh's own overlay and neighbouring windows cannot appear in the image. Do not rely on `NSWindow.sharingType` for exclusion. The trade-off is that the application's other windows are excluded too, such as floating tool palettes, detached inspectors, popovers, and menus. Test this with a design app that uses floating palettes in M0, and document what the model can and cannot see. M0 result: TextEdit's Fonts panel, a separate floating panel, was absent from This window captures, as expected; Whole screen includes such panels. No dedicated design app with floating palettes was available on the test machine.

**Whole screen (confirmed 10 October 2026, §13.3).** An opt-in scope that captures the display the user is working on: the one holding most of the window in use, or the one under the pointer when the desktop is in front. Only that display is captured, never several at once. The filter is `SCContentFilter(display:excludingApplications:exceptingWindows:)`, so the window server leaves out the windows of excluded apps, Whoosh itself, and the system surfaces that can show private content: notification banners, older-style alerts, system password and Touch ID prompts, autofill, the Passwords menu-bar panel, and sign-in sheets (`ScreenExclusions` in `WhooshCore`; identifiers checked on macOS 15.7). What lies behind them shows through instead. The menu bar is included, by the founder's choice: it shows which app is in front, and also other apps' status items, such as a calendar's next meeting. The other rules still apply: nothing while paused, while the screen is locked, or during secure text entry, and nothing at all while an excluded app is in use (Whole screen does not capture everything around it instead). The request carries the window in use's position in the image, so the model can tell what the user is working on. The desktop counts in Whole screen; in This window it is skipped with a message that names the desktop. Whole screen discloses everything else on that display, including other people's messages in open chats; onboarding and Settings say so and suggest excluding chat and mail apps.

**App exclusion list (adopted).** Users can exclude applications that Whoosh must never capture, identified by bundle identifier. The default list contains Whoosh itself, password managers, Keychain Access, the Passwords app, and System Settings. Onboarding shows the list, and excluding the app in use is one action from the menu. While an excluded application is in use, Whoosh skips capture and its menu-bar icon shows that it is skipping.

**Whoosh's own interface.** Opening Whoosh's menu or reply panel must not make Whoosh's UI the window in use, or move capture to another surface. Look now captures the window that was in use before Whoosh's menu or panel opened. A global Look-now shortcut (§4.4) triggers capture without leaving the work; the menu-item path needs its own tests. Define and test these transitions explicitly.

Suspend capture when permission is revoked, the session is locked, or the machine sleeps. Resume only after eligibility is re-established.

A browser window includes its current tab, so every site the user visits can be observed unless the browser is excluded. The prototype does not promise site-level exclusions, private-window recognition, or automatic sensitive-content removal. Such features need separate integrations and validation.

### 5.2 Images and context freshness

Exclude Whoosh's own interface from model input and test that exclusion. Otherwise, the model may respond to its previous messages. Retain enough resolution to read the relevant content; benchmark resizing rather than assuming the smallest image is sufficient.

Attach the following local metadata to every request:

- Unique request ID and capture timestamp.
- Captured window and owning application identity.
- Session/context revision.
- Memory revision.
- Manual or ambient trigger type.

Invalidate outstanding work when its context changes, the user pauses, Hush changes, the user moves to a different window, memory is deleted, or the session ends. Opening Whoosh's own menu or reply panel is not a window change (§5.1). Recheck eligibility before display and persistence. Never let a delayed result recreate forgotten information.

Window identity alone cannot establish that its document has remained unchanged. Use a short expiry and, where practical, a local content-change check of the same window. Discard an automatic response when relevance is uncertain. This remains best effort; the app cannot infer every semantic change from pixels.

### 5.3 Concurrency and budgets

- Allow one provider request in flight. Debounce repeated manual triggers and skip ambient ticks while busy.
- Keep no image backlog. On reconnect or wake, take a fresh eligible sample instead of processing old captures.
- Use a single retry owner. Disable or account for SDK retries so application retries do not multiply attempts.
- Permit at most one retry for an eligible transient failure within the original total deadline and remaining budget. Respect provider retry delays; skip when they exceed the deadline.
- Do not retry invalid credentials, exhausted quota, permission denial, explicit cancellation, invalidated context, or malformed responses automatically.
- Reserve and persist a usage attempt before network dispatch, including each retry. If the accounting write fails, stop new requests and show a quiet error. Count silent outcomes and uncertain timeout results as consumed; a crash must not reset an already dispatched attempt.
- Enforce a local daily request cap from the first live request in M1 (§3.5), defined as a rolling 24-hour window of persisted attempt timestamps. Manual observations, ambient observations, and retries all count toward it. Set the ambient value before enabling ambient operation. Treat provider billing as authoritative; local cost estimates may lag or be incomplete.

## 6. Model behavior and response contract

### 6.1 What the model receives

Send the current permitted screenshot, brief app instructions, the selected feedback style, a bounded set of relevant context, and recent interaction summaries needed to avoid repetition. Do not send an entire memory file or every previous message by default.

The initial adapter should use a fixed approved provider endpoint. Provider, model, retention configuration, image sizing, and output limits must be recorded together. Avoid arbitrary endpoint configuration in the first UI because it changes where images and credentials go.

In the initial prototype, submitting an inline reply updates bounded session context and shows a brief local acknowledgement. It does not trigger a provider request, take another screenshot, or retrieve a discarded image. The next explicit “Look now,” or later eligible ambient observation, uses the answer. Immediate model-backed conversation and longer explanations are deferred; adding them requires an explicit metered action and a separately bounded presentation.

Entering Whoosh's reply panel is an intentional UI transition, not a new project. Bind the reply to the originating session and question. If the user has changed project or ended that session, do not attach a stale reply to the new context. Pause and Hush submission restrictions still apply.

### 6.2 What the model returns

Use a small versioned response schema. An illustrative result:

```json
{
  "schema_version": 1,
  "observation": "A landing-page draft with a short headline is visible.",
  "uncertainty": "The intended audience is unknown.",
  "response_type": "question",
  "message": "Is this page for first-time visitors or existing users?",
  "animation_id": "question_arrival",
  "memory_candidates": []
}
```

Allowed response types are `silent`, `question`, and `comment`. Validate field types, maximum lengths (§3.5), enumerated values, and candidate counts locally. Unknown animation IDs receive a safe static fallback. Malformed responses are never shown as raw payloads.

Observation and uncertainty are internal context, not automatically durable memory. The model's self-reported confidence must not be treated as a calibrated guarantee.

### 6.3 Behavioral rules

- Ground observations in the visible work and confirmed context.
- Do not infer ownership, elapsed effort, emotions, or user intent from appearance alone.
- Praise specific strengths. Offer specific improvements. Adapt directness without changing factual standards.
- Ask questions only when the answer would materially improve later help.
- Prefer silence to repetitive, generic, or weakly supported comments.
- Separate the user's explicit replies from text visible inside documents or web pages.
- Treat instructions within screenshots as quoted content, not commands to Whoosh.
- Return plain text and approved gesture identifiers; never executable code, arbitrary HTML, computer actions, or changes to privacy settings.

Small text, charts, and precise spatial localization require evaluation. OpenAI's vision documentation explicitly lists related limitations; this is one provider example, not a guarantee about the provider eventually selected. [Official vision guidance](https://developers.openai.com/api/docs/guides/images-vision).

## 7. Memory and personalization

### 7.1 Start with session context

The manual and first ambient prototypes keep conversational context in RAM. Exiting the session clears it. A reply can improve the next interaction without requiring long-term storage.

Use a small recent-turn buffer and compact summaries with a configured context budget. Keep corrections attached to their source so summarization does not turn a tentative guess into a confirmed fact. Provider requests containing those summaries are still cloud disclosures.

Provide a “New session / project” action that cancels pending work, clears the conversation, unsent drafts, transient observations, and derived summaries, and asks which saved project context to use, if any. Preserve global confirmed preferences unless the user clears them. Switching windows or apps invalidates pending screen-dependent output but does not silently assign a new project. Automatic project detection is deferred.

Because observation follows the user across apps, session context accompanies observations of unrelated windows. The instructions must tell the model to use context only when the visible work matches it, and tests must check that details of one piece of work do not appear in comments about another.

### 7.2 Add three explicit memory categories

| Category | Example | Persistence rule |
|---|---|---|
| Confirmed background/preferences | “Prefers direct feedback on writing.” | Persist after an explicit Remember action; settings deliberately changed in the app can be saved as settings. |
| Confirmed project context | “This landing page targets first-time visitors.” | Persist after an explicit Remember action; associate with a project/session label and allow correction, expiry, or removal. |
| Recent-work notes | “Reviewed the introduction of a landing page.” | Automatically save only after the user enables recent-work memory; expire under the chosen retention period. |

Tentative interpretations remain marked as inferred. Do not automatically promote them into stable user facts. Only application code can mark a record as confirmed after deliberate user input; the model cannot confer that status. Avoid saving private document contents, third-party details, or secrets merely because they appeared on screen.

For the first persistent-memory implementation, the user explicitly associates a session with a project label. Retrieve project-specific facts only for that chosen project. A reused window or similar-looking document is not sufficient evidence that two projects are the same. Global preferences can apply across projects; project details must not leak into unrelated feedback.

### 7.3 Minimal storage model

A local JSON document is adequate initially. Each record should contain a stable ID, category, concise text, source type, confirmation status, creation/update time, optional project label, and expiry where applicable. Include a schema version and use atomic writes.

Keep settings and content-free usage counters separate from memory. Keep API credentials in Keychain. Initial memory is readable local text, not app-encrypted storage; OS access controls do not prevent the user's backup or sync tools from copying it. Decide whether additional encryption is needed before broader distribution.

Set bounded record counts, per-record length, and prompt-context size during the memory milestone. On overflow, expire old recent notes first and expose any limit to the user. Never silently discard confirmed preferences or allow growth without a bound. A vector database is unnecessary for this initial scale.

### 7.4 Inspection, correction, and forgetting

Provide a “What Whoosh remembers” view with the record's source, confirmation state, and expiry. Support edit, delete, clear session, clear all saved memory, and disable future memory writes.

User corrections supersede conflicting inferences. On deletion, increment the memory revision and remove the affected raw conversation turns, observations, dependent saved notes, derived summaries, and request caches. Reset the entire ephemeral session when the affected content cannot be traced reliably. Prevent in-flight responses from writing the fact back. Apply equivalent cleanup to expired notes so expired content is not retained through a derived summary. Purge expired records both on startup and before context construction.

Forgetting stored information does not make the same visible screen content permanently unobservable. A later authorized capture may reveal it again. For the first version, forgetting also disables automatic recent-work memory until the user explicitly re-enables it; show this consequence in the control. Saving the fact again as confirmed context requires a fresh Remember action.

“Forget” removes Whoosh-managed local copies and stops using them in future requests. It cannot retract content already sent to a provider or erase independent OS backups. The application should create no hidden content-bearing backup or analytics archive.

## 8. Privacy, credentials, and data boundaries

### 8.1 Data inventory

| Data | Location and lifetime | Rule |
|---|---|---|
| Screenshot pixels and encoded upload | Temporary client buffers; provider receives the request | No deliberate application file, cache, or log persistence. Release after processing/cancellation. |
| Session replies and observations | RAM; relevant excerpts sent to provider | Bounded and cleared with the session. |
| Saved preferences/project notes | Local JSON when enabled; relevant entries may be sent to provider | Inspectable, editable, expiring where applicable. |
| Provider key | macOS Keychain; transmitted only for provider authentication | Never put in prompts, logs, memory, exports, or source control. |
| Settings and usage counters | Local files | No screen text, app/window titles, or message bodies in usage telemetry. |
| Operational diagnostics | Local, bounded, content-free | Log timing, status/error codes, and counts; avoid provider error bodies that echo input. |

Apple's Keychain Services provide encrypted storage for small secrets. Use an app-scoped, nonsynchronizing credential entry appropriate to the selected distribution configuration. [Keychain Services](https://developer.apple.com/documentation/security/keychain-services).

### 8.2 Screenshot-retention promise

The implementable local promise is: **Whoosh does not deliberately write screenshot images to its application files, caches, or logs.** Audit the networking layer, debug tooling, error handling, and crash reporting as well as the capture code.

Never log message text, model output, window or app titles, or provider error bodies. On macOS, `print` and unified-logging output is saved by the system outside Whoosh's control. Use `os.Logger` with private interpolation by default, and log only status codes, timings, and counts.

**Known limitation: window titles in the system log (M0 finding, 10 October 2026).** Whoosh's own log entries are content-free. However, Apple's ScreenCaptureKit runs inside Whoosh's process, and each time Whoosh asks it for the list of windows (`SCShareableContent`), it writes the title and owning app of every on-screen window to the system log, for example the title of a browser tab. These entries are filed under Whoosh's process, stay on the Mac with the system log (typically for days), can be read by someone with access to the account using the `log` tool, and can be included in a diagnostic report the user creates. Nothing is sent anywhere by this. Whoosh cannot switch it off without silencing all logging for its process, which would also remove its own diagnostics, and that is not a supported control for a shipped app. **Founder decision (§13.3):** document it honestly, request the window list only at the moment of a capture, explain it in the user-facing privacy text before the pilot, and revisit it before ambient observation (M2), which would add these entries at every interval.

This does not promise forensic erasure from all OS memory, swap, or external systems. Cloud provider retention is a separate condition. For example, OpenAI documents application-state retention and abuse-monitoring retention separately; default abuse-monitoring logs may retain content for up to 30 days, and additional retention controls require approval and have limitations. Setting an endpoint's `store` option to false is not a universal no-retention guarantee. [Official data controls](https://developers.openai.com/api/docs/guides/your-data).

Before enabling the chosen provider, document exactly which image/text fields are sent, the relevant endpoint settings, and the provider's applicable retention policy. If absolute no-remote-retention becomes essential, revisit the inference architecture and provider eligibility.

### 8.3 Trust boundaries

The model has no authority to alter capture scope or the exclusion list, enable observation, bypass Hush, change limits, promote memories, or access credentials. Screen content cannot authorize those actions either.

No automatic external links, computer-control tools, or generated executable visuals belong in the prototype. This reduces the consequences of malicious text embedded in a captured page. Also test whether screen instructions can coax the model into exposing unrelated remembered context in an overlay.

## 9. Reliability and failure behavior

| Situation | Required behavior |
|---|---|
| Capture permission denied, revoked, or not re-confirmed when macOS asks | Stop observation and show an actionable state in settings; never broaden capture scope. |
| Window in use closed, minimized, hidden, excluded, or not verifiably eligible | Skip capture and invalidate pending work for that window; capture again only when an eligible window is in use. |
| Pause during an API request | Cancel where possible, reject its eventual output, and prevent future dispatch. |
| Hush enabled during a request or visible bubble | Reject pending output, dismiss visible unsolicited bubbles, and stop active animations. Preserve any unsent user draft locally. |
| The user moves to another window, or the project changes | Discard stale output and any dependent memory proposal. |
| Wrong key or exhausted provider allowance | Stop automatic attempts; provide a quiet settings-level error requiring user action. |
| Rate limit or temporary provider error | Apply the bounded retry policy or skip the moment. |
| Offline, sleep, or wake | No backlog or reconnect burst; revalidate and resume only under the current mode. |
| Malformed model response | Reject it, record a content-free failure, and remain quiet. |
| Local memory parse/write failure | Preserve the last valid file, disable new writes, and explain the problem; do not silently reset memory. |
| Request count or cost estimate limit reached | Suspend further requests and expose a clear status. No silent provider/model fallback. |

Errors should be visible in the menu/settings without repeatedly interrupting work. User-requested actions can show a concise error in their existing interaction surface.

## 10. Build milestones

### M0 — Platform and interaction feasibility

**Deliverable:** a native app shell that captures the window in use, a fake model response, and an overlay.

Validate detection of the window in use, eligibility and the exclusion list, permission flow, screen scaling, own-overlay exclusion, keyboard focus, global shortcuts, and Pause before introducing live AI. Test switching between windows of the same app and between apps, a design app with floating palettes, password fields, an external display, Spaces/full-screen transitions, and closing windows. Support can initially be limited to the validated cases, with unsupported states clearly suspended.

**Exit gate:** capture stays within its declared boundary; a bubble can appear during typing without diverting input; unsupported cases stop safely and visibly. Any needed additional permission is identified and explained.

**Result (10 October 2026): exit gate met.** On the test machine (§13.2), in both capture scopes (§5.1):
- *Boundary.* Neighbouring windows, excluded apps, notification banners, and Whoosh's own interface never appeared in a capture (§14, task 4).
- *Typing.* Bubbles appeared while typing without taking keystrokes or Escape.
- *Unsupported cases.* Paused, hushed, excluded apps, password fields, and no window all stop the capture and say why, in the menu and in a notice for shortcut requests.
- *Permissions.* Nothing beyond Screen Recording is needed (§13.2).

Also validated: full-screen toolbar strips (fixed, §5.1), switching apps during a request, Pause and Hush during a request, a Sidecar second display, and the pointer option.

Not explicitly validated in M0, carried into M1 testing:
- switching between two windows of the same app, a Spaces change, or closing the window during a request (the same identity re-check covers these, but nobody has watched them happen);
- locking the screen or sleeping (the lock check fails closed and sleep drops work in flight, but neither was exercised);
- a 1× (non-Retina) display and a cabled external monitor;
- a design app with floating palettes (only TextEdit's Fonts panel was tested);
- macOS's periodic Screen Recording re-confirmation, which appears over weeks;
- the third-party password-manager identifiers in the default exclusion list.

### M1 — Manual “Look now” prototype

**Deliverable:** one image of the window in use travels to one provider using the user's key and returns one grounded question/comment or an explicit no-comment result. Inline replies improve the next interaction using session context.

Implement response validation, cancellation, staleness checks, the request cap, basic usage reporting, the four controls with small option sets, and two or three polished gestures. Frequency governs future unsolicited messages; manual requests remain subject to usage limits. Do not build a subscription backend.

**Exit gate:** during a real task, the user can request an observation, correct Whoosh, and see that correction improve a subsequent comment. Live requests, invalid-key handling, and a delayed-response cancellation test pass. Review approximately 20–30 representative observations for accuracy, specificity, and visual readability; this is exploratory evaluation rather than proof of general performance.

### M2 — Ambient prototype

**Deliverable:** explicitly enabled periodic observation with local interruption rules, deduplication, Hush, budget limits, and no message backlog.

Add modest timing heuristics only after the deterministic rules work. Lack of typing or pointer motion must not be treated as proof that the user is interruptible. During uncertainty, prefer silence. Measure visual enjoyment alongside annoyance.

**Exit gate:** the user completes several 30–60 minute work sessions with correct Pause/Hush behavior, no stale-message bursts, and enough useful or enjoyable moments to justify leaving Whoosh enabled. Record unwanted-interruption reasons and adjust defaults before expanding scope. Manual prototype success alone does not establish ambient success.

### M3 — Inspectable persistent memory

**Deliverable:** confirmed user/project records, opt-in recent-work notes, provenance, retention, correction, and deletion.

Keep the store small. Add a focused comparison of interactions with and without relevant memory. Test restart, expiry, conflicting corrections, and deletion while a request is in flight.

**Exit gate:** saved context demonstrably improves relevance, incorrect inferences remain distinguishable, and forgetting removes saved and derived copies from later requests. Verify that stale requests and old conversation turns cannot resurrect it. Test this with the original content removed from the captured surface; independent rediscovery in a future authorized capture is a separate event, as defined in section 7.4.

### M4 — Small external pilot

**Deliverable:** a documented installable build for a small group, with known limitations, reproducible setup, key management, and a chosen open-source license.

Prepare signing/notarization for direct distribution, test permission behavior on fresh installations, and document provider charges. Collect feedback and content-free operational measurements only with an explicit collection policy. Share actual work content only through deliberate user feedback.

Apple's direct-distribution workflow uses Developer ID signing and notarization; plan this before sending builds beyond the development machine. [Apple distribution guidance](https://developer.apple.com/developer-id/).

**Exit gate:** people can install, configure, pause, understand charges, and remove the app's stored data without developer assistance. They choose to continue using it after the first novelty period.

### M5 — Hosted service decision

Proceed when the pilot shows sustained value and costs support a subscription allowance. Design the backend, account system, and billing from measured requirements. Multiple providers, additional operating systems, precise visual anchoring, and dynamically generated visuals each require their own scope decision.

Calendar estimates should follow M0 and the initial provider benchmark. These milestones are dependency and acceptance boundaries, not promised delivery dates.

## 11. Validation and release gates

### 11.1 Functional and boundary tests

Use synthetic screens and an injected fake provider for repeatable failure tests. Synthetic fixtures may be kept in the repository; captured user screens must not become test assets automatically.

| Test | Expected result |
|---|---|
| Put a unique marker in a neighboring window | It never appears in the provider image. |
| Switch between windows of the same app, and between apps | Capture follows the window in use; pending output about the previous window is discarded. |
| Make an excluded app, such as a password manager, the app in use | No capture and no request; the menu-bar icon shows that Whoosh is skipping. |
| Click into a password field in an eligible app | No capture while secure text entry is active. |
| Open Whoosh's menu or reply panel, then trigger Look now | The window that was in use before is captured, never Whoosh's own UI. |
| Display a Whoosh bubble over the window in use | Whoosh UI is absent from the captured input. |
| Delay the provider; then Pause, change windows, or delete memory | No stale overlay or memory write occurs. |
| Enable Hush during a visible animation | The bubble closes and motion stops immediately; no pending result replaces it. |
| Type while a bubble appears and fades | No lost, redirected, or swallowed keystrokes. |
| Reply and dismiss with Escape from the reply field; dismiss an unfocused bubble with the global shortcut; click back into work | Keyboard focus behaves predictably and reversibly; submitting the reply performs no capture or API call. |
| Type in other apps, including Escape, while a bubble is visible | Only Whoosh's registered modifier shortcuts are consumed; all other keys reach the user's app. |
| Use an app with floating palettes or popovers | Only the window in use appears in the provider image, and the documented limitation matches what is captured. |
| Whole screen: show an excluded app's window, a notification banner, and a Whoosh bubble on the display in use | None of them appears in the provider image, and what lies behind them does. Whoosh's own menu-bar icon is absent; the rest of the menu bar is present. |
| Whole screen: make an excluded app the app in use, or focus a password field | No capture and no request. |
| Whole screen with two displays | Only the display in use is captured, and the bubble appears on it. |
| Start a new project/session with a reply or request pending | Old drafts and results cannot enter the new project's context. |
| Return malformed JSON, excessive text, or an unknown gesture | Schema limits and safe fallback apply; raw output is not displayed. |
| Put hostile instructions in the document | No settings, permissions, credential handling, or memory-persistence rule changes. |
| Repeated clicks, offline mode, and transient errors | One in-flight request, bounded attempts, no burst after recovery. |
| Exercise success, cancellation, timeout, and controlled crash paths | No image payloads or secrets appear in Whoosh-managed storage or diagnostics, and Whoosh's own system-log entries contain no message text, titles, or image data. ScreenCaptureKit's window-title entries are the documented exception (§8.2). |
| Remove the original content from view, delete its fact, regenerate context, and restart | The fact, source turns, and derived summaries are absent; old data cannot reconstruct it. |
| Exceed local request limits | Further dispatch stops, including after restart. |
| Crash after reserving/dispatching a request, then restart | The attempt remains counted; accounting failure prevents further dispatch. |

Add automated tests for local policy, request lifecycle, schema validation, and memory behavior. Use manual macOS integration checks for capture and focus where unit tests cannot establish the behavior. Separate those results from model-quality evaluations.

### 11.2 Experience evaluation

For each reviewed interaction, assess observable accuracy, unsupported assumptions, specificity, usefulness or encouragement, visual enjoyment, timing, repetition, and whether a question improved later help. Rate content quality and interruption quality separately: a correct comment can still arrive at the wrong time.

Track capture-to-response latency, requests per active hour, silent-result proportion, usage per interaction, failed/cancelled requests, and resource consumption. Do not optimize message volume, reply rate, or animation count as success metrics. Ignoring a message is an intended interaction.

For M1–M3, use local review sheets or explicitly recorded test notes. These contain real work content, so keep them outside the repository or in its git-ignored `local/` folder. Do not create a hidden transcript to make evaluation easier. Set numerical product targets after the first sessions provide a baseline; the hard boundary tests must pass before an external pilot.

## 12. Operating cost and commercial path

### 12.1 Cost model

At a three-minute interval, eight hours of uninterrupted eligibility produces 160 potential capture requests per day. At 22 such days, that is 3,520 requests per month before retries or any later model-backed conversation. Initial inline replies are local updates and do not add a request. Actual usage depends on paused time, skipped samples, model selection, image size, context length, and output length.

```text
Monthly inference cost =
    all image/text input usage × applicable input prices
  + all output usage × applicable output prices
  + any separately billed features

Hosted service cost also includes infrastructure, operations,
payment costs, and support.
```

Use provider-reported usage and current prices for the selected model. Account for image pricing and caching according to that provider's rules. A silent response still costs inference. A cancellation or timeout can still be billed.

Benchmark representative screenshots before optimizing. Useful candidates include reducing unnecessary captures, skipping near-identical images, bounding context, limiting output, and summarizing recent interactions. Check each optimization against lost context and missed useful moments.

### 12.2 BYOK edition

The app sends requests directly to the user's chosen supported provider. It can be free to install and open source, while inference remains a cost paid by the user. Show the destination, configured model, approximate usage, and an accessible way to remove the credential.

The first adapter should be replaceable without redesigning capture or overlays. A large provider abstraction, plugin marketplace, or universal compatibility layer is unnecessary initially.

### 12.3 Subscription edition

The later hosted route is:

```text
Whoosh app -> authenticated Whoosh API -> model provider
```

Keep shared provider credentials on the server. A compiled or open-source desktop client cannot safely conceal a service-wide API key. Official OpenAI guidance likewise requires protecting keys from client-side exposure. [API credential guidance](https://developers.openai.com/api/reference/overview).

The hosted service needs authentication, server-enforced metering and quotas, spend controls, billing, abuse protection, and content-safe operations/logging. Local counters are helpful UX but cannot enforce a commercial allowance against a modified client.

Define what counts toward the allowance: observations, replies, model tiers, retries, and failure treatment. Set a “generous” allowance from observed usage and margins. Keep memory local initially; hosted model access does not require cloud memory sync. Adding Whoosh's server also adds another data-processing boundary that must be explained.

## 13. Principal risks and decisions still open

### 13.1 Risk register

| Risk | Early response | Evidence needed |
|---|---|---|
| Generic or incorrect observations | Narrow the first work types, allow silence, preserve uncertainty. | Reviewed real-work examples and useful corrections. |
| Accurate but irritating interruptions | Explicit Hush, hard caps, short overlays, conservative timing. | Ambient session feedback after novelty wears off. |
| Unclear capture boundaries | Active-window rule, app exclusion list, and platform spike before automation. | Window-switching, excluded-app, tab, hidden-window, and lifecycle tests. |
| A whole-screen permission feels invasive | Clear onboarding, visible watching state in the menu bar, exclusion list, one-step Pause. | Onboarding and pilot feedback, including reactions to macOS re-confirmation prompts. |
| Context from one piece of work leaks into comments on another | Use context only when it matches the visible work; project-scoped memory (§7.2). | Cross-app leakage tests. |
| Whole screen sends third-party content, such as open chats, to the provider | Opt-in scope with This window as the default, explicit onboarding and Settings text, the exclusion list, and private system surfaces removed. | Whole screen boundary tests and pilot feedback. |
| Privacy claims exceed actual behavior | Precise local promise, provider review, content-free diagnostics, and the documented ScreenCaptureKit logging limitation (§8.2). | Storage/network inspection, system-log review, and provider policy record. |
| Memory compounds mistakes | Provenance, confirmation, expiry, correction, and deletion. | Controlled memory comparisons and deletion tests. |
| Cost grows faster than value | One provider, small context, measured request budgets. | Cost per active hour and monthly usage distributions. |
| Visual appeal conflicts with restraint | Independently control motion and frequency; test reduced motion. | Enjoyment and interruption ratings collected separately. |
| Overlay behavior becomes a platform project | Fixed-corner prototype and explicitly limited supported states. | M0 focus and display checks before UI expansion. |

### 13.2 Open decisions and when they matter

| Decision | Recommendation | Resolve by |
|---|---|---|
| Minimum macOS version and target test machines | **Resolved:** macOS 15.0. First test machine: an Apple Silicon MacBook Pro (M4 Pro) running macOS 15.7 with Xcode 26.3 signed in to the founder's Apple ID, built-in display only. Add a machine on the current macOS release before M4, since capture-permission behavior has changed between releases. | Resolved 10 October 2026 |
| Capture permission model | **Resolved:** the Screen Recording permission, so Whoosh can follow the window in use (§5.1). On macOS 15.7, granting it required quitting and reopening Whoosh. No periodic re-confirmation prompt was seen during M0; record when one appears. | Resolved 10 October 2026; re-confirmation behavior recorded when observed |
| Default app exclusion list | Start with the list in §5.1. M0 verified the Apple identifiers; the third-party password-manager identifiers are unverified because none is installed on the test machine. Refine from pilot feedback. | Verify third-party identifiers before M4 |
| Quiet-mode name and macOS Focus linkage | **Resolved:** Hush, independent of macOS Focus (§3.4). | Resolved 10 October 2026 |
| Reliable active-window detection and extra permissions | **Resolved for M0:** public APIs suffice: the frontmost app from `NSWorkspace`, the window server's front-to-back list, and the toolbar-strip rule (§5.1). No permission beyond Screen Recording is needed; Accessibility and Input Monitoring are not requested. Recheck on each new macOS release. | Resolved 10 October 2026 |
| External-display test hardware | **Partly resolved:** an iPad Pro used as a second display through Sidecar (1366 × 1024 points at 2×). Capture of a window on it and bubble placement on its corner passed on 10 October 2026. **Deferred at M0 exit:** a cabled external monitor and a 1× display remain untested. | Before M4 |
| First provider/model and endpoint | Benchmark a small set of representative screens; choose one on quality, latency, cost, and retention. | Before live requests in M1 |
| Daily request cap and cost warning | Start at 50 attempts per rolling 24 hours (§3.5); include retries and manual observations. | Initial value before M1 live requests; ambient value before M2 |
| Final timing and frequency presets | Tune proposed defaults from actual sessions. | M2 exit |
| Recent-memory retention and record limits | Begin with seven-day opt-in notes and small caps. | M3 implementation |
| Local-memory encryption needs | Evaluate expected content and pilot requirements. | Before external pilot |
| ScreenCaptureKit window titles in the system log | Documented (§8.2). Look for a way to request less, or a supported control, before frequent requests begin. | Before M2 ambient; user-facing text before M4 |
| Open-source license and repository publication | GPL-3.0 recommended: it keeps derivative versions of the app open, and the hosted service stays a separate codebase. Review dependencies and assets. **Deferred by the founder:** the repository may be public without a license until then (§13.3). | Before accepting outside contributions or the M4 pilot, whichever comes first |
| Signing, distribution, and update mechanism | Direct signed/notarized distribution is the initial recommendation. | M4 |
| Subscription price, allowance, and hosted provider policy | Derive from pilot economics and applicable agreements. | M5 |

None of the commercial decisions blocks M0. Provider choice does not block a fake-response overlay prototype. Any change to the confirmed macOS/cloud/BYOK baseline should be recorded before changing implementation direction.

### 13.3 Founder decisions

Decisions the founder made on 10 October 2026, after the plan review:

1. **Whoosh observes whichever window the user is working in**, not one window chosen in advance. This needs the Screen Recording permission, granted once during onboarding. Each launch starts paused and needs one Resume action; Whoosh is meant to stay open, so this is rare. macOS 15 periodically asks users to re-confirm the permission, and Whoosh cannot prevent that (§5.1).
2. **The quiet mode is called Hush**, and it is independent of macOS Focus (§3.4).
3. **The license is deferred.** The repository can be public before a license is chosen. Until then, the default applies: others can view the code, but have no permission to reuse it. Choose one before accepting outside contributions or starting the M4 pilot (§13.2).
4. **Two capture scopes** (decided after task 3, 10 October 2026): This window, the default, and Whole screen, opt-in. The founder's original intention was the whole screen; the window-only rule came from the plan review. Excluded apps and private system surfaces are removed from Whole screen captures; the menu bar stays in (§5.1).
5. **The pointer is an opt-in setting** (10 October 2026): off by default, in both capture scopes, from the menu or Settings. It shows the model where the user is pointing, at the cost of covering a few letters of small text.
6. **Document ScreenCaptureKit's window-title logging** (10 October 2026) rather than silence all of Whoosh's logging (§8.2).

## 14. First implementation tasks

1. The source repository exists, with this plan at `docs/PROTOTYPE_PLAN.md` and the project `.gitignore`. The license is deliberately deferred (§13.3). Keep credentials, user data, and captured screens out of the repository.
2. Minimum macOS version and first test machine: recorded (§13.2). Signing: done. The founder's Apple ID is signed in to Xcode (10 October 2026), so every build, from the first one, uses automatic signing with the founder's team and a stable Apple Development identity (§4.4). Xcode creates the certificate on the first signed build; ad-hoc signing is not used. Create the Xcode app target, the `WhooshCore` package, and a fake provider adapter. **Done (10 October 2026):** bundle identifier `com.olecramanep.Whoosh`, which macOS uses to key the Screen Recording grant, so change it only before the first grant. The project sets the signing identity to Apple Development, so a build without a team fails with a clear error instead of falling back to ad-hoc signing. The founder selected the personal team in Signing & Capabilities; the signed app was verified to carry Hardened Runtime and only the App Sandbox and outgoing-network entitlements, and to launch inside its sandbox container. `WhooshCore` holds the request metadata (§5.2), the provider protocol, the fake provider, and response validation (§6.2, §3.5), with tests that run via `swift test` or the Whoosh scheme.
3. Implement the Screen Recording permission flow, Pause/Resume, detection of the window in use, the app exclusion list, eligibility reporting, and a nonactivating overlay showing fixed example text. **Done (10 October 2026):**
   - *Implemented.* Onboarding window (§3.1), menu-bar states (ready, paused, hushed, skipping, needs permission), Pause/Resume and Hush (§3.4), Look now with the single-window capture filter and placeholder replies from the fake provider, the global shortcuts (§4.4), and the app exclusion list with "Exclude this app" in the menu. Look now is disabled in the menu while paused or hushed and names the control to change; the shortcut shows a short notice bubble instead. Settings are stored as `Whoosh/settings.json` in Application Support inside the sandbox container. The screen-lock check fails closed: if macOS does not report the session state, Whoosh treats the screen as locked. Debug builds add the capture size to each bubble so capture can be checked without displaying or saving the image.
   - *Default exclusion list.* `com.apple.Passwords`, `com.apple.keychainaccess`, and `com.apple.systempreferences` were verified on macOS 15.7. `com.1password.1password`, `com.agilebits.onepassword7`, `com.bitwarden.desktop`, and `org.keepassxc.keepassxc` are well-known identifiers, but none of these apps is installed on the test machine.
   - *Manual checks passed on the test machine.* After granting Screen Recording, macOS 15.7 required quitting and reopening Whoosh. Bubbles appeared while typing without taking keystrokes. Switching apps during a Look now discarded it. Full-screen Safari captured the whole page (3024 × 1890 pixels) after the strip fix (§5.1). A window on the Sidecar display was captured and its bubble appeared on that display. Hush closed a visible bubble at once. The §11.1 boundary tests remain for task 4.
   - *Whole screen added (founder decision 4, §13.3).* Look At in the menu, Settings, and onboarding choose between This window and Whole screen (§5.1). Manual checks passed with the first version, which cropped the menu bar: the built-in display (3024 × 1888 pixels), the Sidecar display (2732 × 1998), and the desktop were captured. The founder then chose to include the menu bar, so full displays are captured. With Passwords in use, Whoosh skipped. In This window, the desktop was skipped with the new message. Whether excluded apps and notifications are absent from the image is proven in task 4.
4. Prove active-window capture boundaries and typing behavior using synthetic content. **Done (10 October 2026):**
   - *Tools.* Test builds add a Last Capture viewer, which holds the image that would have gone to the provider in memory only, never saves it, and clears it on Pause, sleep, and lock, plus 5-second placeholder replies for timing tests. Neither exists in release builds; this was checked in the built binary. The synthetic test page is `Fixtures/boundary-test.html`: a random code per window, a typing checker, an Escape counter, a shortcut-leak counter, and a password field.
   - *This window, all passed.* A neighbouring window's code never appeared in the capture, and neither did Whoosh's bubble. Look now from the menu captured the page, not Whoosh's menu. A focused password field stopped the capture. Typed text stayed intact while bubbles appeared, Escape reached the page, and no Whoosh shortcut reached it. TextEdit's Fonts panel was absent (the expected limitation, §5.1).
   - *Whole screen, all passed.* The Passwords app's window and a notification banner were absent from the capture, and so were Whoosh's bubble and its menu-bar icon. Only the display in use was captured.
   - *Timing, all passed (confirmed in the logs).* Pause, Hush, or switching apps during a 5-second reply cancelled it with no bubble. Hush closed a visible bubble. Five quick presses produced one observation. The pointer option drew the pointer when turned on.
   - *Storage and logs.* Whoosh's container held only `settings.json` (no screen content) and Xcode's code-coverage file; no image files. Whoosh's own log entries contained no titles or message text. ScreenCaptureKit's window-title entries are the documented exception (§8.2). Whoosh's log entries now use the notice level, because info-level entries had expired before they could be reviewed.
5. Record M0 results and any permission or support limitations in this document. **Done (10 October 2026):** see the M0 result in §10 and the updated rows in §13.2.
6. Select the first provider/model, verify retention and pricing, then implement the live M1 loop.

The first demonstrable result is a “Look now” interaction that notices a real detail, accepts a correction, and gives a better subsequent comment without disrupting the user's work.

## 15. Sources and decision history

### Product sources

- The founder's original Whoosh description and the product and technical discussions that preceded this plan.
- The founder's original Whoosh presentation, used as context: the observation loop, the four controls, the privacy and open-source intent, and the BYOK/subscription model. Deliberate departures from it are recorded in §2.3.
- The founder's explicit confirmation on 10 October 2026: macOS first, cloud AI, and BYOK.

### Technical sources

Official sources are linked next to the claims they support. Apple guidance establishes available platform primitives; application behavior still requires testing. OpenAI sources illustrate one possible provider's documented behavior and do not commit Whoosh to that provider. Verify the selected model, endpoint, prices, and retention configuration again before live integration.

### Change log

| Date | Change |
|---|---|
| 10 October 2026 | Created the plan from the product discussion and presentation; recorded confirmed platform/inference choices; separated manual, ambient, memory, pilot, and hosted-service milestones. |
| 10 October 2026 | Plan review, version 0.2. Removed the contradiction that inline replies count toward the request cap; added a request cap from M1 and per-field response limits; recorded departures from the presentation (§2.3); adopted platform decisions (minimum macOS 15.0, project structure, sandboxing and signing, single-window capture filter, no Accessibility or Input Monitoring permission, global shortcuts, logging rule, bubble position, parameterised gestures); clarified keyboard dismissal; added M0 and boundary tests; added founder decisions pending (§13.3); replaced machine-specific paths with repository paths. Marked verified for M0. |
| 10 October 2026 | Founder decisions, version 0.3: Whoosh observes whichever window the user is working in, using the Screen Recording permission instead of Apple's window picker; added eligibility rules, a default app exclusion list, secure-input skipping, and launch behavior; renamed the quiet mode to Hush, independent of macOS Focus; added related tests and risks; recommended a license; removed the reference to the presentation file. |
| 10 October 2026 | The founder signed in to Xcode with an Apple ID. Signing is no longer a prerequisite: all builds use automatic signing with a stable development identity from the start (§14, task 2). |
| 10 October 2026 | The founder deferred the license choice; the repository may be public without one until outside contributions or the M4 pilot (§13.3). |
| 10 October 2026 | Task 2 done: Xcode app target, `WhooshCore` package, fake provider, and response validation; bundle identifier `com.olecramanep.Whoosh` recorded (§14). |
| 10 October 2026 | Task 3 done: permission flow, Pause/Hush, detection of the window in use, exclusion list, overlay, and shortcuts. Recorded the shortcut defaults (§4.4), the full-screen toolbar-strip finding and window-selection rule (§5.1), the Sidecar second display (§13.2), and the manual check results (§14). |
| 10 October 2026 | Founder decision 4: two capture scopes, This window (default) and Whole screen (opt-in). Updated §1.2, §1.3, §2.1, §2.2, §3.1, §5.1 (Whole screen rules), §11.1 (Whole screen tests), §13.1 (third-party content risk), §13.3, and §14. |
| 10 October 2026 | The founder chose to keep the menu bar in Whole screen captures; removed the crop (§2.1, §5.1, §11.1, §13.3, §14). |
| 10 October 2026 | Founder decisions 5 and 6: the pointer as an opt-in setting, and documenting ScreenCaptureKit's window-title logging (§8.2, §11.1, §13.1, §13.2, §13.3). Whoosh's own log entries moved to the notice level so macOS keeps them for review. |
| 10 October 2026 | Task 4 done: boundary tests passed in both capture scopes, including timing and typing; recorded the results and tools (§5.1, §13.2, §14). |
| 10 October 2026 | Version 0.4. M0 complete: exit gate met; results, untested cases, and deferred hardware recorded (§10, §13.2, §14 task 5). |
