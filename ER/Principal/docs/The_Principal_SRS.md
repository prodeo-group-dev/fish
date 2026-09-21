The Principal — Software Requirements Specification

School Management Software powered by FiSH+ER

Sep 17, 2026 · Prepared for @Someone

1. Introduction

1.1 Purpose

This Software Requirements Specification (SRS) defines the functional and non-functional requirements for The Principal, the school management product of the FiSH+ER platform. It is intended to guide design, development, QA, and stakeholder sign-off for the initial release, and to serve as the contractual baseline between Policy and Strategy Initiatives CIC (the product owner) and the engineering team.

1.2 Scope

The Principal is the school-operations layer of a larger Education Management Information System (EMIS) SaaS venture targeting Nigerian schools. It unifies admissions, student records, classroom and attendance management, assessment, fee collection, parent communication, and regulatory compliance into a single product, while delegating financial ledger accounting to FiSH (the Financial Spine) and shared administration/operations/UX services to ER (the Enterprise Runtime).

In scope for this SRS:

The Principal's eight core modules: Admissions Office, Student Register, Classroom Manager, Attendance Officer, Assessment Hub, Fee Desk, Parent Gateway, Compliance Centre

Event contracts published from The Principal to FiSH SOP (the operational event processor)

The proprietary Teacher Productivity Index (TPI) and Student Productivity Index (SPI) as they are computed, surfaced, and consumed within The Principal

Mobile-first, offline-capable operation for low-connectivity Nigerian school environments

Out of scope:

FiSH General Ledger accounting logic (posting rules, chart of accounts) — specified separately under the FiSH SRS

ER's cross-product admin/identity services — specified separately under the ER SRS

Learning management (course content delivery) — explicitly excluded from The Principal's brand positioning

1.3 Definitions, Acronyms and Abbreviations

Term

Definition

EMIS

Education Management Information System — the overall SaaS venture

FiSH

The Financial Spine — the platform's financial/GL engine

ER

Enterprise Runtime — shared Admin, Operations and UX services

FiSH SOP

FiSH's operational event processor, which ingests domain events from products such as The Principal

SchoolSOP

The school-domain logic layer beneath The Principal's UI

TPI

Teacher Productivity Index — proprietary metric for teacher performance/accountability

SPI

Student Productivity Index — proprietary metric for student performance/accountability

SRS

Software Requirements Specification

GL

General Ledger

WCAG

Web Content Accessibility Guidelines

1.4 References

The Principal Brand Guidelines (internal brand specification, this working set)

The Principal UI/UX System (internal design-system specification, this working set)

EMIS Business Plan (Policy and Strategy Initiatives CIC, ~128 pages, canonical business reference)

1.5 Overview

Section 2 describes The Principal at a product level — its position in the FiSH+ER ecosystem, its user classes, and its constraints. Section 3 states functional requirements module by module. Section 4 covers data requirements, including TPI/SPI and event contracts. Section 5 covers external interfaces. Section 6 covers non-functional requirements. Section 7 holds supporting appendices.

2. Overall Description

2.1 Product Perspective

The Principal is not a standalone application; it is the school-domain product inside the FiSH+ER ecosystem:

flowchart TD  A[The Principal<br/>School Management UI] --> B[SchoolSOP<br/>domain logic]  B --> C[FiSH SOP<br/>event processor]  C --> D[FiSH GL<br/>financial engine]  A --> E[ER<br/>Admin · Operations · UX]

The Principal owns school-operations data and UX; it never posts accounting entries directly — it emits domain events (Section 4.2) that FiSH SOP consumes and that FiSH GL turns into ledger postings. ER supplies shared identity, admin, and cross-product UX services The Principal builds on rather than reimplements.

2.2 Product Functions (Summary)

Module

Primary function

Admissions Office

Application intake through enrolment

Student Register

Canonical student records

Classroom Manager

Class, timetable and section administration

Attendance Officer

Daily attendance capture and monitoring

Assessment Hub

Grade entry, reporting, SPI computation

Fee Desk

Invoicing and fee-status tracking (postings via FiSH)

Parent Gateway

Parent-facing visibility into attendance, grades, fees

Compliance Centre

Regulatory/safeguarding alerts and audit trail

2.3 User Classes and Characteristics

User class

Description

Technical proficiency

School administrator / Principal

Full oversight of school operations, compliance, and dashboards

Moderate

Teacher

Marks attendance, enters grades, views class rosters

Low–moderate

Attendance Officer / Registrar

Reviews and corrects attendance records, manages Student Register

Moderate

Fee Desk staff

Generates invoices, reconciles payments

Moderate

Parent/Guardian

Views child's attendance, grades, fee status via Parent Gateway

Low, primarily mobile

Compliance/Safeguarding officer

Reviews restricted pastoral notes, audit logs, compliance alerts

Moderate, requires elevated access

Government/regulatory reviewer

Consumes census, attendance, and exam-format exports

Low, view-only

2.4 Operating Environment

Deployed as a cloud-first SaaS platform on AWS infrastructure

Mobile-first, with an offline-capable mode for classroom and field use where connectivity is intermittent

Recommended UI stack: React + TypeScript for web; Flutter (optional) for mobile

Targets both private-school and government-contract deployments across Nigeria

2.5 Design and Implementation Constraints

Must conform to the brand and UI/UX specifications already established for The Principal (Authority Blue / Academic Gold palette, Merriweather/Inter typography, WCAG 2.1 AA)

Financial data must never be written directly by The Principal — all monetary state changes flow through FiSH SOP events to preserve FiSH as the single source of financial truth

Attendance codes, census fields, and exam-result formats must match Nigerian government-mandated formats and cannot be freely redefined by schools

Must support low-bandwidth and intermittent-connectivity conditions typical of Nigerian school environments

2.6 Assumptions and Dependencies

FiSH GL and FiSH SOP are available as backing services and their event contracts are stable at integration time

ER provides authentication, role-based access control, and shared navigation chrome that The Principal consumes rather than builds

The EMIS business plan's scaling targets (5,000 schools, 1,000,000 students by Year 3) inform capacity planning (Section 6.5) but are business, not functional, requirements

3. System Features (Functional Requirements)

Each subsection lists numbered, testable requirements (FR-<module>-<n>) and a priority: M = Must have, S = Should have, C = Could have (MoSCoW).

3.1 Admissions Office

ID

Requirement

Priority

FR-ADM-1

System shall allow staff to create and track an application record through defined stages (Submitted → Under Review → Offered → Accepted → Enrolled)

M

FR-ADM-2

System shall support document upload and review against an admissions checklist

M

FR-ADM-3

System shall generate offer letters and accept/decline responses from guardians

S

FR-ADM-4

On enrolment, system shall emit a StudentEnrolled event to FiSH SOP (Section 4.2)

M

FR-ADM-5

System shall prevent duplicate enrolment of the same student within one academic year

M

3.2 Student Register

ID

Requirement

Priority

FR-REG-1

System shall maintain a canonical student profile (bio-data, guardian contacts, class assignment, medical/safeguarding flags)

M

FR-REG-2

System shall version student profile changes with an audit trail (who changed what, when)

M

FR-REG-3

System shall support bulk import/export of student records (CSV) for onboarding and government census submission

S

FR-REG-4

System shall restrict visibility of safeguarding-flagged fields to authorised roles only

M

3.3 Classroom Manager

ID

Requirement

Priority

FR-CLS-1

System shall allow creation and maintenance of classes, sections, and timetables

M

FR-CLS-2

System shall assign teachers to classes/subjects and detect timetable conflicts

M

FR-CLS-3

System shall support mid-year class transfers with history retained

S

3.4 Attendance Officer

ID

Requirement

Priority

FR-ATT-1

Teachers shall be able to mark present/absent/late for each student in a class session

M

FR-ATT-2

System shall support offline attendance capture with automatic sync on reconnect

M

FR-ATT-3

System shall use government-mandated attendance codes and reject non-conforming codes

M

FR-ATT-4

On submission, system shall emit an AttendanceRecorded event to FiSH SOP

M

FR-ATT-5

System shall surface attendance-pattern alerts (e.g., consecutive absences) to the Compliance Centre

S

3.5 Assessment Hub

ID

Requirement

Priority

FR-ASS-1

Teachers shall be able to enter grades per student per subject against a defined assessment structure

M

FR-ASS-2

System shall compute and display the Student Productivity Index (SPI) per student per term (Section 4.1)

M

FR-ASS-3

System shall compute and display the Teacher Productivity Index (TPI) per teacher per term (Section 4.1)

M

FR-ASS-4

System shall publish report cards to Parent Gateway on release approval

M

FR-ASS-5

On publication, system shall emit an AssessmentCompleted event to FiSH SOP

M

FR-ASS-6

Exam result formats shall be locked to government-mandated structures where applicable

M

3.6 Fee Desk

ID

Requirement

Priority

FR-FEE-1

Staff shall be able to generate invoices per student per billing cycle from a configurable fee schedule

M

FR-FEE-2

Guardians shall be able to pay fees via Parent Gateway

M

FR-FEE-3

On payment confirmation, system shall emit a StudentPaymentReceived event to FiSH SOP for GL posting

M

FR-FEE-4

System shall never write GL entries directly; all financial postings occur exclusively via FiSH

M

FR-FEE-5

System shall display real-time fee-outstanding status per student on the dashboard

S

3.7 Parent Gateway

ID

Requirement

Priority

FR-PAR-1

Guardians shall view their child(ren)'s attendance, grades/SPI, and fee status

M

FR-PAR-2

Guardians shall receive notifications for attendance anomalies, published reports, and invoices

S

FR-PAR-3

Parent Gateway shall be usable on low-end mobile devices with intermittent connectivity

M

3.8 Compliance Centre

ID

Requirement

Priority

FR-CMP-1

System shall maintain an immutable audit log for all pastoral/safeguarding notes

M

FR-CMP-2

System shall raise critical alerts for attendance, safeguarding, and census-validation breaches

M

FR-CMP-3

System shall generate government census exports in the mandated format

M

FR-CMP-4

System shall enforce role-based restricted access to sensitive fields across all modules

M

4. Data Requirements

4.1 TPI / SPI — Proprietary Productivity Indices

TPI (Teacher Productivity Index) and SPI (Student Productivity Index) are the product's core differentiators, framed around addressing accountability gaps in Nigerian education. They are computed within Assessment Hub and consumed across Parent Gateway, Compliance Centre, and government reporting exports.

Item

Requirement

Inputs (SPI)

Assessment scores, attendance rate, assignment completion — exact weighting TBD with product/education leadership

Inputs (TPI)

Class-level SPI trends, attendance-marking timeliness, assessment-submission timeliness — exact weighting TBD

Computation cadence

Per term, recomputed on each new assessment or attendance submission

Storage

Historical index values retained per student/teacher per term to support trend reporting

Access

SPI visible to guardians (own child only) and school staff; TPI visible to school administrators and the teacher themselves, not to other teachers or guardians

Open item: the precise TPI/SPI formulae are a business/education-methodology decision outside this SRS's scope and must be supplied by product/education leadership before Assessment Hub development begins (see FR-ASS-2, FR-ASS-3).

4.2 FiSH SOP Event Contracts

The Principal never writes financial or cross-product state directly; it emits events that FiSH SOP consumes.

Event

Emitted by

Trigger

Key payload fields

StudentEnrolled

Admissions Office

Application accepted and enrolled

student ID, school ID, class ID, enrolment date

AttendanceRecorded

Attendance Officer

Attendance session submitted

student ID, class ID, date, attendance code

AssessmentCompleted

Assessment Hub

Report card published

student ID, term, SPI value, grade summary

StudentPaymentReceived

Fee Desk

Payment confirmed by payment provider

student ID, invoice ID, amount, payment date, method

Each event shall be idempotent (safe to redeliver) and shall include a unique event ID and timestamp to support FiSH SOP's downstream GL posting and audit requirements.

5. External Interface Requirements

5.1 User Interfaces

Web application (React + TypeScript) for administrators, teachers, and Fee Desk/Compliance staff

Mobile application (Flutter, optional first release) for teachers (attendance/grade entry) and guardians (Parent Gateway)

Design system: Authority Blue (#1E2A78) / Academic Gold (#F2C94C) / Slate Grey (#2F2F2F) / Clean White (#FFFFFF) palette; Merriweather for headings, Inter for body and UI; left-sidebar primary navigation with the eight modules; dashboard cards, data grids, and modal-based data entry as specified in The Principal UI/UX System

5.2 Hardware Interfaces

No dedicated hardware; runs on standard desktop/laptop browsers and Android/iOS mobile devices

Must remain usable on low-spec Android devices common in the target market

5.3 Software Interfaces

Interface

Direction

Purpose

FiSH SOP

Outbound (events)

Delivers domain events (Section 4.2) for financial/operational processing

FiSH GL

Indirect, via FiSH SOP

The Principal never calls FiSH GL directly

ER identity/admin services

Inbound

Authentication, role-based access control, shared navigation chrome

Payment provider(s)

Outbound/Inbound

Processes Fee Desk payments; confirmation triggers StudentPaymentReceived

Government census/reporting systems

Outbound

Export of census, attendance, and exam-result data in mandated formats

5.4 Communications Interfaces

HTTPS/TLS for all client–server communication

Offline-first local data store with background sync over available connectivity (Wi-Fi, mobile data), with conflict resolution favouring the most recent authoritative submission

SMS or push notifications to guardians for attendance anomalies, published reports, and invoices (channel TBD by market research)

6. Non-Functional Requirements

6.1 Performance

ID

Requirement

NFR-PRF-1

Dashboard and table views shall load within 3 seconds on a 3G-equivalent connection

NFR-PRF-2

Offline-captured attendance/grade data shall sync within 60 seconds of connectivity being restored

NFR-PRF-3

System shall support at least 500 concurrent active sessions per school at peak (start/end of day) without degradation

6.2 Offline Capability & Mobile-First

Attendance capture, grade entry, and student lookup shall function fully offline, with local storage of the day's operating data

The mobile experience is the primary reference design, given Nigerian connectivity constraints; the web experience is not a lesser fallback but a parallel first-class surface

6.3 Security & Safeguarding

ID

Requirement

NFR-SEC-1

Pastoral/safeguarding fields shall be masked by default and visible only to roles explicitly granted access

NFR-SEC-2

All access to pastoral notes shall be captured in an immutable audit log

NFR-SEC-3

Role-based access control shall be enforced at the API layer, not only in the UI

NFR-SEC-4

Data at rest and in transit shall be encrypted

6.4 Accessibility

Conforms to WCAG 2.1 AA: sufficient colour contrast, full keyboard navigation, screen-reader labels on all interactive elements, and a high-contrast mode

6.5 Compliance & Scalability

ID

Requirement

NFR-CMP-1

Attendance codes, census fields, and exam-result formats shall be validated against government-mandated structures before submission

NFR-CMP-2

Architecture shall scale to the business plan's Year 3 targets: 5,000 schools and 1,000,000 students, on AWS cloud infrastructure

NFR-CMP-3

System shall support multi-tenant isolation between schools, with per-school data segregation

7. Appendices

7.1 Glossary — Module Naming Reference

Branded name

Functional role

Admissions Office

Application-to-enrolment pipeline

Student Register

Canonical student record system

Classroom Manager

Class/timetable administration

Attendance Officer

Attendance capture and monitoring

Assessment Hub

Grading, reporting, TPI/SPI

Fee Desk

Invoicing and fee tracking

Parent Gateway

Guardian-facing portal

Compliance Centre

Safeguarding, audit, regulatory alerts

7.2 Open Issues / TBDs

☐ TPI/SPI exact formulae and weightings — pending product/education leadership sign-off (Section 4.1)

☐ Notification channel for Parent Gateway (SMS vs. push vs. both) — pending market research (Section 5.4)

☐ Payment provider(s) for Fee Desk — to be selected

☐ Government census export format specification — to be attached once confirmed by regulatory bodies

☐ Concurrent-session and storage sizing assumptions behind NFR-PRF-3 and NFR-CMP-2 — to be validated against actual Year 1 pilot data rather than Year 3 targets alone
