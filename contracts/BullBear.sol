// SPDX-License-Identifier: MIT

// Contract Address: 0x4F67565203902E335Dcd20AD44870c6Ff39c923c
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// Chainlink Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

// Dev imports
import "hardhat/console.sol";

contract BullBear is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Ownable,
    KeeperCompatibleInterface,
    VRFConsumerBaseV2
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256 public interval; // interval the keeper are gonna call and execute the contract
    uint256 public lastTimeStamp;

    //To call the price feed data from chainlink
    AggregatorV3Interface public priceFeed;
    int256 public currentPrice;

    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // Rinkeby coordinator.
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    bytes32 keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    uint32 callbackGasLimit = 500000;
    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 1 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;

    uint256 public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    // IPFS URIs for the dynamic nft graphics/metadata.
    // NOTE: These connect to my IPFS Companion node.
    // You should upload the contents of the /ipfs folder to your own node for development.

    string[] bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];

    string[] bearUrisIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    event TokensUpdated(string marketTrend);

    // For testing with the mock on Rinkeby, pass in 10(seconds) for `updateInterval` and the address of my
    // deployed  MockPriceFeed.sol contract (0xD753A1c190091368EaC67bbF3Ee5bAEd265aC420).
    constructor(uint256 updateInterval, uint64 subscriptionId)
        ERC721("Bull&Bear", "BBTK")
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;

        interval = updateInterval; // la variable que actualiza cada cuanto tiempo el keeper llama al contrato
        lastTimeStamp = block.timestamp; // tomamos el tiempo desde el momento en que se implementa el contrato

        /**
         * Network: Rinkeby
         * Data Feed: BTC/USD
         * Address: 0xECe365B379E1dD183B20fc5f022230C044d51404
         */
        priceFeed = AggregatorV3Interface(
            0xECe365B379E1dD183B20fc5f022230C044d51404
        );

        // set the price for the chosen currency pair. en cuanto creamos el contrato debemos obtener el primer precio.
        currentPrice = getLatestPrice();
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() internal {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        console.log("Request ID: ", s_requestId);
        console.log(" random number call");
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords[0] % 3;
        console.log(" random number fulFill");
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        string memory defaultUri = bullUrisIpfs[0]; //llamamos por default al primer elemento de arreglo de imagines
        _setTokenURI(tokenId, defaultUri);
    }

    // function needed for the keeper
    function checkUpkeep(
        bytes calldata /*checkData*/
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /*performData*/
        )
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(
        bytes calldata /*performData*/
    ) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            int256 lastestPrice = getLatestPrice();

            if (lastestPrice == currentPrice) {
                console.log("NO CHANGE -> returning!");
                return;
            }

            if (lastestPrice < currentPrice) {
                console.log("It's Bear Time");
                updateAllTokenUris("bear");
            }

            if (lastestPrice > currentPrice) {
                console.log("It's Bull Time");
                updateAllTokenUris("Bull");
            }
            // generamos el numero random
            requestRandomWords();
            console.log("after random number en performUpkeep");
            // update currentPrice
            currentPrice = lastestPrice;
        }
        console.log("No entro al primer condicional de performUpkeep");
    }

    //consuming the price of chainlink oracle
    function getLatestPrice() public view returns (int256) {
        (
            ,
            /*uint80 roundID*/
            int256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();

        return price;
    }

    function updateAllTokenUris(string memory trend) internal {
        if (compareString("bear", trend)) {
            for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
                _setTokenURI(i, bearUrisIpfs[s_randomWords]);
            }
        } else {
            for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
                _setTokenURI(i, bullUrisIpfs[s_randomWords]);
            }
        }

        emit TokensUpdated(trend);
    }

    function setInterval(uint256 newInterval) public onlyOwner {
        interval = newInterval;
    }

    function setPriceFeed(address newFeed) public onlyOwner {
        priceFeed = AggregatorV3Interface(newFeed);
    }

    function compareString(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked(a)) ==
            keccak256(abi.encodePacked(b)));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
