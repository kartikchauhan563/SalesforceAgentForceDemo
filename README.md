# Agent Orglicense

The **Org License Service Agent** — an Agentforce Service Agent that answers read-only
questions about this org's Salesforce user-license totals, usage, and remaining capacity,
surfaced to unauthenticated visitors on an Experience Cloud site through Messaging for
In-App and Web (MIAW).

Extracted from the parent `Salesforce` workspace so the agent and everything it depends on
travel as one unit.

## What it does

A guest visitor opens the assistant on the React site and asks about licences. The agent
routes the question, calls an Apex action, and answers from that data only. A visitor who
wants the full breakdown instead follows a suggestion that opens a `/licenses` page, which
reads the same numbers over Apex REST — so the conversational answer and the table can
never disagree.

Both paths read through one Apex service, `OrgLicenseService`, gated by a single custom
permission.

## Architecture

```
Guest visitor
     |
     |  MIAW chat widget (guest, authMode=UnAuth)     |  fetch /services/apexrest/org/licenses
     v                                                v
MessagingChannel  Org_License_Chat            OrgLicenseResource  (@RestResource)
     |  sessionHandlerType = AgentforceServiceAgent          |
     v                                                      |
Bot  Org_License_Service_Agent  (v1)                        |
     |  target: apex://OrgLicenseAgentAction                |
     v                                                      v
OrgLicenseAgentAction  (@InvocableMethod) ------> OrgLicenseService
                                                       |
                             FeatureManagement.checkPermission
                              ('View_Org_License_Summary')
                                                       |
                                    SELECT ... FROM UserLicense WITH SYSTEM_MODE
```

`UserLicense` is a setup object that normally requires *View Setup and Configuration* — a
permission no site user should ever hold. The service reads it in system mode behind an
explicit custom-permission check and returns only an allowlisted summary, which is what
makes it safe to expose to a guest.

## Repository layout

| Path | What it is |
|------|-----------|
| `force-app/` | Deployable Salesforce metadata. This is the whole agent |
| `manifest/package.xml` | Generated from `force-app`, API 67.0 |
| `archive/` | The superseded employee-agent predecessor. Not deployed |

This repository holds the Salesforce side only. The React front end that renders the
assistant and the licence page, the runbooks describing how to stand the whole thing up,
and the Playwright verification scripts all live in the parent `Salesforce` workspace.

### Metadata included

| Type | Member |
|------|--------|
| `AiAuthoringBundle` | `Org_License_Service_Agent` — the Agent Script definition |
| `Bot` / `BotVersion` | `Org_License_Service_Agent`, `v1` — the compiled runtime agent |
| `ApexClass` | `OrgLicenseService`, `OrgLicenseAgentAction`, `OrgLicenseResource`, plus `OrgLicenseTestData` and two test classes |
| `CustomPermission` | `View_Org_License_Summary` |
| `PermissionSet` | `Org_License_Agent_User`, `externalReact_GuestApexAccess`, `externalReact_MemberApexAccess` |
| `MessagingChannel` | `Org_License_Chat` — guest MIAW channel, `authMode=UnAuth` |
| `EmbeddedServiceConfig` | `Org_License_Chat_Web` |
| `Queue` / `QueueRoutingConfig` | `Org_License_Chat_Fallback`, `Org_License_Chat_Routing` — Omni-Channel fallback |
| `CorsWhitelistOrigin` | The Experience Cloud site origin |

## Prerequisites

- Salesforce CLI (`sf`), API 67.0 or later
- Agentforce enabled, with **Agentforce Service Agents** turned on
- An Experience Cloud site to host the widget, with guest access
- A dedicated agent user holding `AgentforceServiceAgentUserPsl` and
  `AgentforceServiceAgentUserPsg`. The bundle currently names
  `org.license.agent.00dbm00000sie4meac@example.com` in its `default_agent_user` —
  **change this to a user in your own org before deploying**

## Deploying

```bash
sf project deploy start --manifest manifest/package.xml --target-org <alias>
sf apex run test --class-names OrgLicenseServiceTest --class-names OrgLicenseResourceTest \
                 --class-names OrgLicenseAgentActionTest --result-format human --target-org <alias>
sf agent activate --api-name Org_License_Service_Agent --target-org <alias>
```

Order matters: the custom permission and Apex must exist before the permission sets that
reference them, and the agent must exist before the messaging channel that names it in
`sessionHandlerAsa`.

**The Embedded Service Deployment cannot be created by the Metadata API.** For a Web
deployment it has to be created and published through the Connect API or Setup UI. The
`EmbeddedServiceConfig` here updates an existing deployment; it will not create one. The
runbook in the parent workspace has the exact Connect API calls.

## `archive/`

`Org_License_Assistant` was the first attempt: an `AgentforceEmployeeAgent` embedded with
the Agentforce Conversation Client. It could not work for guest or Experience Cloud users —
the SDK cannot authenticate in a deployed bundle, and the Agentforce (Default) permission
set licence is internal-only. It is kept for history and is deliberately outside
`force-app/` so it is never deployed.

## Security notes

- Every read is gated on the `View_Org_License_Summary` custom permission
- Only an allowlisted set of licence names is ever returned
- No DML anywhere; the agent's instructions forbid it and the Apex has no write path
- The agent refuses anything outside org licensing, and will not disclose its own prompts

Salesforce reports `UsedLicenses` as `0` for login-based Experience Cloud licences, so that
column can understate real usage. The page states this caveat inline.
