| id | title | contributors |  status |  type |  category |  created at |  
|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| RETC-2     | Smart Contract Standard      | Artem Kushneryk @kyshneryk, Margarita Maksimova @vqrwp | Draft     | Standards Track     | Tokenization     | 2025-07-25     |

## Simple Summary

This standard defines a compliance-oriented standard for on-chain distribution of cash flows (e.g., rents, dividends, redemptions) to holders of real-estate tokens on EVM networks.
It specifies interfaces and events for declaring payout cycles, publishing entitlement commitments (snapshot/Merkle root), enabling self-service claims and operator batch payouts, and providing role-gated controls (pause, rescue/sweep, sanctions screening hooks) with a full audit trail.
This standard is interoperable with ERC-20 and is designed to meet operational expectations under MiCA/VARA/FATF while remaining implementation-agnostic.

## Abstract 

This standard specifies a compliance-oriented standard for on-chain distribution of cash flows (e.g., rents, dividends, redemption proceeds) to holders of real-estate tokens on EVM-compatible networks. It defines a minimal, interoperable interface for declaring payout cycles, publishing entitlement commitments (snapshot or Merkle root), enabling self-service claims and operator batch payouts, and exposing a verifiable audit trail of events.

The standard borrows proven ideas from ERC-1594 (pre-transfer checks), ERC-1644 (operator/controlled actions), and common Merkle-distribution patterns to support role-based access, pausable execution, rescue/sweep of stale funds, and sanctions-screening hooks—while preserving broad wallet and infrastructure compatibility.

This standard is aligned with prevailing regulatory expectations for operational resilience, investor protection, AML/sanctions compliance, and auditability. It is designed to help issuers and service providers meet supervisory requirements across major jurisdictions, including:

* MiCA Regulation (EU) 2023/1114
* Dubai VARA Compliance & Risk Management Rulebook
* Dubai VARA Virtual Assets Issuance Rulebook
* FATF (2021) Updated Guidance for a Risk-Based Approach to VAs and VASPs
* IOSCO Policy Recommendations for Crypto and Digital Asset Markets.

## Motivation 

Accelerate compliant on-chain servicing of real-estate cash flows by standardizing interfaces and events for payout cycles, entitlement commitments, and holder claims/operator batches across EVM.

Taken together, this strandard defines lifecycle semantics (declare → commit → open → claim/batch → close → sweep), verifiable entitlements (snapshot/Merkle with double-claim protection), role-gated & pausable execution with sanctions/freeze hooks (via RETC-1), deterministic error signaling, and an auditable event trail.

## Requirements 

Moving payout servicing for real-estate tokens on-chain requires clear lifecycle semantics, least-privilege controls, and robust auditability. The following requirements are derived from regulatory expectations (MiCA/VARA/FATF/IOSCO) and internal risk assessments:
* MUST standardize a payout lifecycle with forward-only states: Declared → Committed → Open → Closed/Finalized (unique cycle ID, timestamps for record/open/close).
* MUST publish an immutable entitlement commitment per cycle (e.g., snapshot/Merkle root). Once Open, the commitment MUST NOT change (revision only via new cycle/version, with events).
* MUST provide double-claim protection per cycle/beneficiary (e.g., bitmaps or claimed mapping keyed by leaf/index).
* MUST support two execution modes: holder pull claims and operator batch payouts, with idempotent processing.
* MUST be role-gated with least privilege (e.g., ROLE_PAYOUT_ADMIN for declare/commit/close, ROLE_PAYOUT_OPERATOR for execute/claims settlement, ROLE_PAUSER for pause). MAY reuse RETC-1 roles where appropriate.
* MUST expose a pause (circuit breaker) that halts claim/batch actions; unpaused state restores normal operation.
* MUST integrate sanctions/freeze hooks: claims and batches MUST respect RETC-1 freeze/whitelist (or equivalent) and revert for frozen/ineligible addresses.
* MUST emit deterministic events for audit/reconciliation: CycleDeclared, EntitlementCommitted, CycleOpened, ClaimPaid, BatchPaid, CycleClosed/Finalized, FundsSwept/Rescued, plus error codes where applicable.
* MUST provide views for off-chain ops: cycle status, commitment metadata, claimable amount by beneficiary, and claimed status.
* MUST support ERC-20 payout assets (address/decimals explicit). MAY support native token payouts.
* MUST ensure reentrancy safety around external token transfers (e.g., non-reentrant guards) and revert or cleanly report partial failures.
* MUST define deterministic remainder handling (rounding, dust) to avoid silent value drift.
* SHOULD include sweep/rescue for stale/unclaimed funds after close to a designated escrow/account with events.
* SHOULD bound gas for batch operations (size limits or chunking) and avoid all-or-nothing failure semantics where practical.
* SHOULD include per-cycle metadata URI (e.g., statement/report hash) to aid audits.
* SHOULD maintain comprehensive logs of privileged actions (declare/commit/open/close/pause/sweep) for post-incident review.

## Rationale 

### ERC-20: base fungibility & interoperability
RETC-2 keeps payouts compatible with the ERC-20 ecosystem (wallets, custodians, bookkeeping) by indexing claims and distributions against standard fungible balances and by allowing ERC-20 payout assets (e.g., stablecoins). ERC-20 is the canonical token API for transfers/allowances.

### ERC-1594: pre-transfer validation mindset for compliance checks
RETC-2 adopts ERC-1594’s philosophy that movements tied to regulated instruments should be validated before execution. We apply that to payouts: claims are gated by on-chain checks (eligibility, freeze status, windowing), mirroring ERC-1594’s canTransfer / transfer-restriction approach for security tokens. This ensures distributions respect offering restrictions and operational rules. 
GitHub

ERC-1644 — controller/override operations under legal compulsion
RETC-2 allows a designated operator to reallocate or cancel a specific payout in exceptional cases (e.g., court order, operational error), aligning with ERC-1644’s “controller transfer” concept and its transparency expectation (distinct events for forced actions). This provides a lawful remediation path without breaking auditability. 
GitHub
+1

ERC-777 — operator model & hooks as control inspiration
While RETC-2 does not require ERC-777, it borrows its operator model as design guidance for separating who schedules/executes distributions from asset holders, and for safe, explicit callback points. ERC-777 defines operators and send/receive hooks to give holders more control over token flows — a useful mental model for structured payout lifecycles. 
Ethereum Improvement Proposals

MiCA Regulation (EU) 2023/1114 — operational resilience & records
Article 68(7) requires CASPs to ensure continuity and regularity of services and to employ resilient and secure ICT systems (also tying into DORA). RETC-2 therefore includes administrative pause/resume, time-boxed windows, and replay-safe flows to support incident response and orderly resumption. Article 68(9) requires keeping records of services, orders and transactions for five years (extendable to seven); RETC-2 emits granular events for every administrative and user action to facilitate those records. 
EUR-Lex

MiCA — safekeeping & segregation of client assets
Article 70 obliges CASPs that hold client assets or access keys to safeguard ownership rights, prevent own-account use, and hold client funds in separately identifiable accounts. RETC-2’s payout-escrow and reconciliation signals are designed so implementers can evidence segregation and prevent co-mingling during distribution cycles. 
EUR-Lex

IOSCO (2023) Policy Recommendations for Crypto & Digital Asset Markets — custody, reconciliation, ops risk
IOSCO’s final report sets outcomes for CASPs, including custody & client asset protection and operational/technological risk. In particular, Recommendation 15 calls for regular and frequent client-asset reconciliation, including reconciling on-chain and off-chain records, with independent assurance. RETC-2 standardizes per-cycle accounting events (scheduled amounts, claimed, unclaimed, swept) so implementers can meet these reconciliation and assurance expectations. 
IOSCO

FATF (2021) Updated Guidance for VAs & VASPs — Travel Rule & scope of obligations
FATF’s 2021 update clarifies that obligations extend to VASPs that transfer or safekeep/administer VAs and gives additional guidance on implementing the Travel Rule (originator/beneficiary info). RETC-2’s payout lifecycle anticipates Travel-Rule workflows by supporting gated claims, per-recipient eligibility, and data-collection hand-offs to compliance systems before value leaves the payout contract. 
FATF

Dubai VARA — Travel Rule (thresholds & counterparty due diligence)
VARA’s Compliance & Risk Management Rulebook, Part III.G requires VASPs to obtain/hold originator and beneficiary data before initiating VA transfers over AED 3,500, and to perform risk-based due diligence on counterparty VASPs (including unhosted-wallet handling). RETC-2’s staged “schedule → (optional) attest/KYC → claim/settle” flow gives operators the insertion points to enforce those controls and to block settlement when Travel-Rule prerequisites aren’t met. 
VARA Rulebook

Dubai VARA — targeted financial sanctions & freezing
VARA’s Part III.H mandates immediate freezing of assets linked to designated persons and record-keeping of freezing actions for 8 years. RETC-2 exposes account-level freeze guards and emits explicit admin/audit events so implementers can halt claims, preserve evidence, and demonstrate traceability during sanctions responses. 
VARA Rulebook

Dubai VARA — Client Virtual Assets Rules (daily reconciliation)
VARA’s Part V.D requires daily reconciliation of client VA ledgers, with notification to VARA on material discrepancies. RETC-2’s distribution-level accounting signals (total scheduled, claimed per address, remaining, sweep of unclaimed) are engineered to slot into those daily reconciliation runs and exception reports. 
VARA Rulebook

## Specification 



## Security Considerations 



## References 
* [Dubai VARA Compliance and Risk Management Rulebook](https://rulebooks.vara.ae/rulebook/compliance-and-risk-management-rulebook),
* [MiCA Regulation (EU) 2023/1114](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32023R1114),
* [Dubai VARA Virtual Assets Issuance Rulebook](https://rulebooks.vara.ae/rulebook/virtual-asset-issuance-rulebook),
* [FATF (2021), Updated Guidance for a Risk-Based Approach to Virtual Assets and Virtual Asset Service Providers](https://www.fatf-gafi.org/en/publications/Fatfrecommendations/Guidance-rba-virtual-assets-2021.html),
* [IOSCO Policy Recommendations for Crypto and Digital Asset Markets](https://www.iosco.org/library/pubdocs/pdf/IOSCOPD747.pdf),
* [EU Market Abuse Regulation 596/2014](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32014R0596)