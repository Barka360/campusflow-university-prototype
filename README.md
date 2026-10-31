# CampusFlow university services prototype

CampusFlow is an interactive prototype for university intake, clearance, clinic, Student Affairs, and ID-card collection. It uses fictional sample students and keeps demo changes in the current browser with `localStorage`.

## Run the prototype

Open `index.html` in a modern browser. No build step or account is required. Use the role selector in the top-right to explore the Dean, HOD, Documentation Officer, Clinic Officer, Student Affairs, ID Card Officer, and Student perspectives. Try creating a student, finding a record, recording an office decision, previewing a card, and marking an ID card ready or collected.

## Prototype boundaries

This is a front-end workflow prototype, not a live university records system. It has no server-side authentication, persistent shared database, secure document store, email/SMS provider, scanner integration, or biometrics. File selection in student intake is not uploaded or saved. Do not enter real student information or credentials.

The sample role switcher and scope control demonstrate what each role should see; they are not access controls. Production authorization must be enforced by a trusted server for every record and action. The prototype can be deployed as a public demonstration, but it must not be used for real clearance until the production safeguards below exist.

## Proposed production architecture

- Web app: responsive staff and student portals.
- Identity: university SSO or managed account provisioning, MFA for staff, server-enforced role and faculty/department scope.
- Application API: validates each transition, writes audit events, issues short-lived signed upload/download links, and sends approved notifications through a provider.
- Relational data: PostgreSQL for student identity, office assignments, checklist state, ID-card status, and audit metadata.
- Document store: private encrypted object storage. Store document metadata and object keys in the database, not public URLs. Scan for malware and validate type/size before accepting files.
- Notifications: approved university email/SMS provider, delivery receipts, templates, opt-out/contact preference rules, and retry handling.
- Monitoring and recovery: backups, restore drills, health checks, alerting, rate limits, and a documented offline reconciliation process.

`schema.sql` is a starting point for a Postgres data model. It is not applied to any database. Before using it, adapt the roles and policies to the university's identity provider, jurisdiction, records policy, and approved workflow. The final implementation should use server-side authorization and test for cross-department access leaks.

## Identity and workflow decisions

1. Generate a random temporary clearance ID at intake; keep it as the stable internal record key.
2. Link the matric number after the Registrar issues it. Enforce uniqueness when present; retain the temporary ID as an alias.
3. Use phone/email for contact and verification steps, never as the sole primary key or as authorization to view sensitive records.
4. Define the university's actual office order, exceptions, required documents, and who can approve each transition before implementation.
5. Treat scans as received copies until the responsible office verifies authenticity. Biometrics are intentionally out of scope for this prototype.

## Suggested acceptance criteria for the next phase

- Each office sees only its assigned queue and the minimum data needed for its task.
- Dean access is limited to their faculty; HOD and documentation access is limited to their department; cross-scope access attempts are denied and logged.
- A student can be located by temporary ID before matriculation and linked to a matric number later without creating a duplicate profile.
- Every document view, upload, decision, correction request, identifier change, export, and card collection action produces an attributable audit event.
- ID card readiness follows the configured clearance gates; bulk messages show recipients and content for review and record provider delivery results.
- Student corrections, duplicate resolution, account offboarding, retention/deletion, breach response, outage fallback, and recovery have documented procedures.

## Hosting

The files are static and can be deployed to Vercel as a preview. A production deployment needs the selected university domain, approved account, and secure backend configuration. Do not connect this project to unrelated personal or academy projects.

