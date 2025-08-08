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



## Specification 



## Security Considerations 



## References 
* [Dubai VARA Compliance and Risk Management Rulebook](https://rulebooks.vara.ae/rulebook/compliance-and-risk-management-rulebook),
* [MiCA Regulation (EU) 2023/1114](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32023R1114),
* [Dubai VARA Virtual Assets Issuance Rulebook](https://rulebooks.vara.ae/rulebook/virtual-asset-issuance-rulebook),
* [FATF (2021), Updated Guidance for a Risk-Based Approach to Virtual Assets and Virtual Asset Service Providers](https://www.fatf-gafi.org/en/publications/Fatfrecommendations/Guidance-rba-virtual-assets-2021.html),
* [IOSCO Policy Recommendations for Crypto and Digital Asset Markets](https://www.iosco.org/library/pubdocs/pdf/IOSCOPD747.pdf),
* [EU Market Abuse Regulation 596/2014](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32014R0596)