// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ─────────────────────────────────────────────────────────────────────────────
   PayoutDistributor — ERC-20 payout sharing for an ERC20Votes-based shares token
                       (uses on-chain checkpoints instead of ERC20Snapshot)

      Roles
        • ROLE_ADMIN    – governs every other role (alias 0x00)
        • ROLE_DEPOSIT  – authorised to deposit funds & create payouts
        • ROLE_PAUSER   – emergency pause / unpause
   ───────────────────────────────────────────────────────────────────────────── */

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

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
        address token;       // payout currency
        uint256 amount;      // total deposited
        uint256 blockNumber; // checkpoint block used for getPastVotes()
        uint256 timestamp;   // block.timestamp
    }

    IVotes  public immutable sharesToken;         // ERC20Votes-based shares
    Payout[]           private _payouts;          // payout history

    mapping(uint256 => mapping(address => bool)) private _claimed;      // payoutId ⇒ holder ⇒ done?
    mapping(address => uint256)                  private _nextPayoutId; // first unclaimed for holder

    /* ─── Events ───────────────────────────────────── */

    event PayoutRecorded(
        uint256 indexed id,
        address indexed token,
        uint256 amount,
        uint256 checkpointBlock,
        uint256 timestamp
    );

    event PayoutClaimed(
        uint256 indexed id,
        address indexed holder,
        address indexed token,
        uint256 amount
    );

    /* ─── Constructor ───────────────────────────────── */

    constructor(IVotes _sharesToken, address admin_) {
        require(address(_sharesToken) != address(0), "shares token zero");
        sharesToken = _sharesToken;

        _grantRole(ROLE_ADMIN,   admin_);
        _grantRole(ROLE_DEPOSIT, admin_);
        _grantRole(ROLE_PAUSER,  admin_);
    }

    /* ─── Deposit & record ─────────────────────────── */

    /**
     * @notice Deposit ERC-20 `token` and create a payout that will be
     *         distributed pro-rata to shares holders based on voting power
     *         at `block.number - 1`.
     */
    function recordPayout(address token, uint256 amount)
        external
        onlyRole(ROLE_DEPOSIT)
        whenNotPaused
    {
        require(token != address(0), "token zero");
        require(amount > 0, "zero amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 checkpointBlock = block.number - 1;          // must be < current

        _payouts.push(Payout({
            token:       token,
            amount:      amount,
            blockNumber: checkpointBlock,
            timestamp:   block.timestamp
        }));

        emit PayoutRecorded(
            _payouts.length - 1,
            token,
            amount,
            checkpointBlock,
            block.timestamp
        );
    }

    /* ─── Claim APIs ───────────────────────────────── */

    /**
     * @notice Claim all outstanding payouts for caller.
     */
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

        uint256 bal = sharesToken.getPastVotes(account, p.blockNumber);
        if (bal == 0) { _claimed[id][account] = true; return; }

        uint256 supply = sharesToken.getPastTotalSupply(p.blockNumber);
        if (supply == 0) return; // should never happen

        uint256 share = (p.amount * bal) / supply;

        _claimed[id][account] = true;
        IERC20(p.token).safeTransfer(account, share);

        emit PayoutClaimed(id, account, p.token, share);
    }

    /* ─── Unpaid-balances helper ───────────────────── */

    /**
     * @notice Return every unpaid payout share for `holder`.
     *         Two parallel arrays: tokens[i], amounts[i].
     */
    function unpaidBalances(address holder)
        external view
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        uint256 start = _nextPayoutId[holder];
        uint256 end   = _payouts.length;

        uint256 count;
        for (uint256 i = start; i < end; ++i) {
            if (_claimed[i][holder]) continue;
            if (sharesToken.getPastVotes(holder, _payouts[i].blockNumber) == 0) continue;
            ++count;
        }

        tokens  = new address[](count);
        amounts = new uint256[](count);

        uint256 j;
        for (uint256 i = start; i < end; ++i) {
            if (_claimed[i][holder]) continue;

            Payout storage p = _payouts[i];
            uint256 bal = sharesToken.getPastVotes(holder, p.blockNumber);
            if (bal == 0) continue;

            tokens[j]  = p.token;
            amounts[j] = (p.amount * bal) / sharesToken.getPastTotalSupply(p.blockNumber);
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

        uint256 bal = sharesToken.getPastVotes(a, p.blockNumber);
        if (bal == 0) return 0;

        return (p.amount * bal) / sharesToken.getPastTotalSupply(p.blockNumber);
    }

    /* ─── ERC-165 ──────────────────────────────────── */

    function supportsInterface(bytes4 id)
        public view
        override(AccessControlEnumerable)
        returns (bool)
    { return super.supportsInterface(id); }
}
