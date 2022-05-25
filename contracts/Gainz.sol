// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Authorizable.sol";
import "./RedPillSanta.sol";

contract Gainz is ERC20, Authorizable, ReentrancyGuard {
    address public SANTA_CONTRACT;

    // Required amount of $GAINZ to unlock the prize pool
    uint256 public UNLOCK_AMOUNT = 10_000 * 10 ** decimals();
    // Leveling cooldown period
    uint256 public LEVEL_COOLDOWN_PERIOD = 1 days;

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
        uint32 levelCoolDown;
    }

    mapping(uint256 => StakedSantaObj) public stakedSantas;

    uint256 public totalStakedSanta;
    uint256 public totalStrengthAcquired;

    //Events s
    event TierUp(uint256 tokenId, uint256 oldStrength, uint256 newStrength);
    event GainzMinted(address minter, uint256 amount);
    event GainzBurned(address minter, uint256 amount);
    event PrizeClaimed(address claimer, uint256 prizeAmount);

    constructor(address _santaContract) ERC20("GAINZ", "GAINZ") {
        setSantaContract(_santaContract);
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
        require(stakedSantas[tokenId].strength == 0, "ALREADY STAKED");

        uint256 strength = santaContract.tokenStrength(tokenId); // take base strength from the NFT contract
        uint32 currentTs = uint32(block.timestamp);
        uint32 rarity = 0;

        if(strength == 30) {             // common
            rarity = 1;
        } else if(strength == 90){       // cool
            rarity = 2;
        } else if(strength == 200){      // rare
            rarity = 3;
        } else if(strength == 300){      // epic
            rarity = 4;
        } else if(strength == 400){      // legendary
            rarity = 5;
        } else if(strength == 500){      // unique
            rarity = 6;
        }

        stakedSantas[tokenId] = StakedSantaObj(
            strength,
            rarity,
            currentTs,
            uint48(0),
            uint32(0)          // Can't level up immediately
        );

        totalStakedSanta++;
        totalStrengthAcquired += strength;
    }

    // Returns all of the user's staked santa IDs
    function stakedSantasOfOwner(address sender) public view returns (uint256[] memory stakedIDs, uint256 stakedCount)
    {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        uint256[] memory ownerSantaIDs = santaContract.tokensOfOwner(sender);
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
            uint256 secondsPassed = block.timestamp - santa.stakeBeginTime;
            return secondsPassed * (gainzPerDay / 86400);
        } else {
            return 0;
        }
    }

    // Returns the amount of $GAINZ earned by ALL Santas of the sender
    function viewAllEarnedGainz(address sender) public view returns (uint256) {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        uint256[] memory ownerSantaIDs = santaContract.tokensOfOwner(sender);
        require(ownerSantaIDs.length > 0 , "Sender has no Santas!");
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

    // Unstake santa and stop earning $GAINZ
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
   function takeRedPill(uint256 tokenId) external onlyAuthorized nonReentrant {
        RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
        StakedSantaObj memory santa = stakedSantas[tokenId];

        require(santa.strength > 0, "Santa is not staked!");
        require(santa.strength <= 300, "Santa is already at the max upgradeble tier");
        require(uint32(block.timestamp) >= santa.levelCoolDown, "Santa is on level cooldown");

        santa.pillsTaken++;
        uint256 currentStrength = santa.strength;

        if(currentStrength == 30) {              // common -> cool
            santa.strength  = 90;
        } else if(currentStrength == 90){       // cool -> rare
            santa.strength  = 200;
        } else if(currentStrength == 200){       // rare -> epic
            santa.strength  = 300;
        } else if(currentStrength == 300){       // epic -> legendary
            santa.strength  = 400;
        } 

        // Set the Cooldown end time
        santa.levelCoolDown = uint32(block.timestamp + LEVEL_COOLDOWN_PERIOD);

        // Update Santa parameters:
        stakedSantas[tokenId] = santa;
        
        // Update total global strength value
        totalStrengthAcquired += (santa.strength - currentStrength);

        // Finally Update the RedPillSanta contract
        santaContract.setStrength(tokenId, santa.strength);

        // Unleash the event
        emit TierUp(tokenId, currentStrength, santa.strength);
   }

    // Burns given amount of $GAINZ from given account
   function _burnGainz (address account, uint256 gainzAmount) internal {
       require(balanceOf(account) >= gainzAmount, "Not enough $GAINZ to burn!");
       _burn(account, gainzAmount);

       // Unleash the event
       emit GainzBurned(account, gainzAmount);
   }

   function burnGainz (address account, uint256 gainzAmount) external onlyAuthorized {
       _burnGainz(account, gainzAmount);
   }

   function TheAvalanchePrize() external nonReentrant {
       require(balanceOf(msg.sender) >= UNLOCK_AMOUNT, "NOT ENOUGH GAINZ TO CLAIM THE PRIZE");

       // Burn $GAINZ
       _burnGainz(msg.sender, UNLOCK_AMOUNT);

       // Transfer funds to the winner
       RedPillSanta santaContract = RedPillSanta(SANTA_CONTRACT);
       santaContract.fundTheWinner(payable(msg.sender));

   }

   function setUnlockAmount(uint256 newAmount) public onlyOwner {
       UNLOCK_AMOUNT = newAmount;
   } 

    function setLevelCooldown(uint256 value) external onlyOwner {
        LEVEL_COOLDOWN_PERIOD = value;
    }

    function setSantaContract(address _santaContract) public onlyOwner {
        SANTA_CONTRACT = _santaContract;
    }

    // Mint $GAINZ to holders
    // RPS contracts also call this
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
   function restoreUserGainz(uint256 _fromTokenId, uint256 _toTokenId) external onlyOwner {
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
