// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./RedPillSanta.sol";

contract Gainz is ERC20, Authorizable, ReentrancyGuard {
    address public SANTA_CONTRACT;

    // // $GAINZ price for per Red Pill NFT
    // uint256 public RED_PILL_PRICE = 4000 * 10 ** decimals();

    // // Required $GAINZ amount to win the game
    // uint256 public CHEST_PRICE = 1_000_000 * 10 ** decimals();

    // Leveling cooldown period
    uint32 public COOLDOWN_PERIOD = 1 days;

    struct StakedSantaObj {
        // Current strength of the Santa
        uint256 strength;
        // Base rarity of Santas. It won't be upgraded once assigned
        // 1- common (stay away from 0 frens), 2-cool, 3-rare, 4-epic, 5-legend, 6-unique
        uint32 rarity;
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
    event TierUp(uint256 tokenId, uint256 oldStrength, uint256 newStrength);
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
        require(santaContract.isGameActive() == true, "Game is not active!");
        require(santaContract.ownerOf(tokenId) == msg.sender, "NOT OWNER!");
        require(stakedSantas[tokenId].strength == 0, "ALREADY STAKED!");

        uint256 strength = santaContract.tokenStrength(tokenId); // take base strength from the NFT contract
        uint32 currentTs = uint32(block.timestamp);
        uint32 rarity = 0;

        if(strength == 8) {             // common
            rarity = 1;
        } else if(strength == 10){       // cool
            rarity = 2;
        } else if(strength == 15){       // rare
            rarity = 3;
        } else if(strength == 50){       // epic
            rarity = 4;
        } else if(strength == 200){      // legendary
            rarity = 5;
        } else if(strength == 400){      // unique
            rarity = 6;
        }

        require(rarity != 0, "Rarity Issue!");

        stakedSantas[tokenId] = StakedSantaObj(
            strength,
            rarity,
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
            uint256 gainzPerDay = (santa.strength * 10 ** decimals());  // TO BE UPDATED -> ADD INTERVALS !!!
            uint256 daysPassed = (block.timestamp - santa.stakeBeginTime) / 1 days;
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
            if (santa.strength > 0) { // To be sure that santa is staked
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
        require(santaContract.isGameActive() == true, "Game is not active!");
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
            // Unleash the event
            emit GainzMinted(msg.sender, totalGainzEarned);
        }
    }

    function claimGainz(uint256[] calldata tokenIDs) external nonReentrant {
        _claimGainz(tokenIDs);
    }

    // Unstake santa and stop earning $GAINZ, ngmi for sure.
    function _unstake(uint256 tokenId) internal {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        require(santaContract.isGameActive() == true, "Game is not active!");
        require(santaContract.ownerOf(tokenId) == msg.sender, "Sender is not the owner of that tokenID!");
    
        StakedSantaObj memory santa = stakedSantas[tokenId];
        if(santa.strength > 0) {    // Santa is staked
            totalStakedSanta--;
            totalStrengthAcquired -= santa.strength;

            // This only updates strength of this contract object.
            // Actual strength can be fetched again from the RedPillSanta NFT contract
            santa.strength = 0;
            stakedSantas[tokenId] = santa;

            // Unleash the event
            emit UnStaked(tokenId, block.timestamp);
        }
    }

    function _unstakeMultiple(uint256[] calldata tokenIDs) internal {
        for(uint256 i = 0; i < tokenIDs.length; i++) {
            _unstake(tokenIDs[i]);
        }
    }

    // Are you quitting? NGMI
    function claimAllAndUnstake(uint256[] calldata tokenIDs) external nonReentrant{
        _claimGainz(tokenIDs);
        _unstakeMultiple(tokenIDs);
    }

    /**
     @dev This function will be called externally by RedPill.sol contract
     i.   Updates pillsTaken value of a Santa
     ii.  Levels up Santa's strength to 1 Tier Up
     iii. Updates cooldown period
     -> Can't take RedPill unless Santa is currently staked
     -> Can't take RedPill if Cooldown period has not ended
     -> Can't take RedPill if Santa is already at the Legendary tier
    */
   function takeRedPill(uint256 tokenId) external onlyAuthorized {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        StakedSantaObj memory santa = stakedSantas[tokenId];

        require(santaContract.isGameActive() == true, "Game is not active!");
        require(santa.strength > 0, "Santa is not staked!");
        require(santa.strength <= 50, "Santa is already at the max upgradeble tier");
        require(block.timestamp >= santa.coolDownTime, "Santa is on Cooldown");

        santa.pillsTaken++;
        uint256 currentStrength = santa.strength;

        if(currentStrength == 8) {              // common -> cool
            santa.strength  = 10;
        } else if(currentStrength == 10){       // cool -> rare
            santa.strength  = 15;
        } else if(currentStrength == 15){       // rare -> epic
            santa.strength  = 50;
        } else if(currentStrength == 50){       // epic -> legendary
            santa.strength  = 200;
        } 

        santa.coolDownTime = uint32(block.timestamp + COOLDOWN_PERIOD);
        // Update santa parameters:
        stakedSantas[tokenId] = santa;
        
        // Update total global strength value
        totalStrengthAcquired += (santa.strength - currentStrength);

        // Finally Update the RedPillSanta contract
        santaContract.setStrength(tokenId, santa.strength);

        // Unleash the event
        emit TierUp(tokenId, currentStrength, santa.strength);
   }

    // Burns given amount of $GAINZ from sender's wallet
   function _burnGainz (address sender, uint256 gainzAmount) internal {
       require(balanceOf(sender) >= gainzAmount, "Not enough $GAINZ to burn!");
       _burn(sender, gainzAmount);

       // Unleash the event
       emit GainzBurned(sender, gainzAmount);
   }

   function burnGainz (address sender, uint256 gainzAmount) external onlyAuthorized {
       _burnGainz(sender, gainzAmount);
   }

    // Will be used to mint $GAINZ to holders on special occasions
    // Will also be called by RedPill contract 
   function mintGainz(address _to, uint256 amount) external onlyAuthorized {
       _mint(_to, amount);
       emit GainzMinted(_to, amount);
   }

    // AirDrops $GAINZ to holders of specified tokenId ranges
   function airDropGainz(uint256 _fromTokenId, uint256 _toTokenId, uint256 amount) external onlyOwner {
       RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);

       for(uint256 i = _fromTokenId; i <= _toTokenId; i++) {
           address tokenOwner = santaContract.ownerOf(i);
           if(tokenOwner != address(0)) {
               _mint(tokenOwner, amount);
           }
       }
   }

    // Restores claimable $GAINZ for stakers specified with tokenId range
    // Fundus are safu!
   function restoreUserGainz (uint256 _fromTokenId, uint256 _toTokenId) external onlyOwner {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);

        for(uint256 i = _fromTokenId; i <= _toTokenId; i++) {
           address tokenOwner = santaContract.ownerOf(i);
           StakedSantaObj memory santa = stakedSantas[i];
           // Only restore balances for staker wallets
           if(santa.strength > 0) {
               _mint(tokenOwner, viewEarnedGainz(i));
               santa.stakeBeginTime = uint32(block.timestamp);
               stakedSantas[i] = santa;
           }
       }
   }

}
