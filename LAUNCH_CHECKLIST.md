# RemoteLove Launch Checklist

Use this checklist before TestFlight beta, then again before App Store review.

## 1. Product Readiness

- [ ] Family account creation works on a fresh install.
- [ ] Existing family sign-in loads the correct care circle.
- [ ] First care setup creates a care profile, owner membership, and invite codes.
- [ ] Helper access works after a fresh install.
- [ ] Returning helper access works with name/PIN without creating duplicate helpers.
- [ ] Family invite redemption works with a valid code.
- [ ] Invalid invite code followed by valid invite code works without stale errors.
- [ ] Logout returns to the login screen for family and helper users.
- [ ] Demo family and demo helper flows are clearly marked as demo/test data.
- [ ] Empty states are friendly in Overview, Care, Planner, Health, Care Circle, and More.

## 2. Care Data Workflows

- [ ] Add, edit, complete, undo, and redo care tasks.
- [ ] Family task completion is controlled by caregiver mode.
- [ ] Helper can only do actions allowed by their permission.
- [ ] Planner medicine, appointment, and other items sync to Supabase.
- [ ] Planner items that should become care tasks appear in the Care tab.
- [ ] Health readings sync to Supabase and are visible to other members.
- [ ] Health status labels are understandable: good, watch, attention, etc.
- [ ] CSV export works for selected categories and all categories.
- [ ] Photo-required tasks can attach/upload photos.
- [ ] App remains usable when photo permission is denied.

## 3. Notifications and Widgets

- [ ] Notification permission onboarding explains why notifications matter.
- [ ] Users can enable and disable notifications.
- [ ] Send test notification works on a real device.
- [ ] Task due notifications use friendly wording.
- [ ] Notification actions work where supported.
- [ ] App opens the right task when a photo-required task notification is tapped.
- [ ] Muting notifications behaves as expected for family and helpers.
- [ ] Widget renders readable text in light and dark appearances.
- [ ] Widget updates after relevant in-app changes.

## 4. Payments and Entitlements

- [ ] If subscriptions are available at launch, StoreKit purchases are fully implemented.
- [ ] Monthly, yearly, and lifetime plan choices match App Store Connect products.
- [ ] Three-day trial is configured in App Store Connect for subscription products.
- [ ] Restore purchases is available.
- [ ] Manage subscription is available.
- [ ] Backend entitlements update only after a valid purchase/transaction.
- [ ] Helpers cannot see care plan purchase UI.
- [ ] Plan limits are enforced consistently: family members, helpers, and care profiles.
- [ ] Cancelled/expired/revoked plans downgrade correctly.

## 5. Supabase Security

- [ ] Run `Supabase/RemoteLove_RLS_Audit.sql` in Supabase SQL Editor.
- [ ] Every care-related table has RLS enabled.
- [ ] No care data table grants direct access to `anon`.
- [ ] Users can only read/write care recipients they belong to.
- [ ] Helpers cannot grant themselves family or owner access.
- [ ] Invite codes cannot create owner memberships.
- [ ] Invite code redemption uses RPC/functions, not direct table browsing.
- [ ] Storage buckets for photos have policies matching care-circle access.
- [ ] Service-role keys are not present in the iOS app.
- [ ] Supabase anon key is the only public key in the client.

## 6. App Store Connect

- [ ] Apple Developer Program membership is active.
- [ ] Bundle ID, signing team, app target, and widget target are valid.
- [ ] App icon is final.
- [ ] Version and build numbers are aligned across app extensions.
- [ ] Privacy Policy URL is public and working.
- [ ] Support URL is public and working.
- [ ] App description, subtitle, keywords, age rating, and screenshots are ready.
- [ ] Privacy Nutrition Label is completed.
- [ ] Review notes include a demo account and clear tester instructions.
- [ ] Export compliance answer is completed.
- [ ] Subscription/in-app purchase products are submitted with the app if enabled.

## 7. Legal and Safety

- [ ] Privacy Policy is available in-app and on the web.
- [ ] Terms of Use are available in-app and on the web.
- [ ] Data deletion instructions are available in-app and on the web.
- [ ] Safety disclaimer states RemoteLove is not for emergencies.
- [ ] Support flow tells users to contact emergency services for urgent danger.
- [ ] Health/care information is framed as tracking/support, not medical diagnosis.

## 8. Real Device QA

- [ ] Test on at least one small iPhone.
- [ ] Test on at least one large iPhone.
- [ ] Test light mode.
- [ ] Test dark mode.
- [ ] Test Dynamic Type large text.
- [ ] Test VoiceOver basics for login, tabs, task completion, and forms.
- [ ] Test poor network or airplane-mode recovery.
- [ ] Test after killing and reopening the app.
- [ ] Test after deleting and reinstalling the app.
- [ ] Test push/local notifications on a real device.

## Launch Recommendation

RemoteLove should go through TestFlight before public release. Use at least 5 to 20 testers covering family-owner, family-member, and helper roles before App Store submission.
