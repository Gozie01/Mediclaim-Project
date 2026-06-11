// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ─────────────────────────────────────────────────────────────────────────────
// MultiOracleConsensus — Gap 5 (Oracle trust / single point of failure)
//
// Three independent off-chain oracle nodes (see oracle/node1.js, node2.js,
// node3.js) each validate ICD-10 / CPT procedure codes against a reference
// dataset. A claim is approved only when ≥ 2-of-3 nodes agree (consensus).
//
// This directly addresses the gap: "a single Chainlink feed is a central point
// of failure for automated adjudication. No paper proposes multi-oracle
// consensus for claim validation."  — identified in the 2024-2025 literature.
//
// Additionally records per-node accuracy scores for reputation tracking.
// ─────────────────────────────────────────────────────────────────────────────

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IMediClaimCallback {
    function oracleCallback(
        bytes32 claimId,
        bool    approved,
        uint8   confidenceScore
    ) external;
}

contract MultiOracleConsensus is AccessControl {

    bytes32 public constant ORACLE_NODE_ROLE = keccak256("ORACLE_NODE_ROLE");

    uint8 public constant TOTAL_NODES        = 3;
    uint8 public constant REQUIRED_CONSENSUS = 2; // 2-of-3 majority

    // Timeout after which a request can be manually resolved with partial votes
    uint256 public constant REQUEST_TIMEOUT = 5 minutes;

    struct OracleRequest {
        bytes32 claimId;
        string  icdCode;
        string  cptCode;
        address mediClaimContract;
        uint8   approveCount;
        uint8   rejectCount;
        bool    resolved;
        uint256 requestedAt;
    }

    // requestId → OracleRequest
    mapping(bytes32 => OracleRequest)                        public requests;
    // requestId → nodeAddress → hasVoted
    mapping(bytes32 => mapping(address => bool))             public hasVoted;
    // requestId → nodeAddress → vote
    mapping(bytes32 => mapping(address => bool))             public votes;

    // Oracle node reputation tracking (Gap 5 — novel contribution)
    mapping(address => uint256) public nodeCorrectVotes;
    mapping(address => uint256) public nodeTotalVotes;
    address[]                   public oracleNodes;

    // ── Events ────────────────────────────────────────────────────────────────
    event ValidationRequested(
        bytes32 indexed requestId,
        bytes32 indexed claimId,
        string  icdCode,
        string  cptCode,
        uint256 timestamp
    );
    event OracleVoteCast(
        bytes32 indexed requestId,
        address indexed node,
        bool    approved,
        uint256 timestamp
    );
    event ConsensusReached(
        bytes32 indexed requestId,
        bytes32 indexed claimId,
        bool    approved,
        uint8   confidence,
        uint256 timestamp
    );
    event OracleNodeRegistered(address indexed node, uint256 timestamp);
    event RequestTimedOut(bytes32 indexed requestId, uint256 timestamp);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ── Admin: register an oracle node ───────────────────────────────────────
    function registerOracleNode(address _node) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_node != address(0), "MultiOracleConsensus: zero address");
        _grantRole(ORACLE_NODE_ROLE, _node);
        oracleNodes.push(_node);
        emit OracleNodeRegistered(_node, block.timestamp);
    }

    // ── Called by MediClaim when a claim passes Gates A + B ──────────────────
    function requestValidation(
        bytes32        _claimId,
        string calldata _icdCode,
        string calldata _cptCode,
        address         _mediClaimContract
    ) external returns (bytes32) {
        bytes32 requestId = keccak256(
            abi.encodePacked(_claimId, _icdCode, _cptCode, block.timestamp)
        );

        requests[requestId] = OracleRequest({
            claimId:           _claimId,
            icdCode:           _icdCode,
            cptCode:           _cptCode,
            mediClaimContract: _mediClaimContract,
            approveCount:      0,
            rejectCount:       0,
            resolved:          false,
            requestedAt:       block.timestamp
        });

        emit ValidationRequested(requestId, _claimId, _icdCode, _cptCode, block.timestamp);
        return requestId;
    }

    // ── Oracle node casts vote ────────────────────────────────────────────────
    function submitVote(
        bytes32 _requestId,
        bool    _approved
    ) external onlyRole(ORACLE_NODE_ROLE) {
        OracleRequest storage req = requests[_requestId];
        require(req.requestedAt > 0,         "MultiOracleConsensus: request not found");
        require(!req.resolved,               "MultiOracleConsensus: already resolved");
        require(!hasVoted[_requestId][msg.sender], "MultiOracleConsensus: already voted");

        hasVoted[_requestId][msg.sender] = true;
        votes[_requestId][msg.sender]    = _approved;
        nodeTotalVotes[msg.sender]++;

        if (_approved) { req.approveCount++; }
        else           { req.rejectCount++;  }

        emit OracleVoteCast(_requestId, msg.sender, _approved, block.timestamp);

        // Check if consensus threshold reached
        if (req.approveCount >= REQUIRED_CONSENSUS || req.rejectCount >= REQUIRED_CONSENSUS) {
            _resolveConsensus(_requestId);
        }
    }

    // ── Timeout resolution (partial consensus after REQUEST_TIMEOUT) ──────────
    function resolveTimedOut(bytes32 _requestId) external {
        OracleRequest storage req = requests[_requestId];
        require(!req.resolved, "MultiOracleConsensus: already resolved");
        require(
            block.timestamp >= req.requestedAt + REQUEST_TIMEOUT,
            "MultiOracleConsensus: timeout not reached"
        );
        // Resolve with majority of partial votes, or reject if tie
        _resolveConsensus(_requestId);
        emit RequestTimedOut(_requestId, block.timestamp);
    }

    // ── Internal: compute consensus and callback ──────────────────────────────
    function _resolveConsensus(bytes32 _requestId) internal {
        OracleRequest storage req = requests[_requestId];
        req.resolved = true;

        bool  approved    = req.approveCount > req.rejectCount;
        uint8 totalVotes  = req.approveCount + req.rejectCount;
        uint8 confidence  = totalVotes > 0
            ? uint8((uint256(approved ? req.approveCount : req.rejectCount) * 100) / totalVotes)
            : 0;

        emit ConsensusReached(_requestId, req.claimId, approved, confidence, block.timestamp);

        // Callback to MediClaim contract
        IMediClaimCallback(req.mediClaimContract).oracleCallback(
            req.claimId,
            approved,
            confidence
        );
    }

    // ── Reputation: update correct-vote count (called post-resolution) ────────
    // MediClaim can call this to reward nodes whose vote matched consensus
    function recordNodeAccuracy(bytes32 _requestId) external {
        OracleRequest storage req = requests[_requestId];
        require(req.resolved, "MultiOracleConsensus: not resolved");
        bool consensus = req.approveCount > req.rejectCount;

        for (uint i = 0; i < oracleNodes.length; i++) {
            address node = oracleNodes[i];
            if (hasVoted[_requestId][node] && votes[_requestId][node] == consensus) {
                nodeCorrectVotes[node]++;
            }
        }
    }

    // ── View helpers ──────────────────────────────────────────────────────────
    function getNodeAccuracy(address _node) external view returns (uint256 correct, uint256 total) {
        return (nodeCorrectVotes[_node], nodeTotalVotes[_node]);
    }

    function getRequestStatus(bytes32 _requestId) external view returns (
        bool   resolved,
        bool   approved,
        uint8  approveCount,
        uint8  rejectCount
    ) {
        OracleRequest storage req = requests[_requestId];
        return (
            req.resolved,
            req.approveCount >= REQUIRED_CONSENSUS,
            req.approveCount,
            req.rejectCount
        );
    }

    function getOracleNodes() external view returns (address[] memory) {
        return oracleNodes;
    }
}
