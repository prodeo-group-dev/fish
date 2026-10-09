# Business Owner MFA: lost-device recovery policy (draft for Femi's approval)

**Status:** 2026-10-09, draft policy plus build outline. Written by the EA session at CM's request after Femi's decision that an authenticator app (TOTP) is **required for Business Owners**. **Femi approves this policy before MFA is switched on.** Nothing is built; the build is described in section 8 and sits behind config flags that default OFF, switched on only on CM's go, so testers are not locked out. Related: `docs/EA_Tenancy_ID_Design.md` section 10.12.

## 1. Why this policy matters more than the MFA itself

MFA protects the Owner from someone who has his password. The recovery path decides what happens when the Owner has **lost** the device, and it is the first place an attacker will go: "I lost my phone, please reset my MFA." If that path is quick and works on a phone call, MFA adds nothing. So the policy is deliberately slow, needs two people, and needs proof from outside the channel the requester controls. **Slow and annoying for a genuine Owner is the price of being hard for a social engineer.**

Cognito allows **one** authenticator-app device per user and gives no backup codes, so there is no second device to fall back on. That is why this policy exists.

## 2. Principles

1. **Two people, always.** One operator handles the request, a different operator approves it. Operators act with their own named token, so every step has a name. (Femi is the break-glass approver.)
2. **Proof comes from outside the requester's channel.** A caller who asks is not allowed to supply the phone number, the email, or the evidence.
3. **Nothing happens immediately.** An approved reset waits through a cooling-off period during which the real Owner can cancel it.
4. **Everyone on file is told.** The Owner is told at every address and number on file when a request is opened, approved, cancelled and executed.
5. **Everything is recorded** in an append-only audit entry the Owner can see.
6. **Prefer self-service where it is safe** (section 3, path 0), so operators are the exception.

## 3. Paths

**Path 0: the Owner still has a signed-in session (a laptop, say) and lost only the phone.** He replaces the device himself in Settings after re-entering his password. No operator, no waiting. (He cannot do this if every session is gone.)

**Path 1: no session, no device.** The operator process below. A genuine Owner who uses this path accepts a delay.

## 4. Proof required (Path 1)

All of the following, none supplied by the requester except as noted:
1. **A request from the registered email** (or, if that mailbox is itself lost, Path 1 stops here and goes to section 7).
2. **The Tenancy ID** quoted by the requester (it is a label, so it proves little on its own).
3. **A call-back to the verified admin phone number held on file** (the number from onboarding, never one the requester gives), by the handling operator, who confirms the request on that call. This is the main out-of-band proof.
4. **Two knowledge checks drawn from facts held in EA at onboarding**, asked by the operator and answered without prompting: for example the date of birth, the company registration number, the registered address (the Company profile fields). The operator records pass or fail per question, never the answers.
5. **For a high-risk case (section 6), a fresh identity check** through the KYC channel the Owner used at onboarding.

An operator who cannot obtain 1, 3 and at least one of 4 **refuses**, and the refusal is itself recorded.

## 5. Process and timings

1. **Open.** The handling operator records the request and which proofs passed. EA emails the Owner's registered address: "A reset of your authenticator was requested. If this was not you, reply STOP or use this link." (SMS is not available; the phone is covered by the operator's call-back.)
2. **Approve.** A second operator reviews the recorded proofs and approves or rejects. They may not be the same person. Approval needs the proofs recorded, not a re-run.
3. **Cooling-off: 24 hours by default** (configurable 24 to 72). At approval the Owner is told again at the registered address, with a one-click **cancel**. A cancel by the Owner ends the request, signs the account out everywhere, and requires a full recovery review before any later request.
4. **Execute.** At the due time EA, using the operator-approved record, disables the user's authenticator in Cognito and signs the user out everywhere. The next sign-in needs the password and then **forces a new enrolment as the only screen**, before anything else in the app.
5. **After.** The Owner is told "Your authenticator was reset". For **7 days** the account is on elevated monitoring (alerts on sign-in from a new device or location).

## 6. Limits and red flags

- **At most 2 resets per Owner per 90 days.** A third needs Femi's approval and a fresh identity check.
- **A password reset in the last 24 hours plus an MFA reset request** is the classic takeover pattern: hold for 72 hours and require the fresh identity check.
- **No reset on a phone call alone**, ever, and no reset where the requester pressures for speed; urgency is recorded as a red flag.
- **A new Tenant created within the last 7 days** (nothing to protect yet, but also little history to check against): use the fresh identity check.
- Operators never ask the Owner for a one-time code, a password, or the contents of the authenticator, and say so on the call.

## 7. If the Owner's mailbox is lost too

The email in section 4 is gone. The only route is the **fresh identity check** through the KYC channel, plus the call-back to the verified phone, with Femi's approval as the second operator. This is the slowest path and it is meant to be.

## 8. The audit entry

Append-only `owner_mfa_reset_audit` in EA, written when the request is opened (intent) and updated at each step, in the same transaction as each state change; the Cognito call is also in CloudTrail. Fields:
- tenant and Owner user ids, Tenancy ID, request time and channel;
- the proofs checked, each as pass or fail with **who checked it and when** (never the answers themselves);
- the handling operator and the approving operator (their named tokens), with times;
- notifications sent (address or number masked, time, result);
- scheduled time, cancelled time and by whom, executed time and the Cognito result;
- the reason text and any red flags raised.
The Owner sees his own entries in Settings ("security history"). Retention: at least six years (Femi to confirm). EA does not allow edits or deletes of these rows.

## 9. What would be built, behind flags (default OFF)

Not before Femi approves this policy and CM gives the go. Two flags, both off by default so testers are never locked out:
- **`EA_OWNER_MFA_RESET_ENABLED`** (EA): the operator request/approve/cancel actions in Omniview, the scheduled executor, the Owner cancel link, the audit table and the notifications. It needs, from CM, the right to call Cognito `AdminSetUserMFAPreference` and `AdminUserGlobalSignOut` on the user pool (and nothing broader).
- **`OWNER_MFA_REQUIRED`** (WEB): forces TOTP enrolment as the first screen and handles the TOTP challenge at sign-in. The pool is set to `mfa_configuration = OPTIONAL` with the software token enabled (CM); enrolment uses the user's own session.
Tested with a throwaway user Femi creates, never with a real Owner.

## 10. Decisions for Femi

1. **Named operators** who may handle and approve, and that Femi is the break-glass approver.
2. **Cooling-off**: 24 hours, or longer.
3. **Proof**: is a call-back to the verified phone plus one knowledge check enough for a normal case, with the fresh identity check reserved for the red flags?
4. **Limit**: 2 resets per 90 days.
5. **Retention** of the audit entry.
6. **Path 0** (replace the device from a signed-in session): allowed?
7. **A weekly digest** of every request, approval and reset to Femi, so an insider acting alone is visible.
