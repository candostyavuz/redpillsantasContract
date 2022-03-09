// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./RedPillSanta.sol";

contract Gainz is ERC20, Authorizable, ReentrancyGuard {
    address public SANTA_CONTRACT;

    // $GAINZ price for per Red Pill NFT
    uint256 RED_PILL_PRICE = 4000 * 10 * decimals();

    // Required $GAINZ amount to win the game
    uint256 CHEST_PRICE = 1_000_000 * 10 * decimals();

    // Leveling cooldown period
    uint32 public COOLDOWN_PERIOD = 1 hours;

    struct StakedSantaObj {
        // Current strength of the Santa
        uint256 strength;
        // Stake begin time
        uint32 stakeBeginTime;
        // # of Redpills taken
        uint48 pillsTaken;
        // Time until upgrading is allowed again
        uint32 coolDownTime;
    }

    mapping(uint256 => StakedSantaObj) public stakedSantas;

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
        for (uint256 i = 0; i < tokenIDs.length; i++) {
            _stake(tokenIDs[i]);
        }
    }

    function _stake(uint256 tokenId) internal {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(
            santaContract.ownerOf(tokenId) == msg.sender,
            "You are not the owner ser!"
        );
        require(
            stakedSantas[tokenId].strength == 0,
            "This santa is already staked ser!"
        );

        uint256 strength = santaContract.tokenStrength(tokenId); // take base strength from the NFT contract
        uint32 currentTs = uint32(block.timestamp);

        stakedSantas[tokenId] = StakedSantaObj(
            strength,
            currentTs,
            uint48(0),
            uint32(currentTs) + uint32(COOLDOWN_PERIOD)
        );

        totalStakedSanta++;
        totalStrengthAcquired += strength;

        // Unleash the event
        emit Staked(tokenId, block.timestamp);
    }

    // Returns all of the user's staked santa IDs
    function stakedSantasOfOwner() public view returns (uint256[] memory stakedIDs, uint256 stakedCount)
    {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        uint256[] memory ownerSantaIDs = santaContract.tokensOfOwner(msg.sender);
        stakedIDs = new uint256[](ownerSantaIDs.length);

        stakedCount = 0;
        for (uint256 i = 0; i < ownerSantaIDs.length; i++) {
            StakedSantaObj memory santa = stakedSantas[ownerSantaIDs[i]];
            if (santa.strength > 0) {
                stakedIDs[stakedCount] = ownerSantaIDs[i];
                stakedCount++;
            }
        }
        return (stakedIDs, stakedCount);
    }

    // Returns the amount of $GAINZ earned by a specific Santa
    function viewEarnedGainz(uint256 tokenId) public view returns (uint256) {
        StakedSantaObj memory santa = stakedSantas[tokenId];
        if (santa.strength > 0) {
            uint256 gainzPerDay = (santa.strength * 10 ** decimals());
            uint256 daysPassed = (block.timestamp - santa.stakeBeginTime) /
                1 days;
            return gainzPerDay * daysPassed;
        } else {
            return 0;
        }
    }

    // Returns the amount of $GAINZ earned by ALL Santas of the sender
    function viewAllEarnedGainz() public view returns (uint256) {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        uint256[] memory ownerSantaIDs = santaContract.tokensOfOwner(msg.sender);
        uint256 totalGainzEarned = 0;
        for (uint256 i = 0; i < ownerSantaIDs.length; i++) {
            StakedSantaObj memory santa = stakedSantas[ownerSantaIDs[i]];
            if (santa.strength > 0) {
                // To be sure that santa is staked
                uint256 earnedAmount = viewEarnedGainz(ownerSantaIDs[i]);
                if (earnedAmount > 0) {
                    totalGainzEarned += earnedAmount;
                }
            }
        }
        return totalGainzEarned;
    }

    // Mints earned amount of $GAINZ to sender's wallet
    function _claimGainz(uint256[] calldata tokenIDs) internal {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        uint256 totalGainzEarned = 0;

        for (uint256 i = 0; i < tokenIDs.length; i++) {
            require(santaContract.ownerOf(tokenIDs[i]) == msg.sender, "Sender is not the owner of that tokenID!");
            StakedSantaObj memory santa = stakedSantas[tokenIDs[i]];
            if (santa.strength > 0) {
                uint256 earnedAmount = viewEarnedGainz(tokenIDs[i]);
                if (earnedAmount > 0) {
                    totalGainzEarned += earnedAmount;
                    // Reset the santa timestamp for next $GAINZ calculation
                    santa.stakeBeginTime = uint32(block.timestamp);
                    stakedSantas[tokenIDs[i]] = santa;
                }
            }
        }
        if (totalGainzEarned > 0) {
            _mint(msg.sender, totalGainzEarned); // Mint $GAINZ to user's wallet
            emit GainzMinted(msg.sender, totalGainzEarned);
        }
    }

    function claimGainz(uint256[] calldata tokenIDs) external nonReentrant {
        _claimGainz(tokenIDs);
    }

    // Unstake santa and stop earning $GAINZ, ngmi for sure.
    function _unstake(uint256 tokenId) internal {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.ownerOf(tokenId) == msg.sender, "Sender is not the owner of that tokenID!");

        StakedSantaObj memory santa = stakedSantas[tokenId];
        if(santa.strength > 0) {    // Santa is staked
            totalStakedSanta--;
            totalStrengthAcquired -= santa.strength;

            // This only updates strength of this contract object.
            // Actual strength can be fetched again from the RedPillSanta NFT contract
            santa.strength = 0;
            stakedSantas[tokenId] = santa;

            emit UnStaked(tokenId, block.timestamp);
        }
    }

    function _unstakeMultiple(uint256[] calldata tokenIDs) internal {
        for(uint256 i = 0; i < tokenIDs.length; i++) {
            _unstake(tokenIDs[i]);
        }
    }

    // NGMI
    function unstake(uint256[] calldata tokenIDs) external {
        _unstakeMultiple(tokenIDs);
    }

    // Are you quitting ser?
    function claimAllAndUnstake(uint256[] calldata tokenIDs) external nonReentrant{
        _claimGainz(tokenIDs);
        _unstakeMultiple(tokenIDs);
    }

    // Update pillsTaken value of a Santa
    // Can't take any RedPills unless Santa is currently staked
   function takeRedPill(uint256 tokenId) external onlyAuthorized {
       StakedSantaObj memory santa = stakedSantas[tokenId];
       require(santa.strength > 0, "Santa is not staked");
        //   Continue from there...
           
   }

}
