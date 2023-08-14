// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

/**
 * @title TokenDuel
 * @dev A smart contract for creating and participating in token duels.
 */

contract TokenDuel {

    // Structure to store token information
    struct tokenInfo {
        address tokenAddress; // Address of the ERC721 token contract
        uint256 tokenID; // ID of the token within the ERC721 contract
    }

    // Structure to store duel information
    struct duelInfo {
        address player1; // Address of player 1
        tokenInfo token1; // Information about player 1's token
        address player2; // Address of player 2
        tokenInfo token2; // Information about player 2's token
        string status; // Status of the duel (e.g., "pending", "ongoing")
    }

    // Mapping to store duel information by duel ID
    mapping(uint256 => duelInfo) public Duels;

    // Variable to keep track of the maximum duel ID
    uint256 maxDuelID;

    // Events
    event TransferNFTPlayer1(uint256 indexed duelID, address indexed token1Address, uint256 indexed token1ID);
    event TransferNFTPlayer2(uint256 indexed duelID, address indexed token2Address, uint256 indexed token2ID);
    event DuelCreated(uint256 indexed duelID, address indexed player1);
    event DuelWithdrawn(uint256 indexed duelID, address indexed player1);
    event DuelJoined(uint256 indexed duelID, address indexed player2);
    event DuelEnded(uint256 indexed duelID, address indexed winner, address indexed loser);


    /**
     * @dev This function allows a user to create a duel by transferring their token to the contract.
     * @param _nftContract The address of the ERC721 token contract.
     * @param _tokenId The ID of the token to be used in the duel.
     */
    function createDuel(address _nftContract, uint256 _tokenId) public returns (uint256) {
        // Transfer the token to this contract
        IERC721 token = IERC721(_nftContract);
        require(token.getApproved(_tokenId) == address(this), "Contract is not approved");
        token.transferFrom(msg.sender, address(this), _tokenId);

        // Store duel information
        uint256 duelID = maxDuelID;
        Duels[duelID].player1 = msg.sender;
        Duels[duelID].token1.tokenAddress = _nftContract;
        Duels[duelID].token1.tokenID = _tokenId;
        Duels[duelID].status = "pending";
        maxDuelID++;
        emit TransferNFTPlayer1(duelID, _nftContract, _tokenId);
        emit DuelCreated(duelID, msg.sender);
        return duelID;
    }

    /**
     * @dev This function allows the creator of a duel to withdraw it, receiving their token back.
     * @param _duelID The ID of the duel to be withdrawn.
     */
    function withdrawDuel(uint256 _duelID) public {
        require(msg.sender == Duels[_duelID].player1, "You cannot remove the duel");
        require(keccak256(abi.encodePacked(Duels[_duelID].status)) == keccak256(abi.encodePacked("pending")), "Duel has already been accepted");

        // Transfer the token back to the creator
        IERC721 token = IERC721(Duels[_duelID].token1.tokenAddress);
        uint256 tokenID = Duels[_duelID].token1.tokenID;
        token.transferFrom(address(this), msg.sender, tokenID);

        // Delete the duel information
        delete Duels[_duelID];
        emit DuelWithdrawn(_duelID, msg.sender);
    }

    /**
     * @dev This function allows a user to join a pending duel by transferring their token to the contract.
     * @param _nftContract The address of the ERC721 token contract.
     * @param _tokenId The ID of the token to be used in the duel.
     * @param _duelID The ID of the duel to join.
     */
    function joinDuel(address _nftContract, uint256 _tokenId, uint256 _duelID) public {
        IERC721 token = IERC721(_nftContract);
        // todo: check if the duel exists
        require(keccak256(abi.encodePacked(Duels[_duelID].status)) == keccak256(abi.encodePacked("pending")), "Duel has already been accepted");
        require(token.getApproved(_tokenId) == address(this), "Contract is not approved");

        // Transfer the token to this contract
        token.transferFrom(msg.sender, address(this), _tokenId);

        // Store duel information for the joining player
        Duels[_duelID].player2 = msg.sender;
        Duels[_duelID].token2.tokenAddress = _nftContract;
        Duels[_duelID].token2.tokenID = _tokenId;
        Duels[_duelID].status = "ongoing";

        emit TransferNFTPlayer2(_duelID, _nftContract, _tokenId);
        emit DuelJoined(_duelID, msg.sender);
    }

    /**
     * @dev This function allows one of the two players to end an ongoing duel with a pseudo-random draw.
     * The winner gets their NFT back, and the loser's NFT is burnt (sent to address(1)).
     * @param _duelID The ID of the duel to end.
     */
    function endDuel(uint256 _duelID) public {
        require(msg.sender == Duels[_duelID].player1 || msg.sender == Duels[_duelID].player2, "You cannot end the duel");
        require(keccak256(abi.encodePacked(Duels[_duelID].status)) == keccak256(abi.encodePacked("ongoing")), "Duel is not ongoing");

        // Generate a pseudo-random number using block variables
        uint256 randomNum = uint256(keccak256(abi.encodePacked(Duels[_duelID].player1, Duels[_duelID].player2, block.prevrandao, block.timestamp)));

        if (randomNum % 2 == 0) {
            // Player 1 lost
            IERC721(Duels[_duelID].token1.tokenAddress).transferFrom(address(this), address(1), Duels[_duelID].token1.tokenID);
            IERC721(Duels[_duelID].token2.tokenAddress).transferFrom(address(this), Duels[_duelID].player2, Duels[_duelID].token2.tokenID);
            emit DuelEnded(_duelID, Duels[_duelID].player2, Duels[_duelID].player1);
        } else {
            // Player 2 lost
            IERC721(Duels[_duelID].token2.tokenAddress).transferFrom(address(this), address(1), Duels[_duelID].token2.tokenID);
            IERC721(Duels[_duelID].token1.tokenAddress).transferFrom(address(this), Duels[_duelID].player1, Duels[_duelID].token1.tokenID);
            emit DuelEnded(_duelID, Duels[_duelID].player1, Duels[_duelID].player2);
        }

        // Delete the duel information
        delete Duels[_duelID];
    }
}
