# HR bank-details encryption: one key today, per-Company data keys proposed (T15 H7)

**From:** HR session. **Date:** 2026-10-10. **For:** CM (decision). **Status:** design only; nothing built. Read from `HR` on `origin/master` (`1635e1b`) and `Infrastructure/hr.tf` on the date above.

## 1. What is there today (checked in the code)

- `FieldCipher` is AES-256-GCM with a fresh 12-byte IV per value; the stored text is `base64(iv + ciphertext + tag)`. There is **no key id and no additional authenticated data** in it.
- One key encrypts every row of `employees.bank_details`, for every Company and Tenant. It comes from `HR_BANK_DETAILS_ENCRYPTION_KEY`, a Secrets Manager secret (`fish-hr-payroll/production/bank-details-encryption-key`) that `hr.tf` generates with `random_id`. That means the key also sits in the Terraform state.
- Rows are reached by Company, never by Tenant, so today this is **not a read path across Tenants**. The audit table never holds bank details (V9 forces `old_value` and `new_value` to NULL).

## 2. What it risks once HR serves more than one Tenant

1. **One leaked key opens every customer's bank details at once.**
2. **A wrong-row decrypt succeeds.** If a future code path (or a copied or restored row) decrypts Company B's value for Company A, the single key makes it work and the wrong plaintext is returned. Nothing in the ciphertext says whose it is.
3. **No way to retire one customer.** A Tenant that leaves cannot be crypto-shredded without destroying everyone's data.
4. **No rotation story.** With no key id on the row, a new key means re-encrypting everything in one step.

## 3. Proposal

**A. Bind each value to its Company (small, worth doing regardless).** Encrypt with the Company id as GCM additional authenticated data, and write a version and key id in front: `v2:{keyId}:{base64(iv + ciphertext)}`. A value moved to another Company then fails its tag check and fails closed. Old values (no prefix) stay readable with the current key until they are rewritten.

**B. One data key per Company, wrapped by AWS KMS (envelope encryption).** The statement said "per Tenant", but HR's native key is the **Company**: the repository has no Tenant and the Tenant is only learned from the caller's `/me`. A Company belongs to exactly one Tenant, so per-Company keys are at least as strong, need no Company-to-Tenant lookup in the persistence layer, and a Tenant is shredded by shredding its Companies (EA lists them).

- New table `company_data_keys(company_id, key_id, wrapped_key, status, created_at)` (next migration, V15 or later). The data key is made by KMS `GenerateDataKey` on the first bank-details write for a Company, stored only wrapped, and cached unwrapped in memory with a short TTL, so a brief KMS outage does not stop reads. Start-up does not need KMS.
- One KMS key for HR, with the task role allowed `GenerateDataKey` and `Decrypt` only (CM's Terraform). Every unwrap is in CloudTrail. The key never appears in Terraform state, unlike today.
- Rotation: a new `key_id` per Company; reads use the id on the row; rewrites move to the new one; a sweep finishes the rest.
- Failure mode: KMS down and key not cached means that Company's bank details cannot be read or written, answered as 503 (fail closed), not as blank or plaintext.

## 4. Options and cost

| Option | Fixes | Cost | When |
|---|---|---|---|
| Do nothing | nothing | 0 | only while one customer holds real data |
| **A** only (company-bound, versioned format, same key) | risk 2, prepares 4 | about 1 day | before the second Tenant holds real data |
| **A + B** (the proposal) | risks 1 to 4 | 2 to 3 days HR, plus CM's KMS key and IAM | before the second **paying** Tenant, ideally before the Live switch |
| Secrets Manager secret per Company instead of KMS | 1 to 3 | similar, but N secrets, manual rotation, no per-use audit | not recommended |

Production data is still legacy test data, so migrating now is cheap: a one-off re-encrypt of the few rows, then retire the old env key. After the Live switch the same move needs a careful rollout (read both formats, write new, sweep, retire).

## 5. Decisions needed from CM

1. Is A + B wanted before the second paying Tenant, or A first and B later?
2. Per-Company data keys (recommended) or literally per-Tenant?
3. KMS envelope (recommended) or Secrets Manager per Company?
4. CM's side: the KMS key, the task-role permissions, and removing the `random_id` key from `hr.tf` once nothing reads it.

Out of scope here: the display rules for bank details (Epic 5.3, who may see them), which stay as they are.
