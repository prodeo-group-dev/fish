# Admissions: create an application (JSON) and the form's options (+ER Education, 2026-10-18)

For WEB's "+ New application" form (RT_School_Admission_Create). Built on ER branch `feature/admissions-create-json` (tip below in CM's hand-off); live only once CM merges and deploys it. The old pipe-delimited text body keeps working unchanged.

## Create

`POST /schools/{schoolId}/admissions` with `Content-Type: application/json`. Who: the admissions officer, the registrar, the school admin (unchanged).

```
{
  "applicantRef": "APP-2026-014",        // required, at most 128 characters; unique per school and academic year
  "givenName": "Ada",                    // required, at most 128
  "familyName": "Lovelace",              // required, at most 128
  "academicYear": "2026/27",             // required, at most 32; free text, offer the values from the options read
  "classSectionId": "<id>",              // optional; must be one of THIS school's classes
  "guardian": {                          // required
    "name": "Mrs Lovelace",              // required, at most 128
    "relationship": "Mother",            // optional, at most 64
    "email": "mum@example.com",          // optional, at most 254
    "phone": "+23276000000"              // optional, at most 32; at least one of email and phone is required
  }
}
```

Response 200: `{ "id": "...", "status": "SUBMITTED" }` (the same two fields as before). Then the existing `POST .../admissions/{id}/transition` moves it through the pipeline to ENROLLED (registrar or admin to enrol), exactly as today.

Refusals (JSON `{ "error": "<code>", "message": "..." }`):

| Status | `error` | When |
|---|---|---|
| 400 | `invalid_json` | the body is not valid JSON of this shape: a missing required field (including `guardian`) or **any unknown key** (nothing is silently ignored) |
| 400 | `invalid_application` | a required text is blank, a text is too long, or the guardian has neither an email nor a phone |
| 400 | `unknown_class_section` | `classSectionId` is not a class of this school (another school's class answers the same) |
| 409 | `conflict` text | the same applicant and academic year already exists (unchanged behaviour) |
| 401, 403 | | no credential, or no admissions role at this school (unchanged) |

At enrolment the guardian becomes the new student's first guardian.

## The list now carries the guardian

`GET /schools/{schoolId}/admissions` rows gain four **additive** nullable fields: `guardianName`, `guardianEmail`, `guardianPhone`, `guardianRelationship` (null for applications made through the old body or before this change). Nothing is removed or renamed.

## Options for the form

`GET /schools/{schoolId}/admissions/options` (same roles as the admissions routes) returns this school's own values only:

```
{ "academicYears": ["2026/27"], "classSections": [ { "id": "...", "name": "JSS1 A" } ] }
```

`academicYears` are the years of the school's own terms (empty until the school has set terms up; the form should then accept a typed year). `classSections` are the school's classes, **which a real school cannot yet create over HTTP** (see the fee plan, section 5), so the list can be empty; class is optional on an application.
