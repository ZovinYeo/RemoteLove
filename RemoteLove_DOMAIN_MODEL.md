# RemoteLove Product and Domain Model

This document is the source of truth for RemoteLove. Read it before modifying authentication, onboarding, CareCircle, CareRecipient, membership, invitation, permissions or role-based navigation code.

## 1. What RemoteLove is

RemoteLove is a native SwiftUI and Supabase care-coordination application. It helps families coordinate the care of an elderly person when family members may not be physically present.

It connects:

- Owners
- Family members
- Helpers or caregivers
- View-only members
- People receiving care

Family members manage the wider care arrangement. Helpers receive a simplified, task-focused experience.

The app includes:

- Multiple people receiving care
- Separate timelines for each CareRecipient
- Scheduled care tasks
- Helper task acknowledgement
- “Attending now” and “Done” task states
- Medication schedules and supply tracking
- Appointments and calendar events
- Health readings and trends
- Care updates and photos
- Emergency alerts and escalation
- Care-circle permissions
- Immutable activity history

RemoteLove coordinates and records care. It does not diagnose medical conditions or replace healthcare professionals.

## 2. Critical domain distinction

Do not treat these concepts as the same thing.

### User account

The identity of someone using RemoteLove.

Examples include a daughter, son, spouse, sibling, helper or viewer.

A user account is not a CareRecipient.

### Care circle

The family or caregiving workspace through which people coordinate care.

A family user may:

- Create a new care circle.
- Join an existing care circle.
- Belong to multiple care circles.
- Have different permissions in different care circles.

### CareRecipient

The elderly person receiving care, such as Mum, Dad or Grandmother.

A care circle may contain one or more CareRecipients, depending on the current approved database model.

Every care-related record must reference the relevant CareRecipient by identifier. This includes:

- Tasks
- Medicines
- Medication schedules
- Appointments
- Health records
- Photos
- Updates
- Emergencies
- Audit-history records

Do not associate records using duplicated names or email addresses.

### CareCircleMember

A membership connects a user identity to a care circle or CareRecipient according to the approved database schema.

The membership contains:

- Role
- Permission level
- Active status
- Date joined

Supported roles are:

- owner
- family
- helper
- viewer

Authentication proves who the user is. Membership determines what the user is allowed to access. These must not be combined into one Boolean such as `isLoggedIn`.

## 3. Welcome route

The first screen presents:

- “I’m a family member”
- “I’m a helper”

These are separate onboarding experiences.

## 4. Family route

Selecting “I’m a family member” opens:

- Sign in
- Create account

Account creation collects only the information needed to establish the family user’s identity and user profile.

Creating a family account must not automatically create a new elderly care profile.

After successful account creation, or after signing in to an account with no active membership, show:

**How would you like to get started?**

1. Set up care for someone
2. Join an existing family care circle

### Family option A: Set up care for someone

Use this when the user is starting a completely new care arrangement.

Required route:

Family account authenticated
→ Create new care circle or care workspace
→ Create first CareRecipient
→ Create owner membership for the signed-in user
→ Generate the appropriate family and helper invitation mechanisms
→ Enter the Family Main App

The creator becomes the owner. Only this route creates a new CareRecipient during onboarding.

### Family option B: Join an existing family care circle

Use this when another family member has already created the care arrangement and CareRecipient.

Required route:

Family account authenticated
→ Enter family invitation code
→ Validate invitation through Supabase
→ Add the signed-in user as a CareCircleMember
→ Apply the role and permissions carried by the invitation
→ Load the existing CareRecipient or permitted CareRecipients
→ Enter the Family Main App

This route must not create:

- A duplicate care circle
- A duplicate CareRecipient
- A second elderly profile
- A new owner membership unless the invitation explicitly grants ownership

A family invitation must be distinguishable from a helper invitation.

### Returning family account

After sign-in:

1. Load the authenticated user profile.
2. Load all active CareCircleMember records.
3. Load the CareRecipients accessible through those memberships.
4. If at least one active membership exists, enter the Family Main App.
5. If no active membership exists, show “Set up care for someone” and “Join an existing family care circle”.

Do not send every returning user through CareRecipient creation.

### Existing family adding another circle

An authenticated family member must be able to join another care circle later from the Care Circle or Settings area without creating another account.

## 5. Helper route

Selecting “I’m a helper” must not show family sign-in or family account creation.

Required helper route:

Welcome
→ “I’m a helper”
→ Enter helper name and helper invite code
→ Start or restore Supabase anonymous authentication
→ Validate and redeem helper invitation through Supabase
→ Create or restore helper membership
→ Load only the CareRecipient connected to the membership
→ Enter Helper Main App

Helpers:

- Do not provide an email address.
- Do not create family accounts.
- Do not create new CareRecipients during onboarding.
- Cannot access the Family tab.
- Cannot manage memberships or permissions.
- Cannot access restricted health-management features unless explicitly permitted.
- See a simplified daily task-focused experience.
- Can submit task updates, required photos and permitted readings.
- Can be removed by an authorised family member.
- Must lose access when membership is deactivated.

`LOVE2026` may remain available only as clearly marked demo helper access. Demo access must be isolated from real production care records and must not bypass production security policies.

## 6. Invitation model

Do not use one ambiguous invitation-code path for every role.

An invitation should carry or resolve to:

- Invitation identifier
- Invitation type
- Target role
- Permission level
- Care circle identifier
- Permitted CareRecipient identifiers
- Creator
- Active or revoked status
- Expiry, if supported
- Redemption state
- Date created
- Date redeemed

At minimum, distinguish:

- Family invitation
- Helper invitation

Redeeming an invitation must be handled atomically by a secure Supabase RPC or equivalent server-side operation.

The redemption operation should:

1. Normalise the entered code.
2. Validate that it exists.
3. Validate that it is active.
4. Validate that it is not expired or revoked.
5. Validate that it matches the intended invitation type.
6. Identify the care circle and CareRecipient access.
7. Create or restore the correct membership.
8. Return the resulting role, permissions and recipient access.
9. Avoid duplicate memberships if the request is repeated.
10. Record an audit-history entry.

A failed code attempt must not poison subsequent attempts. Entering an incorrect code followed by the correct code must work.

Never rely on a local Swift string comparison for production invitation validation.

## 7. Application state model

Do not navigate using multiple unrelated Boolean values such as:

- `isLoggedIn`
- `isHelperMode`
- `hasCreatedProfile`
- `showOnboarding`
- `hasCareRecipient`
- `shouldShowMainApp`

Use a single explicit application route or session state. A suitable conceptual model is:

```swift
enum AppRoute {
    case restoringSession
    case welcome
    case familyAuthentication
    case familyGettingStarted
    case createCareSetup
    case joinFamilyCareCircle
    case helperJoin
    case familyApp
    case helperApp
}
```

The exact names may follow the project’s existing architecture.

The application route must be derived from:

- Supabase authentication state
- User profile existence
- Active membership records
- Membership roles
- Accessible CareRecipients
- Whether onboarding operations completed successfully

Pressing a button alone must not set the application as authenticated or onboarding as complete. Navigate only after the relevant Supabase operation succeeds and returns the required records.

## 8. Role-based application behaviour

### Owner

Can:

- Manage the care setup
- Manage CareRecipients
- Invite and remove members
- Set permissions
- Manage care tasks, medicines and appointments
- View permitted health information
- Access activity history
- Transfer or resolve ownership where supported

### Family

Can:

- Access existing CareRecipients permitted by membership
- Monitor care
- Create or edit permitted tasks
- Manage permitted planner and health features
- Communicate with helpers
- Receive alerts
- Perform only membership actions allowed by their permission level

### Helper

Can:

- Access only assigned or permitted CareRecipients
- See the helper-focused interface
- View relevant daily tasks
- Select “Attending now”
- Complete tasks
- Upload required photos
- Send care updates
- Trigger emergency alerts

Cannot:

- Access the Family tab
- Manage the care circle
- Change roles or permissions
- Create arbitrary CareRecipients
- Access unrelated recipients

### Viewer

Can view only information allowed by membership and cannot modify care records.

Role restrictions must be enforced by Supabase RLS and server-side functions, not only by hiding SwiftUI tabs.

## 9. Multiple-recipient behaviour

A family account may access multiple CareRecipients.

Requirements:

- Each recipient has a separate timeline.
- Each recipient has separate tasks.
- Each recipient has separate medicines.
- Each recipient has separate appointments.
- Each recipient has separate health records.
- Each recipient has separate invite and membership access where required.
- Selecting a profile in Overview must not permanently lock the global profile selector.
- Switching the top “People receiving care” selection changes the active recipient context throughout the application.
- “All profiles” views aggregate data without changing the globally selected recipient unless the user explicitly chooses one.

Never load all records and filter them only by display name.

## 10. Audit history

Activity history is read-only and append-only from the client’s perspective.

It should record:

- Actor user or helper identity
- Actor role
- CareRecipient
- Action category
- Action performed
- Relevant record identifier
- Before and after summary where appropriate
- Timestamp

It should cover:

- Task creation, editing, pausing, completion and deletion
- Medicine changes
- Appointment changes
- Health entries
- Emergency alerts and acknowledgement
- Updates and messages
- Invitation redemption
- Member removal
- Permission changes
- Safety-rule changes

Removing a helper must not erase legitimate historical actions previously performed by that helper.

## 11. Instructions before implementation

Do not modify files immediately.

First inspect:

- SwiftUI app entry point
- ContentView
- Login and welcome views
- Family authentication views
- Helper join view
- Session or authentication store
- Navigation router
- Supabase client
- Database repositories
- Supabase migrations
- RLS policies
- Invitation RPC functions
- Existing CareRecipient creation code
- Existing CareCircleMember creation code

Then produce:

1. The current onboarding state diagram.
2. The corrected onboarding state diagram.
3. Every place where account creation is incorrectly coupled to CareRecipient creation.
4. Every duplicated authentication or navigation state.
5. The current database entities involved.
6. Any schema or RPC changes required.
7. A file-by-file implementation plan.
8. Migration and rollback considerations.
9. Tests that must be added.

Wait for approval of the plan before making broad architectural changes.

## 12. Implementation requirements

When approved:

1. Separate user-account creation from care-setup creation.
2. Add the post-authentication choice: “Set up care for someone” or “Join an existing family care circle”.
3. Implement family invitation validation and redemption.
4. Preserve the separate helper anonymous-authentication route.
5. Load existing memberships after every sign-in and session restoration.
6. Route users based on actual membership records.
7. Prevent duplicate circles, recipients and memberships.
8. Preserve the existing RemoteLove visual design where possible.
9. Add clear loading, success and recoverable error states.
10. Do not store demo data permanently in interface code.
11. Record relevant actions in activity history.
12. Ensure RLS protects all care records.

## 13. Required acceptance tests

### New family starting care

- Create family account.
- Choose “Set up care for someone”.
- Create first CareRecipient.
- Confirm owner membership is created.
- Confirm invitations are generated.
- Confirm Family Main App loads.

### New family joining existing care

- Create family account.
- Choose “Join an existing family care circle”.
- Enter valid family invite.
- Confirm membership is created.
- Confirm existing CareRecipient loads.
- Confirm no duplicate CareRecipient is created.

### Returning family

- Sign in to an account with an active membership.
- Confirm onboarding is skipped.
- Confirm accessible CareRecipients load.

### Family with no membership

- Sign in successfully.
- Confirm the getting-started choice appears.
- Confirm the user is not forced to create a CareRecipient.

### Family joining another circle

- Sign in to an existing account.
- Redeem another family invitation.
- Confirm the account now has access to both memberships.
- Confirm records remain isolated by CareRecipient.

### Helper

- Enter helper name and valid helper code.
- Confirm anonymous identity and helper membership.
- Confirm Helper Main App loads.
- Confirm Family tab is inaccessible.

### Invitation errors

- Enter an incorrect family code, then a correct family code.
- Enter an incorrect helper code, then a correct helper code.
- Confirm both second attempts succeed.
- Confirm revoked or expired invitations fail safely.
- Confirm a helper code cannot be used through the family route.
- Confirm a family code cannot be used through the helper route.

### Permission security

- Attempt to access an unrelated CareRecipient directly by identifier.
- Attempt to promote a helper to owner from the client.
- Attempt to access Family views using helper navigation or a deep link.
- Confirm Supabase rejects all unauthorised operations.

## 14. First instruction for Codex

For the first step, do not modify any code.

Read this complete specification and respond with:

1. Your understanding of RemoteLove in no more than 15 points.
2. The difference between User account, Care circle, CareRecipient, CareCircleMember, Family invitation and Helper invitation.
3. The exact onboarding route for a family member starting new care, a family member joining existing care, a returning family member and a helper.
4. The rules you must never violate.
5. Any conflicts between this specification and the current code.

Wait for confirmation before implementing anything.
