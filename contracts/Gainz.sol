// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./RedPillSanta.sol";

contract Gainz is ERC20, Authorizable {

    address public SANTA_CONTRACT;

    struct StakedSantaObj {
        // Current strength of the Santa
        uint256 strength;
        // Stake begin time
        uint32 stakeBeginTime;
        // # of Redpills taken
        uint48 pillsTaken;
    }

    mapping (uint256 => StakedSantaObj) public stakedSantas;

    uint256 public totalStakedSanta;
    uint256 public totalStrengthAcquired;

    //Events
    event Staked(uint256 tokenId, uint256 timeStamp);
    event UnStaked(uint256 tokenId, uint256 timeStamp);
    event GainzMinted(address minter, uint256 amount);
    event GainzBurned(address minter, uint256 amount);

    constructor(address _santaContract) ERC20("GAINZ", "GAINZ") {
        SANTA_CONTRACT = _santaContract;
    }

    // Santa Staking
    function stake(uint256[] calldata tokenIDs) external {
        for(uint256 i = 0; i < tokenIDs.length; i++) {
            _stake(tokenIDs[i]);
        }
    }

    function _stake(uint256 tokenId) internal {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.ownerOf(tokenId) == msg.sender, "You are not the owner ser!");
        require(stakedSantas[tokenId].strength == 0, "This santa is already staked ser!");

        uint256 strength = santaContract.tokenStrength(tokenId);    // take base strength from the NFT contract
        uint32 currentTs = uint32(block.timestamp);

        stakedSantas[tokenId] = StakedSantaObj(strength, currentTs, uint48(0));
        
        totalStakedSanta++;
        totalStrengthAcquired += strength;

        // Unleash the event
        emit Staked(tokenId, block.timestamp);
    }

    // Returns all of the user's staked santa IDs
    function stakedSantasOfOwner() public view returns (uint256[] memory stakedIDs, uint256 stakedCount) {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        uint256[] memory allSantaIDs = santaContract.tokensOfOwner(msg.sender);
        stakedIDs = new uint256[](allSantaIDs.length);

        stakedCount = 0;
        for(uint256 i = 0; i < allSantaIDs.length; i++) {
            StakedSantaObj memory santa = stakedSantas[allSantaIDs[i]];
            if(santa.strength > 0) {
                stakedIDs[stakedCount] = allSantaIDs[i];
                stakedCount++;
            } 
        }
        return (stakedIDs, stakedCount);
    }

}
