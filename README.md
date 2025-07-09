| id | title | contributors |  status |  type |  category |  created at |  
|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| RETC-1     | Smart Contract Standard      | Artem Kushneryk @kyshneryk, Margarita Maksimova @vqrwp | Draft     | Standards Track     | Tokenization     | 2025-07-08     |

# Summary

Defines a compliance-focused tokenization standard for real estate assets, designed to support secure, transparent, and regulation-aligned issuance and transfer of real estate-backed tokens on EVM-compatible blockchains. The goal is to enable secure, transparent, and legally compliant tokenized real estate offerings globally.

# Abstract | *updating*

This standard aligns with:
* MiCA Regulation (EU) 2023/1114 (Art. 94),
* Dubai VARA Compliance and Risk Management Rulebook (Part III – Anti-Money Laundering and Combating the Financing of Terrorism, section H),
* FATF guidance,
* IOSCO recommendations.

# Motivation | *updating*

# Requirements | *updating*

Moving real estate assets and their lifecycle events onto EVM-compatible blockchain networks requires strict compliance, strong access controls, and robust operational safeguards to meet global regulatory standards.

The following requirements have been compiled based on applicable MiCA, VARA, and FATF guidelines, and internal risk assessments:

* MUST implement Role-Based Access Control (RBAC) to segregate privileged governance actions (ROLE_ADMIN) from routine transfer permissions (ROLE_TRANSFER). This supports organizational transparency and reduces insider abuse risks.
* MUST allow authorized administrators (ROLE_ADMIN) to freeze and unfreeze individual accounts to support sanctions compliance, fraud mitigation, and investor protection.
* MUST support forced transfers (forceTransfer) to enable asset reallocation under court orders or legal mandates without user consent.
* MUST enable controlled token burning (burnFrom) by ROLE_ADMIN, ensuring token supply remains consistent with underlying real estate assets.
* MUST provide an emergency pause (circuit breaker) mechanism to halt all token transfers during operational or security crises.
* MUST enforce a transfer guard in the core balance update logic (e.g., _update() function) to ensure freeze checks are performed on every transfer, mint, or burn event.
* SHOULD maintain audit logs of all administrative actions (freezes, forced transfers, burns, pauses) for regulatory traceability.

# Rationale | *updating*

Dubai VARA Compliance and Risk Management Rulebook (Part III – Anti-Money Laundering and Combating the Financing of Terrorism, section H):
>Freezing.  
VASPs are required to —  
a. take immediate action to freeze any assets, including Virtual Assets and/or money, associated with individuals or entities identified as designated Entities under the UNSC sanctions frameworks or Federal AML-CFT Laws;  
b. and ensure that no withdrawals, transfers, or use of the frozen assets occur during the freezing period.  
VASPs must establish and enforce internal policies and procedures to —  
a. immediately freeze any assets, including Virtual Assets and/or money, upon detecting a match with a designated Entity;  
b. and maintain records of all freezing actions and associated transactions for a minimum of eight (8) years.

MiCA Regulation (EU) 2023/1114 (Art. 94):
>In order to fulfil their duties under Title VI, competent authorities shall have, in accordance with national law, at least the following supervisory and investigatory powers in addition to the powers referred to in paragraph 1:  
[...]  
(f)  
to request the freezing or sequestration of assets, or both;

# Specification | *updating*

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
Description: The contract overrides the low■level balance update hook to enforce freeze checks on every transfer, mint and burn.

# References | *updating*
* [Dubai VARA Compliance and Risk Management Rulebook](https://rulebooks.vara.ae/rulebook/compliance-and-risk-management-rulebook) (Part III – Anti-Money Laundering and Combating the Financing of Terrorism, section H),
* [MiCA Regulation (EU) 2023/1114](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32023R1114) (Art. 94)
