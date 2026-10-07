# Loading playbook operator sheets into Omniview's Playbooks tab

**For:** Femi, or an operator with the console open. **Written:** 2026-10-07 by the Omniview session. **Why this exists:** the console is private (reached only over the SSM bastion), so neither the
Omniview session nor CM can write to it. The sheets are ready; this is the short way to load them. The tab accepts a sheet of up to **40,000 characters** (live since task definition :7).

## What goes where

Each sheet is a file in the FiSH repository. Load each as **one live sheet per subject**. A ticket then shows the sheet for its **industry** and the sheet for the **service** it was raised from.

| Sheet file (in the FiSH repo) | Kind | Subject | Name to give it | Owning service |
| --- | --- | --- | --- | --- |
| `docs/Omniview_Operator_Sheet.md` | SERVICE | `OMNIVIEW` | Omniview (the support console) | `OMNIVIEW` |
| `docs/SOP_Playbook_Draft.md` | SERVICE | `SOP` | Sales Order Processing | `SOP` |
| `docs/EA_Playbook.md` | SERVICE | `EA` | Enterprise Administration | `EA` |
| `docs/GL_Playbook_Draft.md` | SERVICE | `GL` | General Ledger | `GL` |
| `docs/POP_Playbook_Draft.md` | SERVICE | `POP` | Purchase Order Processing | `POP` |
| `ER/Principal/docs/ER_School_Playbook_Draft.md` | INDUSTRY | `SCHOOL` | School (The Principal's EduSys) | `EDUCATION_RUNTIME` |

The School sheet is about the School industry; if the Education Runtime owner also wants a sheet about the service itself, that is a second one: kind SERVICE, subject `EDUCATION_RUNTIME`. **Only load a sheet once its owner has said it is ready** (the files are drafts and say what they were written from). A sheet must be plain text with no control characters; tabs and line breaks are fine.

## Steps, in the console (no script)

1. Open the console over the bastion and sign in with your operator token.
2. Go to the **Playbooks** tab and choose **New playbook**.
3. **What it is for**: an industry or a service; then pick the subject from the list. **Name**: as in the table. **The service whose owner is the L2**: as in the table. **Escalate to**: a lane, if one is named (leave blank for now).
4. Paste the whole file into the text box. Press **Create**.
5. To change a sheet later, select it in the list, paste the new text, and press **Save** (editing is in place and is recorded in the access log). The subject cannot be changed.

## Steps, with the script (one command per sheet)

The script reads a sheet file and posts it through the console's own API, so the text cannot be mangled by quoting. **It asks for your operator token at a prompt; the token is never in the file, the command line or a log.**
It must run while the bastion is forwarding the console to your machine (the examples assume `http://localhost:8090`; change `-BaseUrl` if you forward a different port). Run it from a copy of the FiSH repository so the relative paths work.

```powershell
.\Load-PlaybookSheet.ps1 -File docs\Omniview_Operator_Sheet.md -Kind SERVICE -Subject OMNIVIEW -Name 'Omniview (the support console)' -OwningService OMNIVIEW
.\Load-PlaybookSheet.ps1 -File docs\SOP_Playbook_Draft.md       -Kind SERVICE -Subject SOP      -Name 'Sales Order Processing'        -OwningService SOP
.\Load-PlaybookSheet.ps1 -File docs\EA_Playbook.md              -Kind SERVICE -Subject EA       -Name 'Enterprise Administration'     -OwningService EA
.\Load-PlaybookSheet.ps1 -File docs\GL_Playbook_Draft.md        -Kind SERVICE -Subject GL       -Name 'General Ledger'                -OwningService GL
.\Load-PlaybookSheet.ps1 -File docs\POP_Playbook_Draft.md       -Kind SERVICE -Subject POP      -Name 'Purchase Order Processing'     -OwningService POP
.\Load-PlaybookSheet.ps1 -File ER\Principal\docs\ER_School_Playbook_Draft.md -Kind INDUSTRY -Subject SCHOOL -Name "School (The Principal's EduSys)" -OwningService EDUCATION_RUNTIME
```

It prints `Loaded: ...` on success. If a live sheet already exists for that subject it says so and does nothing (edit it in the tab instead). A wrong token prints `unauthorized`.
**Tested 2026-10-07** against a local copy of the service (a new sheet, a second one, a duplicate, a wrong token), and the stored text was identical to the file. It has **not** been run against production, which no one but you can reach.

Save this as `Load-PlaybookSheet.ps1` (it is also kept here so it travels with the instructions):

```powershell
# Loads one playbook operator sheet into Omniview's Playbooks tab, through the console's own API.
# Run it ONLY while the console is reachable over the SSM bastion (it is private). It asks for your operator token; the token is never written to a file or a log.
param(
    [Parameter(Mandatory = $true)][string]$File,                       # the sheet, for example docs\SOP_Playbook_Draft.md
    [Parameter(Mandatory = $true)][ValidateSet('INDUSTRY', 'SERVICE')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$Subject,                     # SCHOOL for an industry; SOP, EA, GL, POP, EDUCATION_RUNTIME, OMNIVIEW for a service
    [Parameter(Mandatory = $true)][string]$Name,                        # at most 80 characters
    [string]$OwningService = '',                                        # the service whose owner is the L2, for example SOP
    [string]$BaseUrl = 'http://localhost:8090'                          # where your bastion forwards the console
)
$ErrorActionPreference = 'Stop'
$secure = Read-Host -AsSecureString 'Operator token'
$token = [System.Net.NetworkCredential]::new('', $secure).Password
$text = Get-Content -Raw -Encoding UTF8 -LiteralPath $File
$payload = [ordered]@{ kind = $Kind; subject = $Subject; name = $Name; body = $text }
if ($OwningService) { $payload.owningService = $OwningService }
$json = $payload | ConvertTo-Json -Depth 3                                 # escapes quotes, line breaks and everything else correctly
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
try {
    $r = Invoke-RestMethod -Method Post -Uri "$BaseUrl/operator/playbooks" -Headers @{ 'X-Operator-Token' = $token } -ContentType 'application/json; charset=utf-8' -Body $bytes
    "Loaded: $($r.kind) $($r.subject) '$($r.name)' ($($r.body.Length) characters)"
} catch {
    $detail = $_.ErrorDetails.Message
    if ($detail -match 'playbook_exists') { "A live sheet for $Kind $Subject already exists. Edit it in the Playbooks tab instead (select it, paste the new text, Save)." }
    else { "Not loaded: $detail" }
}
```

## After loading

Open a ticket (or ask an operator to) whose context names the industry or service, and look at its **Playbook** tab: it should show the sheet. Then say so in the coordination thread so the owner of each sheet knows it is live.
The sheets' own **PLAYBOOK CONTENTS** lists are how a reader finds the rest of each playbook (scope, requirements, use cases, tasks, order): the console shows plain text only and cannot link to the repository.
