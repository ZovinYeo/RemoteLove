# RemoteLove Complete UI Button Testing Instructions

Read `RemoteLove_DOMAIN_MODEL.md` before starting.

I want comprehensive automated testing of every interactive control in RemoteLove. Work directly in this Codex conversation. Do not create agents or subagents.

Do not test against the production Supabase database. Use the existing development or staging environment and clearly marked test records.

## 1. Inventory all interactive controls

Inspect every SwiftUI screen and produce a button-coverage inventory for:

- Welcome
- Family sign-in
- Family account creation
- Family care setup
- Join existing family care circle
- Helper joining
- Overview
- Family
- Helper
- Planner
- Calendar
- Medicines
- Appointments
- Health Monitor
- Care Circle
- Activity History
- Settings
- Alerts, sheets, menus, dropdowns and confirmation dialogs

Include all:

- Buttons
- NavigationLinks
- Toolbar buttons
- Menu actions
- Toggles
- Context-menu actions
- Swipe actions
- Sheet confirmation buttons
- Destructive actions
- Photo and camera controls
- Logout and account-management controls

Create a table containing:

| Screen | Control | Role | Expected action | Testable | Test status |
|---|---|---|---|---|---|

Do not modify code until the inventory is complete.

## 2. Make the controls testable

Add stable accessibility identifiers where missing.

Use descriptive identifiers such as:

```swift
.accessibilityIdentifier("welcome.familyButton")
.accessibilityIdentifier("family.createAccountButton")
.accessibilityIdentifier("task.saveButton")
.accessibilityIdentifier("medicine.saveButton")
.accessibilityIdentifier("appointment.deleteButton")
```

Do not locate controls only by visible text because wording may change.

Do not change RemoteLove’s visual design when adding identifiers.

## 3. Establish a safe UI-test environment

Create or use a UI-testing launch configuration that:

- Never connects to production.
- Uses development/staging Supabase or deterministic test fixtures.
- Contains no real health records or photographs.
- Provides test family, helper and viewer states.
- Provides at least two CareRecipients.
- Resets test state before relevant test cases.
- Does not send real push notifications, emergency messages, emails or SMS.
- Does not contain production credentials in source control.
- Is unavailable in Release builds.

Do not bypass production authorization rules. Test role permissions through the same interfaces used by the real application.

## 4. Build XCUITest coverage

Create automated UI tests that navigate through RemoteLove and test every reachable control.

For each control:

1. Launch the app in the required state.
2. Locate the control using its accessibility identifier.
3. Confirm it exists.
4. Confirm it is hittable or correctly disabled.
5. Tap it.
6. Confirm the expected result.

An expected result must be asserted. Examples include:

- Destination screen appears.
- Sheet opens or closes.
- Menu expands.
- Toggle state changes.
- Loading indicator appears and disappears.
- Validation message appears.
- Record appears in the interface.
- Edited value is displayed.
- Confirmation alert appears.
- Cancel preserves the record.
- Delete removes the test record.
- Logout returns to Welcome.
- Helper is prevented from accessing family-only functionality.

Do not count a test as successful merely because tapping does not crash.

## 5. Test critical RemoteLove flows

At minimum, automate:

- Family sign-in.
- Family account creation without automatically creating a CareRecipient.
- Set up care for someone.
- Join an existing family care circle.
- Helper joins using name and invite code.
- Incorrect invite followed by correct invite.
- Switching between multiple CareRecipients.
- Creating, editing, pausing and removing tasks.
- “Attending now” and “Done”.
- Required-photo task behavior.
- Creating, editing, disabling and deleting medicine.
- Adding, editing and cancelling appointments.
- Logging and filtering health readings.
- Download controls where UI-testable.
- Adding and removing care-circle members.
- Permission controls.
- Emergency alert and acknowledgement using test-only notification behavior.
- Activity-history filters.
- Password-reset entry.
- Logout.

Test owner, family, helper and viewer roles separately.

## 6. Detect blocked buttons

When a control is not hittable, inspect for:

- Transparent overlays
- Remaining popup backdrops
- Conflicting gestures
- `.disabled`
- `.allowsHitTesting`
- Incorrect `zIndex`
- Stuck loading state
- Missing navigation destination
- Wrong environment-object instance
- Validation failing silently
- Async errors being swallowed

Fix the underlying problem. Do not use arbitrary delays or `zIndex` changes without proving the cause.

## 7. Run and report

Run the complete UI-test suite on at least one supported iPhone simulator.

Report:

- Total controls inventoried.
- Controls covered automatically.
- Tests passed.
- Tests failed.
- Controls that could not be automated.
- Root cause of every failure.
- Files changed.
- Build result.
- Test result.

For controls that cannot be automated, such as some camera, notification, StoreKit or external website behaviour, create a short manual-test checklist.

Do not claim that all buttons work unless every inventoried control is either covered by a passing assertion or explicitly listed as requiring manual testing.
