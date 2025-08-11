// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ───────────────────────────────────────────────────────────────────────────
   RealEstateToken — permissioned ERC-20 for tokenised real-estate shares
   Built on OpenZeppelin v5.3.0

      Roles
        • ROLE_ADMIN     – governs every other role (alias 0x00)
        • ROLE_TRANSFER  – settlement & override transfers
        • ROLE_MINTER    – mint new supply
        • ROLE_BURNER    – burn via allowance
        • ROLE_PAUSER    – emergency pause

      Core features
        • Dual transfer modes
              – Role-gated  (default)
              – Whitelist   (toggleable)
        • forceTransfer(from, to, amount, data)
              – operator override path
              – `data` = arbitrary evidence bytes (court order, JSON, PDF hash…)
              – emits ForcedTransfer event
        • Pause, freeze, partial balance-lock, mint, burn, EIP-2612 permit
   ───────────────────────────────────────────────────────────────────────── */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/governance/utils/Votes.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract RealEstateToken is
    ERC20,
    ERC20Permit,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Votes,
    AccessControlEnumerable
{
    /* ─── Role IDs ───────────────────────────────── */
    bytes32 public constant ROLE_ADMIN     = 0x00;
    bytes32 public constant ROLE_TRANSFER  = keccak256("ROLE_TRANSFER");
    bytes32 public constant ROLE_MINTER    = keccak256("ROLE_MINTER");
    bytes32 public constant ROLE_BURNER    = keccak256("ROLE_BURNER");
    bytes32 public constant ROLE_PAUSER    = keccak256("ROLE_PAUSER");

    /* ─── Compliance state ───────────────────────── */
    mapping(address => bool)    private _frozen;
    mapping(address => uint256) private _locked;
    mapping(address => bool)    private _kyc;
    bool public whitelistEnabled;                       // false ⇒ role-gated

    /* ─── Events ─────────────────────────────────── */
    event AccountFrozen      (address indexed account);
    event AccountUnfrozen    (address indexed account);
    event BalanceLocked      (address indexed account, uint256 amount);
    event BalanceUnlocked    (address indexed account, uint256 amount);
    event Whitelisted        (address indexed account, bool status);
    event WhitelistModeChanged(bool enabled);
    event ForcedTransfer(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes   data
    );

    /* ─── Constructor ───────────────────────────── */
    constructor(
        string  memory name_,
        string  memory symbol_,
        uint256 initialSupply_,
        address admin_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        _grantRole(ROLE_ADMIN,    admin_);
        _grantRole(ROLE_MINTER,   admin_);
        _grantRole(ROLE_BURNER,   admin_);
        _grantRole(ROLE_TRANSFER, admin_);
        _grantRole(ROLE_PAUSER,   admin_);

        _mint(admin_, initialSupply_);
        whitelistEnabled = false;                       // strict mode default
    }

    /* ─── Zero-decimals token ───────────────────── */
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /* ─── Whitelist controls ────────────────────── */
    function setWhitelistMode(bool enabled)
        external onlyRole(ROLE_ADMIN)
    { whitelistEnabled = enabled; emit WhitelistModeChanged(enabled); }

    function setWhitelist(address account, bool status)
        external onlyRole(ROLE_ADMIN)
    { _kyc[account] = status; emit Whitelisted(account, status); }

    /* ─── Pause / freeze / lock APIs ────────────── */
    function pause()   external onlyRole(ROLE_PAUSER) { _pause(); }
    function unpause() external onlyRole(ROLE_PAUSER) { _unpause(); }

    function freeze(address account)
        external onlyRole(ROLE_ADMIN)
    { _frozen[account] = true;  emit AccountFrozen(account); }

    function unfreeze(address account)
        external onlyRole(ROLE_ADMIN)
    { _frozen[account] = false; emit AccountUnfrozen(account); }

    function lockBalance(address account, uint256 amount)
        external onlyRole(ROLE_ADMIN)
    {
        require(
            amount > 0 &&
            amount <= balanceOf(account) - _locked[account],
            "lock exceeds unlocked"
        );
        _locked[account] += amount;
        emit BalanceLocked(account, amount);
    }

    function unlockBalance(address account, uint256 amount)
        external onlyRole(ROLE_ADMIN)
    {
        require(amount > 0 && amount <= _locked[account], "unlock too big");
        _locked[account] -= amount;
        emit BalanceUnlocked(account, amount);
    }

    /* ─── Mint / burn ───────────────────────────── */
    function mint(address to, uint256 amount)
        external onlyRole(ROLE_MINTER)
    { _mint(to, amount); }

    function burnFrom(address account, uint256 amount)
        public override onlyRole(ROLE_BURNER)
    {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    /* ─── forceTransfer with evidence bytes ─────── */
    function forceTransfer(
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    )
        external
        onlyRole(ROLE_TRANSFER)
    {
        require(from != address(0) && to != address(0), "zero address");
        require(data.length != 0,                       "empty data");

        _transfer(from, to, amount);                    // triggers _update
        emit ForcedTransfer(_msgSender(), from, to, amount, data);
    }

    /* ─── Delegation disabled (votes == balance) ── */
    function delegate(address delegatee)
        public
        override(Votes)
    {
        require(delegatee == _msgSender(), "delegation disabled");
        super.delegate(delegatee);  // self-delegate if first call (creates checkpoint)
    }

    function delegateBySig(
        address, uint256, uint256,
        uint8, bytes32, bytes32
    )
        public
        pure
        override(Votes)
    { revert("delegation disabled"); }

    /* ─── Compliance hook & auto-self-delegate ──── */
    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        /* Ensure votes follow balances from first token movement */
        if (from != address(0) && delegates(from) == address(0)) {
            _delegate(from, from);
        }
        if (to   != address(0) && delegates(to)   == address(0)) {
            _delegate(to,   to);
        }

        /* Compliance checks */
        if (from != address(0) && to != address(0)) {
            require(!_frozen[from] && !_frozen[to],            "frozen");
            require(amount <= balanceOf(from) - _locked[from], "lock exceeds unlocked");

            if (whitelistEnabled) {
                if (!hasRole(ROLE_TRANSFER, _msgSender()))
                    require(_kyc[from] && _kyc[to], "not whitelisted");
            } else {
                require(hasRole(ROLE_TRANSFER, _msgSender()), "no ROLE_TRANSFER");
            }
        }
        super._update(from, to, amount);              // pause & votes bookkeeping
    }

    /* ─── Resolve duplicate nonces() ────────────── */
    function nonces(address owner)
        public view
        override(ERC20Permit, Nonces)
        returns (uint256)
    { return super.nonces(owner); }

    /* ─── ERC-165 support ───────────────────────── */
    function supportsInterface(bytes4 id)
        public view
        override(AccessControlEnumerable)
        returns (bool)
    { return super.supportsInterface(id); }

    /* ─── Helper views ──────────────────────────── */
    function lockedBalanceOf(address a) external view returns (uint256) { return _locked[a]; }
    function isFrozen       (address a) external view returns (bool)    { return _frozen[a]; }
    function isWhitelisted  (address a) external view returns (bool)    { return _kyc[a]; }
}
