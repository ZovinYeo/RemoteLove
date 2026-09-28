# RemoteLove Beta Test Plan

Use this plan for TestFlight or manual device testing. Record device model, iOS version, tester role, and whether the test passed.

## Tester Roles

- Family owner: creates the care circle and first care profile.
- Family member: joins with a family invite code.
- Helper: joins with helper access and completes care work.

## Test Pass 1: Family Owner Setup

1. Install RemoteLove fresh.
2. Create a family account.
3. Create the first care setup.
4. Confirm the app enters the main family app.
5. Confirm the new care profile appears in Overview, Care, Planner, Health, and Care Circle.
6. Confirm invite code sharing shows only the invite code when copied.

Expected result: setup completes once, no duplicate care circles, no duplicate members, and no login loop.

## Test Pass 2: Family Member Join

1. Install RemoteLove fresh on another device or simulator.
2. Choose the family route.
3. Create or sign in to a different family account.
4. Enter the family invite code from the owner.
5. Confirm the joined care profile loads.
6. Add a task and confirm the owner can see it.

Expected result: valid code joins the correct care circle. Wrong code followed by correct code succeeds.

## Test Pass 3: Helper Join and Return

1. Install RemoteLove fresh.
2. Choose "I'm a helper".
3. Enter helper name and invite code.
4. Set or enter the helper PIN if prompted.
5. Complete a task.
6. Force quit and reopen the app.
7. Confirm the helper can return without creating a duplicate helper profile.

Expected result: helper sees the helper app, not family admin/payment screens.

## Test Pass 4: Care Tasks

1. Add a task for today.
2. Add a task for a future day.
3. Mark today's task done.
4. Undo the task.
5. Edit one occurrence only.
6. Edit all future similar occurrences.
7. Use undo and redo for task edits.

Expected result: order remains sorted by time, undo/redo explains what changed, helper sees only allowed controls.

## Test Pass 5: Planner

1. Add medicine with multiple daily times.
2. Add appointment with custom reminders.
3. Add an "Other" planner item.
4. Use planner filters for medicines, appointments, and other items.
5. Confirm matching care tasks appear where intended.

Expected result: each filter only shows its category, reminders are understandable, and planner-created tasks sync.

## Test Pass 6: Health Monitor

1. Add hydration, mood, blood pressure, and another reading.
2. Confirm status labels appear in Health and Overview.
3. Export selected health categories.
4. Export all health data.
5. Confirm another family member sees the readings.

Expected result: readings sync, statuses are clear, and CSV export opens the share/download sheet directly.

## Test Pass 7: Photos

1. Create a photo-required task.
2. Deny photo access and confirm the app explains how to enable access.
3. Allow photo access from Settings.
4. Attach a photo and complete the task.
5. Confirm another member can see the update if supported.

Expected result: denied permission does not trap the user, and allowed permission lets the task complete.

## Test Pass 8: Notifications

1. Allow notifications during onboarding.
2. Send a test notification from More > Notifications.
3. Create a task due soon.
4. Confirm notification title/body are friendly.
5. Try supported notification actions.
6. Mute notifications for the day.
7. Confirm helper mute behavior alerts family if implemented.

Expected result: notifications are useful, permission state can be changed, and muting is understandable.

## Test Pass 9: Tutorial and Accessibility

1. Create a fresh account and confirm tutorial appears.
2. Step through the family tutorial tab by tab.
3. Skip tutorial and reopen it from More.
4. Repeat with helper mode.
5. Increase text size and repeat main flows.
6. Turn on VoiceOver and navigate login, tabs, and task completion.

Expected result: tutorial points at actual app areas, skip works, and main controls remain accessible.

## Test Pass 10: Failure Recovery

1. Try sign-in with wrong password.
2. Try invite join with wrong code, then correct code.
3. Turn on airplane mode and try adding a task.
4. Restore network and retry.
5. Kill and reopen the app during setup.

Expected result: user-facing errors are friendly, no raw database errors appear, and retry works.

## Beta Exit Criteria

- No blocker issues in account creation, invite join, task completion, or data sync.
- No duplicate helper/member/circle records from normal use.
- No raw Supabase errors shown to users.
- All high-risk RLS audit items are resolved.
- At least three complete family-owner/helper test runs pass on real devices.
