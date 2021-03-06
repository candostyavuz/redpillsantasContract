// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./Authorizable.sol";

contract RedPillSanta is ERC721, ERC721Enumerable, Authorizable, ReentrancyGuard, IERC2981 {
    using Strings for uint256;

    // State Variables
    uint256 public constant MAX_SANTAS = 4000;
    string private _baseTokenURI;
    string public baseExtension = ".json";
    bool public paused = true;
    uint256 public mintPrice = 1.25 ether;  // 1.25 AVAX
    uint256 public wlMintPrice = 1 ether;   // 1 AVAX
    uint256 public _royaltyAmount = 50;     // 5% royalty
    uint256 public _belowFloorRoyaltyAmount = 250;     // 25% royalty

    uint256 public prizeDenominator = 16;    // Percentage of funds for the winner

    uint256[4000] public remainingTokens;
    uint256 public remainingSupply = MAX_SANTAS;
    uint256 public lastMintedTokenId;

    address payable private admin1;
    address payable private admin2;
    address payable private admin3;
    address payable private prizePoolWallet;

    uint256 public gameStartTime;
    bool public isGameActive = false;
    bool public isGameSessionActive = false;

    mapping (uint256 => uint256) public tokenStrength;

    // Free Mint
    mapping(address => uint256) public freeMintAddress;  // Mapping for giveaway winners and earned amount

    // Whitelist
    mapping(address => uint256) public whiteListAddress; // Mapping for whitelist winners and WL mint limit

    // Events
    event PrizePoolFunded(uint amount);
    event WinnerRewarded(address winner, uint256 amount);

    constructor(string memory _initBaseURI, address payable _admin1, address payable _admin2, address payable _admin3 , address payable _prizePoolWallet)
        ERC721("REDPILLSANTA", "REDPILLSANTA")
    {
        setBaseURI(_initBaseURI);
        setAdminAddress(_admin1, _admin2, _admin3,_prizePoolWallet);
    }

    function claimSanta(uint256 _amount) public payable nonReentrant {
        require(!paused, "Minting is paused!");
        require(msg.sender != address(0), "Address zero issue!");
        require(_amount > 0, "Mint amount cannot be zero!");
        require(msg.value >= mintPrice * _amount, "Insufficient funds");
        // require(remainingSupply >= _amount, "Amount exceeds the remaining supply!");
        require(_amount <= 20, "Max 20 Santas can be minted in one order!");

        uint256 mintAmount;
        if(_amount >= 5) {
            mintAmount = _amount + (_amount/5); 
        } else {
            mintAmount = _amount;
        }
        require(remainingSupply >= mintAmount, "Amount exceeds the remaining supply!");

        uint256 tokenId = lastMintedTokenId;
        for (uint256 i = 0; i < mintAmount; i++) {
            tokenId = _mintRandomID(msg.sender);
            setBaseStrength(msg.sender, tokenId);
        }
        lastMintedTokenId = tokenId;
        
        distributeMintFee(msg.value);
    }

    function whiteListMint(uint256 _amount) public payable nonReentrant {
        require(!paused, "Minting is paused!");
        require(msg.sender != address(0), "Address zero issue!");
        require(_amount > 0, "Mint amount cannot be zero!");
        require(msg.value >= wlMintPrice * _amount, "Insufficient funds, ngmi.");
        // require(remainingSupply >= _amount, "Amount exceeds the remaining supply!");
        require(whiteListAddress[msg.sender] >= _amount, "Amount exceeds user's whitelist minting limit!");

        uint256 mintAmount;
        if(_amount >= 5) {
            mintAmount = _amount + (_amount/5); 
        } else {
            mintAmount = _amount;
        }

        require(remainingSupply >= mintAmount, "Amount exceeds the remaining supply!");

        uint256 tokenId = lastMintedTokenId;
        for (uint256 i = 0; i < mintAmount; i++) {
            tokenId = _mintRandomID(msg.sender);
            setBaseStrength(msg.sender, tokenId);
        }
        lastMintedTokenId = tokenId;

        distributeMintFee(msg.value);

        whiteListAddress[msg.sender] = whiteListAddress[msg.sender] - (_amount);
    }

    function freeMint(uint256 _amount) public nonReentrant {
        require(!paused, "Minting is paused!");
        require(msg.sender != address(0), "Address zero issue!");
        require(_amount > 0, "Mint amount cannot be zero!");
        require(freeMintAddress[msg.sender] >= _amount, "Amount exceeds user's free mint limit!");
        require(remainingSupply >= _amount, "Amount exceeds the remaining supply!");

        uint256 tokenId = lastMintedTokenId;
        for (uint256 i = 0; i < _amount; i++) {
            tokenId = _mintRandomID(msg.sender);
            setBaseStrength(msg.sender, tokenId);
        }
        lastMintedTokenId = tokenId;

        freeMintAddress[msg.sender] = freeMintAddress[msg.sender] - (_amount);
    }

    function distributeMintFee(uint256 _fee) private {
        uint256 poolShare = (_fee * 60)/100;    // 60% of fees are added into the prize pool
        (prizePoolWallet).transfer(poolShare);

        uint256 perMemberShare = (_fee - poolShare)/3;
        (admin1).transfer(perMemberShare);
        (admin2).transfer(perMemberShare);
        (admin3).transfer(perMemberShare);
    }

    function _mintRandomID(address _to) internal returns (uint256) {
        uint256 _idx = _getEnoughRandom();
        uint256 _uniqueId = _getTokenId(_idx);
        remainingSupply--;
        remainingTokens[_idx] = _getTokenId(remainingSupply);
        _safeMint(_to, _uniqueId);
        return _uniqueId;
    }

    function _getTokenId(uint256 _idx) internal view returns (uint256) {
        if (remainingTokens[_idx] == 0) {
            return _idx;
        } else {
            return remainingTokens[_idx];
        }
    }

    /**
     * @dev Pseudo-random number generator
     * If you are determined to exploit this, you deserve the rare Santas TBH
     */
    function _getEnoughRandom() internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            ) % remainingSupply;
    }

    function setBaseStrength(address minter, uint256 tokenId) internal {
         require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        require ( minter == ownerOf(tokenId), "You are not the owner of this NFT");

        if(tokenId >= 0 && tokenId < 13) {               // unique
            tokenStrength[tokenId] = 500;
        } else if(tokenId >= 13 && tokenId < 1532){      // common
            tokenStrength[tokenId] = 30;
        } else if(tokenId >= 1532 && tokenId < 2807){    // cool
            tokenStrength[tokenId] = 90;
        } else if(tokenId >= 2807 && tokenId < 3604){    // rare
            tokenStrength[tokenId] = 200;
        } else if(tokenId >= 3604 && tokenId < 3922){    // epic
            tokenStrength[tokenId] = 300;
        } else if (tokenId >= 3922 && tokenId < 4000) {  // legendary
            tokenStrength[tokenId] = 400;
        } else {                                            // ERROR CONDITION!
            tokenStrength[tokenId] = 0;
        }
    }

    function tokensOfOwner(address _owner) public view returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)): "";
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount){
        if(salePrice <= mintPrice) {
            return (prizePoolWallet, salePrice * (_belowFloorRoyaltyAmount)/1000);
        } else {
            if(tokenId >= 0 && tokenId < 13) {
                return (prizePoolWallet, salePrice * (_royaltyAmount+10)/1000);
            } else {
                return (prizePoolWallet, salePrice * (_royaltyAmount)/1000);
            }
        }
    }

    function whitelistLeft(address user) public view returns(uint256){
        return whiteListAddress[user];
    }

    function freeMintLeft(address user) public view returns(uint256){
        return freeMintAddress[user];
    }

    // Only Owner functions
    function setWhitelist(address[] calldata _wallets) external onlyOwner {
        for (uint i = 0; i < _wallets.length; i++) {
            whiteListAddress[_wallets[i]] = 5;
        }
    }

    function setFreeMint(address _wallet, uint256 _amount) external onlyOwner {
        freeMintAddress[_wallet] += _amount;
    }

    function setRoyaltyAmount(uint256 number, uint256 belowFloorNumber) external onlyOwner {
        _royaltyAmount = number;
        _belowFloorRoyaltyAmount = belowFloorNumber;
    }
    
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        _baseTokenURI = _newBaseURI;
    }

    function setPrice(uint _newPrice) external onlyOwner {
        mintPrice = _newPrice;
    }
    function setWLPrice(uint _newPrice) external onlyOwner {
        wlMintPrice = _newPrice;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setBaseExtension(string memory _baseExtension) external onlyOwner {
        baseExtension = _baseExtension;
    }

    function setAdminAddress (address payable _admin1, address payable _admin2, address payable _admin3, address payable _prizePoolWallet) public onlyOwner {
        admin1 = _admin1;
        admin2 = _admin2;
        admin3 = _admin3;
        prizePoolWallet = _prizePoolWallet;
    }

    function setGameActive (bool _state) public onlyOwner {
        isGameActive = _state;
        gameStartTime = block.timestamp;
    }

    function setGameSessionActive (bool _state) public onlyOwner {
        isGameSessionActive = _state;
    }

    function setPrizeDenominatr(uint256 _denominator) external onlyOwner {
        prizeDenominator = _denominator;
    }

    function fundTheWinner (address payable winner) external onlyAuthorized {
        require(isGameActive == true, "Game is not active!");
        require(isGameSessionActive == true, "Game session is not active!");
        require(address(this).balance >= 0.5 ether, "No funds!");
        require(msg.sender != address(0), "address 0 issue");

        uint256 prize = address(this).balance / prizeDenominator;

        if(prize <= 0.5 ether){
            (winner).transfer(0.5 ether);
        } else {
            (winner).transfer(prize);
        }

        emit WinnerRewarded(winner, prize);
    }

    function viewCurrentPrizePool() public view returns (uint256) {
        return address(this).balance;
    }

    // Will be used to add funds into the Prize Pool
    function addFunds() public payable onlyAuthorized {
        emit PrizePoolFunded(msg.value);
    }

    function setStrength(uint256 tokenId, uint256 _newStrength) external onlyAuthorized {
        require(isGameActive == true, "Game is not active!");
        require(_newStrength <= 400, "Maximum upgradable strength is 400!");
        tokenStrength[tokenId] = _newStrength;
    }

    function withdraw() external onlyOwner {
        require(address(this).balance != 0, "no funds");
        payable(msg.sender).transfer(address(this).balance);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

}
