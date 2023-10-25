// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@daohaus/baal-contracts/contracts/interfaces/IBaal.sol";
import "@daohaus/baal-contracts/contracts/interfaces/IBaalToken.sol";

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// import "hardhat/console.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IBaalState {
    enum ProposalState {
        Unborn /* 0 - can submit */,
        Submitted /* 1 - can sponsor -> voting */,
        Voting /* 2 - can be cancelled, otherwise proceeds to grace */,
        Cancelled /* 3 - terminal state, counts as processed */,
        Grace /* 4 - proceeds to ready/defeated */,
        Ready /* 5 - can be processed */,
        Processed /* 6 - terminal state */,
        Defeated /* 7 - terminal state, yes votes <= no votes, counts as processed */
    }

    function getProposalStatus(uint32 proposalId) external view returns (bool[4] memory);

    function state(uint32 id) external view returns (ProposalState);
}

contract CommunityVetoShaman is Initializable {
    event CommunityVetoProposal(address indexed baal, address token, uint32 proposalId, string details);

    string public constant name = "CommunityVetoShaman";

    IBaal public baal;
    uint256 public thresholdPercent;

    mapping(uint32 => uint256) proposalSnapshots;
    mapping(uint32 => uint256) proposalVetoStake;
    mapping(uint32 => mapping(address => uint256)) vetoStakesByProposalId;

    function setup(
        address _moloch, // DAO address
        address _vault, // recipient vault
        bytes memory _initParams
    ) external initializer {
        uint256 _thresholdPercent = abi.decode(_initParams, (uint256));
        baal = IBaal(_moloch);
        thresholdPercent = _thresholdPercent; // 200 = 20%
    }

    function initCommunityVetoProposal(uint32 proposalId, string memory details) public {
        require(baal.isGovernor(address(this)), "Not governor shaman");
        require(proposalSnapshots[proposalId] == 0, "Veto already initiated");
        require(proposalInVoting(proposalId), "!voting");
        IBaalToken token = IBaalToken(baal.lootToken());
        // sponsor threshold of loot token only, prevent spam
        require(
            token.balanceOf(msg.sender) > baal.sponsorThreshold(),
            "Member does not meet sponsor threshold with loot"
        );
        // snapshot is taken after vote checkpoint, ideal would be at proposal sponsor
        // this is mostly an issue if loot token is transferable
        uint256 snapshotId = token.snapshot();
        proposalSnapshots[proposalId] = snapshotId;

        emit CommunityVetoProposal(address(baal), baal.lootToken(), proposalId, details);
    }

    function stakeVeto(uint32 proposalId) public {
        require(vetoStakesByProposalId[proposalId][msg.sender] == 0, "Already staked");
        require(proposalSnapshots[proposalId] != 0, "Veto not initiated");
        require(proposalInVoting(proposalId), "!voting");

        uint256 memberStake = IBaalToken(baal.lootToken()).balanceOfAt(msg.sender, proposalSnapshots[proposalId]);
        vetoStakesByProposalId[proposalId][msg.sender] = memberStake;
        proposalVetoStake[proposalId] = proposalVetoStake[proposalId] + memberStake;
    }

    function initAndStakeVeto(uint32 proposalId, string memory details) external {
        initCommunityVetoProposal(proposalId, details);
        stakeVeto(proposalId);
    }

    function cancelProposal(uint32 proposalId) external {
        require(getCurrentThresholdPercent(proposalId) > thresholdPercent, "Not enough loot staked to cancel");
        // will fail if not in voting state
        baal.cancelProposal(proposalId);
    }

    function getCurrentThresholdPercent(uint32 proposalId) public view returns (uint256) {
        uint256 totalAtSnapshot = IBaalToken(baal.lootToken()).totalSupplyAt(proposalSnapshots[proposalId]);
        return ((proposalVetoStake[proposalId] * 1000) / totalAtSnapshot);
    }

    function updateThresholdPercent(uint256 _thresholdPercent) public onlyBaal {
        thresholdPercent = _thresholdPercent;
    }

    function proposalInVoting(uint32 proposalId) internal view returns (bool) {
        IBaalState.ProposalState state = IBaalState(address(baal)).state(proposalId);
        return state == IBaalState.ProposalState.Voting;
    }

    modifier onlyBaal() {
        require(msg.sender == address(baal), "!baal");
        _;
    }
}
