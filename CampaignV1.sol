//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ICampaignV1 {
    function totalVoteCount() external view returns (uint64[] memory);

    function isVoted(address addr) external view returns (bool);

    function startDate() external view returns (uint256);

    function setStartDate(uint256 newTimestamp) external; // contract owner required

    function endDate() external view returns (uint256);

    function setEndDate(uint256 newTimestamp) external; // contract owner required

    function setUri(string memory newUri) external; // contract owner required

    function contractURI() external view returns (string memory);

    function setContractURI(string memory uri) external;

    function vote(
        uint8[] memory sortedIds, // Length from 1 to 3, ascending order
        bytes memory memo, // Within 128 bytes
        bytes32 ticket,
        bytes memory signature
    ) external;
}

contract CampaignV1 is ERC1155, ICampaignV1, Ownable, ReentrancyGuard {
    uint256 private _startDate;
    uint256 private _endDate;
    string private _contractUri;
    uint256 private _nextTokenId;
    // Array for candidate's total vote count
    uint64[] private _voteCounts;

    // Flag whether address is voted or not
    mapping(address => bool) private _isVoted;

    mapping(bytes32 => bool) private _isTicketUsed;

    event Voted(
        uint8[] sortedIds,
        bytes32 ticket,
        address voter,
        uint256 tokenId
    );

    constructor(
        string memory tokenBaseUri,
        string memory contractBaseUri,
        uint8 totalCandidates,
        uint256 campaignStartDate,
        uint256 campaignEndDate
    )
        ERC1155(
            string(
                abi.encodePacked(
                    tokenBaseUri,
                    "/",
                    Strings.toHexString(block.chainid),
                    "/",
                    Strings.toHexString(uint256(uint160(address(this))), 20),
                    "/{id}"
                )
            )
        )
    {
        _contractUri = string(
            abi.encodePacked(
                contractBaseUri,
                "/",
                Strings.toHexString(block.chainid),
                "/",
                Strings.toHexString(uint256(uint160(address(this))), 20)
            )
        );
        _voteCounts = new uint64[](totalCandidates);
        _startDate = campaignStartDate;
        _endDate = campaignEndDate;
        _nextTokenId = 0;
    }

    function setUri(string memory newUri) external override onlyOwner {
        _setURI(newUri);
    }

    function setStartDate(uint256 newTimestamp) external override onlyOwner {
        _startDate = newTimestamp;
    }

    function setEndDate(uint256 newTimestamp) external override onlyOwner {
        _endDate = newTimestamp;
    }

    function totalVoteCount() external view override returns (uint64[] memory) {
        return _voteCounts;
    }

    function isVoted(address addr) external view override returns (bool) {
        return _isVoted[addr];
    }

    function startDate() external view override returns (uint256) {
        return _startDate;
    }

    function endDate() external view override returns (uint256) {
        return _endDate;
    }

    function vote(
        uint8[] memory sortedIds,
        bytes memory memo,
        bytes32 ticket,
        bytes memory signature
    ) external override nonReentrant {
        // checks
        require(block.timestamp >= _startDate, "vote has not started yet");
        require(block.timestamp <= _endDate, "vote has ended already");
        require(!_isVoted[_msgSender()], "User has voted");
        require(
            sortedIds.length >= 1 && sortedIds.length <= 3,
            "Ids length not in [1,3]"
        );
        require(_isAscendingOrder(sortedIds), "Ids not in ascending order");
        require(memo.length <= 128, "Memo should be within 128 bytes");
        require(!_isTicketUsed[ticket], "Ticket is used");
        require(_isAuthorized(ticket, signature), "The vote is not authorized");
        // effects
        uint256 mintedTokenId = _nextTokenId;
        _nextTokenId++;
        for (uint8 i = 0; i < sortedIds.length; i++) {
            _voteCounts[sortedIds[i]] += 1;
        }
        _isVoted[_msgSender()] = true;
        _isTicketUsed[ticket] = true;
        // interactions
        _mint(_msgSender(), mintedTokenId, 1, "");
        emit Voted(sortedIds, ticket, _msgSender(), mintedTokenId);
    }

    function _isAuthorized(bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool)
    {
        return owner() == ECDSA.recover(hash, signature);
    }

    function _isAscendingOrder(uint8[] memory arr)
        internal
        pure
        returns (bool)
    {
        if (arr.length == 1) return true;
        for (uint8 i = 1; i < arr.length; i++) {
            if (arr[i] <= arr[i - 1]) return false;
        }
        return true;
    }

    function contractURI() external view override returns (string memory) {
        return _contractUri;
    }

    function setContractURI(string memory uri) external onlyOwner override {
        _contractUri = uri;
    }
}
