| id | title | contributors |  status |  type |  category |  created at |  
|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| RETC-1     | Smart Contract Standard      | Artem Kushneryk @kyshneryk, Margarita Maksimova @vqrwp | Draft     | Standards Track     | Tokenization     | 2025-07-08     |

## Simple Summary

Defines a compliance-focused tokenization standard for real estate assets, designed to support secure, transparent, and regulation-aligned issuance and transfer of real estate-backed tokens on EVM-compatible blockchains. The goal is to enable secure, transparent, and legally compliant tokenized real estate offerings globally.

## Abstract | *needs approval*

This standard extends the ERC-20 interface to introduce compliance-focused mechanisms required for real estate-backed tokenization. 

It builds on ERC-20 for basic token functionality and integrates concepts from ERC-1400 (security token framework), ERC-1594 (transfer restrictions and validation), ERC-1644 (controller operations for forced transfers), and ERC-777 (advanced hooks), ensuring compatibility with EVM-compatible blockchains while enabling strong compliance and governance controls.

This standard aligns with global regulatory frameworks to support legally compliant real estate tokenization. It references:
* MiCA Regulation (EU) 2023/1114,
* Dubai VARA Compliance and Risk Management Rulebook,
* Dubai VARA Virtual Assets Issuance Rulebook,
* FATF (2021), Updated Guidance for a Risk-Based Approach to Virtual Assets and Virtual Asset Service Providers,
* IOSCO recommendations.

## Motivation | *needs approval*

Facilitate the compliant issuance, management, and transfer of real estate-backed tokens on EVM-compatible blockchains by defining standardized mechanisms that address real-world regulatory and operational requirements.

This standard aims to support property-backed tokenization with strong governance controls through role-based access, enable legal enforcement via forced transfers, provide consumer protection through account freezing and emergency pause capabilities, and ensure supply alignment via controlled token burning. These mechanisms are critical to align on-chain asset management with traditional real estate legal frameworks and to meet anti-money laundering (AML), market integrity, and investor protection guidelines outlined by MiCA, VARA, FATF, and IOSCO.

## Requirements | *needs approval*

Moving real estate assets and their lifecycle events onto EVM-compatible blockchain networks requires strict compliance, strong access controls, and robust operational safeguards to meet global regulatory standards.

The following requirements have been compiled based on MiCA, VARA, FATF guidelines, and internal risk assessments:

* MUST implement Role-Based Access Control (RBAC) to segregate privileged governance actions, operational actions, and emergency interventions across distinct roles (e.g., ROLE_ADMIN, ROLE_TRANSFER, ROLE_PAUSER, ROLE_MINTER/BURNER). This minimizes insider risk, enforces least-privilege principles, and supports organizational transparency.
* MUST allow authorized administrators (ROLE_ADMIN) to freeze and unfreeze individual accounts to support sanctions compliance, fraud mitigation, and investor protection mandates.
* MUST support forced transfers (`forceTransfer`) executed by ROLE_TRANSFER to enable asset reallocation under court orders, legal disputes, or exceptional regulatory scenarios without user consent.
* MUST enable controlled token burning (`burnFrom`) by ROLE_MINTER/BURNER to ensure the on-chain token supply accurately reflects the status of off-chain real estate assets.
* MUST provide an emergency pause (circuit breaker) mechanism, managed by ROLE_PAUSER, to halt all token transfers during operational crises, cyberattacks, or compliance emergencies.
* MUST enforce transfer guards within core balance update logic (e.g., `_update()` function) to ensure freeze checks are applied consistently on every transfer, mint, or burn event.
* SHOULD maintain detailed audit logs of all privileged administrative actions (freezes, forced transfers, burns, pauses) to ensure regulatory traceability and facilitate post-incident reviews.

## Rationale | *updating*

### ERC-20: Fungibility and Base Compatibility
This standard builds on ERC-20 to maintain broad compatibility with existing wallets, exchanges, and DeFi protocols. ERC-20 provides basic fungible token functionality, which is necessary for real estate-backed token fractionalization and liquidity. Retaining ERC-20 compatibility ensures ease of integration and simplifies adoption by infrastructure providers.

### ERC-1400: Security Token Framework
The design extends concepts from ERC-1400, particularly around compliance-focused token behavior and governance. By incorporating features like forced transfers and advanced access controls, this standard addresses legal enforceability and regulatory requirements similar to those covered by ERC-1400, while simplifying some aspects (e.g., partitions) to better fit real estate tokenization use cases.

### ERC-1594: Transfer Restrictions and Validation
The requirement to perform pre-transfer validation checks (similar to canTransfer in ERC-1594) is implemented through role-based freezing and transfer guard mechanisms. These features ensure that transfers comply with jurisdictional restrictions and prevent transfers from frozen or sanctioned addresses, supporting regulatory requirements from MiCA, VARA, and FATF.

### ERC-1644: Controller Operations (Forced Transfers)
The inclusion of forced transfers (forceTransfer) is directly inspired by ERC-1644. This functionality is critical for enabling administrative or court-ordered interventions, allowing tokens to be moved without holder approval in specific legal or compliance scenarios.

### ERC-777: Advanced Hooks and Transfer Control
By referencing ERC-777, this standard emphasizes advanced control via low-level hooks (e.g., _update()), enabling deeper checks such as address freezing at the core balance update level. This enhances security and aligns with requirements for real-time anomaly detection and prompt remedial action (e.g., as described in MiCA Art. 68 and VARA guidelines).

### Compliance and Governance Justification
Role-based access control (using distinct roles such as ROLE_ADMIN, ROLE_TRANSFER, ROLE_PAUSER, and ROLE_MINTER/BURNER) is introduced to segregate governance functions, routine operational actions, emergency interventions, and supply management. This design reduces insider risk, enforces least-privilege principles, and aligns with organizational transparency and risk management guidelines outlined in MiCA and VARA compliance frameworks.

Controlled token burning (burnFrom) ensures the on-chain token supply accurately reflects off-chain real estate asset status, supporting investor trust, supply integrity, and auditability.

### Dubai VARA Virtual Assets Issuance Rulebook  
(Part IV – Supervision, Examination and Enforcement, section 2)
>VARA may also impose additional conditions and/or take further enforcement action within its power including, but not limited to, imposing fines or penalties. 

#### Dubai VARA Compliance and Risk Management Rulebook  
(Part III – Anti-Money Laundering and Combating the Financing of Terrorism, section H):
>Freezing.  
VASPs are required to —  
a. take immediate action to freeze any assets, including Virtual Assets and/or money, associated with individuals or entities identified as designated Entities under the UNSC sanctions frameworks or Federal AML-CFT Laws;  
b. and ensure that no withdrawals, transfers, or use of the frozen assets occur during the freezing period.  
VASPs must establish and enforce internal policies and procedures to —  
a. immediately freeze any assets, including Virtual Assets and/or money, upon detecting a match with a designated Entity;  
b. and maintain records of all freezing actions and associated transactions for a minimum of eight (8) years.

#### MiCA Regulation (EU) 2023/1114  
(Clause 51):  
>Issuers of asset-referenced tokens should have robust governance arrangements, including a clear organisational structure with well-defined, transparent and consistent lines of responsibility and effective processes to identify, manage, monitor and report the risks to which they are or to which they might be exposed.  

(Article 94):  
>In order to fulfil their duties under Title VI, competent authorities shall have, in accordance with national law, at least the following supervisory and investigatory powers in addition to the powers referred to in paragraph 1:  
[...]  
(f)  
to request the freezing or sequestration of assets, or both;

## Specification | *updating*

*Identify additional constraints*

1. Role-Based Access Control (ROLE_ADMIN & ROLE_TRANSFER)
Description: Segregates privileged governance actions (ROLE_ADMIN) from routine transfer permissions (ROLE_TRANSFER) using OpenZeppelin AccessControl.

2. Account Freezing & Unfreezing
Description: ROLE_ADMIN can freeze individual addresses; frozen accounts cannot send or receive tokens until unfrozen.

3. Forced Transfers (forceTransfer)
Description: ROLE_TRANSFER may, under exceptional circumstances, move tokens between user accounts without prior user approval—typically to honour court orders or correct errant settlements.

4. Controlled Token Burning (burnFrom)
Description: ROLE_ADMIN can irreversibly destroy tokens held by any account, ensuring supply stays aligned with underlying real estate assets.

5. Emergency Pause (Circuit Breaker)
Description: Inherited ERC20Pausable lets ROLE_ADMIN halt all transfers during operational crises or cyber attacks.

6. Transfer Guard in _update()
Description: The contract overrides the low level balance update hook to enforce freeze checks on every transfer, mint and burn.

## Security Considerations | *needs approval*

This standard introduces multiple privileged roles (e.g., ROLE_ADMIN, ROLE_TRANSFER, ROLE_PAUSER, ROLE_MINTER/BURNER). Strong off-chain key management practices are critical to ensure these roles cannot be abused. Suggested measures include:

* Use of cold storage and hardware wallets (e.g., for ROLE_ADMIN and DAO multisig signers).
* Multisignature setups (e.g., 3-of-5 or 2-of-X) to distribute control and mitigate insider risk.
* Firewall-protected automated signers and rate limiting for operational roles (e.g., ROLE_TRANSFER).
* Mandatory procedural checklists and board-level approvals for minting and burning operations.
* Regular social engineering drills and off-chain recovery planning.
* Adherence to these security practices aligns with regulatory expectations from MiCA, VARA, and FATF, and protects against operational and governance-level vulnerabilities.

## References | *updating*
* [Dubai VARA Compliance and Risk Management Rulebook](https://rulebooks.vara.ae/rulebook/compliance-and-risk-management-rulebook),
* [MiCA Regulation (EU) 2023/1114](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32023R1114),
* [Dubai VARA Virtual Assets Issuance Rulebook](https://rulebooks.vara.ae/rulebook/virtual-asset-issuance-rulebook),
* [FATF (2021), Updated Guidance for a Risk-Based Approach to Virtual Assets and Virtual Asset Service Providers](https://www.fatf-gafi.org/en/publications/Fatfrecommendations/Guidance-rba-virtual-assets-2021.html)