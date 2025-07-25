// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ─────────────────────────────────────────────────────────────────────────────
   PayoutDistributor — permissioned contract to record & distribute ERC-20
                       revenues (“payouts”) to holders of a snapshot-enabled
                       shares token.

      Roles
        • ROLE_ADMIN    – governs every other role (alias 0x00)
        • ROLE_DEPOSIT  – authorised to deposit funds & create payouts
        • ROLE_PAUSER   – emergency pause / unpause
   ───────────────────────────────────────────────────────────────────────────── */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

/* ─── Minimal interface for snapshot-enabled token ─────────────────────────── */
interface IERC20Snapshot {
    function snapshot() external returns (uint256);
    function totalSupplyAt(uint256 id) external view returns (uint256);
    function balanceOfAt(address account, uint256 id) external view returns (uint256);
}

/* ─── PayoutDistributor ────────────────────────────────────────────────────── */
contract PayoutDistributor is
    AccessControlEnumerable,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    /* ─── Role IDs ───────────────────────────────────── */

    bytes32 public constant ROLE_ADMIN   = 0x00;  // AccessControl default admin
    bytes32 public constant ROLE_DEPOSIT = keccak256("ROLE_DEPOSIT");
    bytes32 public constant ROLE_PAUSER  = keccak256("ROLE_PAUSER");

    /* ─── Data structures ──────────────────────────── */

    struct Payout {
        address token;      // payout currency
        uint256 amount;     // total deposited
        uint256 snapshotId; // frozen supply / balances
        uint256 timestamp;  // block.timestamp
    }

    IERC20Snapshot public immutable sharesToken;
    Payout[]           private _payouts;

    mapping(uint256 => mapping(address => bool)) private _claimed;      // payoutId ⇒ holder ⇒ done?
    mapping(address => uint256)                  private _nextPayoutId; // first unclaimed for holder

    /* ─── Events ───────────────────────────────────── */

    event PayoutRecorded(
        uint256 indexed id,
        address indexed token,
        uint256 amount,
        uint256 snapshotId,
        uint256 timestamp
    );

    event PayoutClaimed(
        uint256 indexed id,
        address indexed holder,
        address indexed token,
        uint256 amount
    );

    /* ─── Constructor ───────────────────────────────── */

    constructor(IERC20Snapshot _sharesToken, address admin_) {
        require(address(_sharesToken) != address(0), "shares token zero");
        sharesToken = _sharesToken;

        _grantRole(ROLE_ADMIN,   admin_);
        _grantRole(ROLE_DEPOSIT, admin_);
        _grantRole(ROLE_PAUSER,  admin_);
    }

    /* ─── Deposit & record ─────────────────────────── */

    function recordPayout(address token, uint256 amount)
        external
        onlyRole(ROLE_DEPOSIT)
        whenNotPaused
    {
        require(token != address(0), "token zero");
        require(amount > 0, "zero amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 snapId = sharesToken.snapshot();

        _payouts.push(Payout({
            token:      token,
            amount:     amount,
            snapshotId: snapId,
            timestamp:  block.timestamp
        }));

        emit PayoutRecorded(_payouts.length - 1, token, amount, snapId, block.timestamp);
    }

    /* ─── Claim APIs ───────────────────────────────── */

    function claimAll()
        external
        nonReentrant
        whenNotPaused
    {
        uint256 i   = _nextPayoutId[msg.sender];
        uint256 end = _payouts.length;
        require(i < end, "nothing to claim");

        for (; i < end; ++i) _claimSingle(i, msg.sender);
        _nextPayoutId[msg.sender] = end;
    }

    function _claimSingle(uint256 id, address account) private {
        if (_claimed[id][account]) return;

        Payout storage p = _payouts[id];

        uint256 bal = sharesToken.balanceOfAt(account, p.snapshotId);
        if (bal == 0) { _claimed[id][account] = true; return; }

        uint256 share = (p.amount * bal) / sharesToken.totalSupplyAt(p.snapshotId);

        _claimed[id][account] = true;
        IERC20(p.token).safeTransfer(account, share);

        emit PayoutClaimed(id, account, p.token, share);
    }

    /* ─── List unpaid balances ─────────── */

    /**
     * @notice Return every unpaid payout share for `holder`.
     * @dev    Arrays are parallel and trimmed to length of non-zero items.
     */
    function unpaidBalances(address holder)
        external view
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        uint256 start = _nextPayoutId[holder];
        uint256 end   = _payouts.length;

        // First pass: count how many non-zero shares we’ll return
        uint256 count;
        for (uint256 i = start; i < end; ++i) {
            if (_claimed[i][holder]) continue;
            Payout storage p = _payouts[i];
            uint256 bal = sharesToken.balanceOfAt(holder, p.snapshotId);
            if (bal == 0) continue;
            count++;
        }

        tokens  = new address[](count);
        amounts = new uint256[](count);

        // Second pass: populate arrays
        uint256 j;
        for (uint256 i = start; i < end; ++i) {
            if (_claimed[i][holder]) continue;
            Payout storage p = _payouts[i];

            uint256 bal = sharesToken.balanceOfAt(holder, p.snapshotId);
            if (bal == 0) continue;

            tokens[j]  = p.token;
            amounts[j] = (p.amount * bal) / sharesToken.totalSupplyAt(p.snapshotId);
            ++j;
        }
    }

    /* ─── Pause control ────────────────────────────── */

    function pause()   external onlyRole(ROLE_PAUSER) { _pause(); }
    function unpause() external onlyRole(ROLE_PAUSER) { _unpause(); }

    /* ─── View helpers ─────────────────────────────── */

    function payoutsCount() external view returns (uint256) { return _payouts.length; }

    function nextPayoutIdOf(address a) external view returns (uint256) {
        return _nextPayoutId[a];
    }

    function pending(address a, uint256 id) external view returns (uint256) {
        if (id >= _payouts.length || _claimed[id][a]) return 0;
        Payout storage p = _payouts[id];

        uint256 bal = sharesToken.balanceOfAt(a, p.snapshotId);
        if (bal == 0) return 0;

        return (p.amount * bal) / sharesToken.totalSupplyAt(p.snapshotId);
    }

    /* ─── ERC-165 ──────────────────────────────────── */

    function supportsInterface(bytes4 id)
        public view
        override(AccessControlEnumerable)
        returns (bool)
    { return super.supportsInterface(id); }
}
