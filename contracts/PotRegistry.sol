// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PotRegistry — records Potfolio pots onchain. Holds no funds.
/// @notice A pot is an allocation (token + weight in basis points) owned by the wallet that created it.
contract PotRegistry {
    struct Allocation {
        address token;
        uint16 weightBps; // all weights sum to 10_000
    }

    struct Pot {
        address owner;
        string name;
        uint8 goal; // 0 wealth, 1 tech, 2 income, 3 long term
        uint64 createdAt;
        Allocation[] allocations;
    }

    address public immutable admin;
    mapping(address => bool) public allowedToken; // tokenized stocks on Base
    mapping(uint256 => Pot) private _pots;
    mapping(address => uint256[]) private _byOwner;
    uint256 public potCount;

    event PotCreated(uint256 indexed potId, address indexed owner, uint8 goal);
    event PotUpdated(uint256 indexed potId);
    event TokenAllowed(address indexed token, bool allowed);

    error NotOwner();
    error BadWeights();
    error TokenNotAllowed(address token);
    error TooManyAllocations();

    constructor() {
        admin = msg.sender;
    }

    function setAllowedToken(address token, bool allowed) external {
        require(msg.sender == admin, "admin only");
        allowedToken[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    function createPot(string calldata name, uint8 goal, Allocation[] calldata allocs) external returns (uint256 potId) {
        potId = ++potCount;
        Pot storage p = _pots[potId];
        p.owner = msg.sender;
        p.name = name;
        p.goal = goal;
        p.createdAt = uint64(block.timestamp);
        _write(p, allocs);
        _byOwner[msg.sender].push(potId);
        emit PotCreated(potId, msg.sender, goal);
    }

    function updatePot(uint256 potId, Allocation[] calldata allocs) external {
        Pot storage p = _pots[potId];
        if (p.owner != msg.sender) revert NotOwner();
        delete p.allocations;
        _write(p, allocs);
        emit PotUpdated(potId);
    }

    function getPot(uint256 potId) external view returns (address owner, string memory name, uint8 goal, uint64 createdAt, Allocation[] memory allocations) {
        Pot storage p = _pots[potId];
        return (p.owner, p.name, p.goal, p.createdAt, p.allocations);
    }

    function potsOf(address owner) external view returns (uint256[] memory) {
        return _byOwner[owner];
    }

    function _write(Pot storage p, Allocation[] calldata allocs) private {
        if (allocs.length == 0 || allocs.length > 10) revert TooManyAllocations();
        uint256 total;
        for (uint256 i; i < allocs.length; ++i) {
            if (!allowedToken[allocs[i].token]) revert TokenNotAllowed(allocs[i].token);
            total += allocs[i].weightBps;
            p.allocations.push(allocs[i]);
        }
        if (total != 10_000) revert BadWeights();
    }
}
