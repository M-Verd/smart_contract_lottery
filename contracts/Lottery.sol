// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract Lottery is ConfirmedOwner, VRFV2WrapperConsumerBase {
    // Creating an Enum to check current Lottery State
    enum LOTTERY_STATE {
        OPEN, //0
        CLOSED, //1
        CALCULATING_WINNER, //2
        EXTRACTED_WINNER //3
    }

    // Useful events to know if the random number request was sent and fullfilled
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );
    event WinnerExtracted(
        uint256 random_number,
        address winner,
        uint256 winner_index
    );

    // Lottery variables
    address payable[] private players;
    mapping(address => bool) is_player_in_game; // A mapping to check if a player is already in game
    address payable public recent_winner;
    uint256 private ENTRANCE_FEE = 30000000000000000;
    address private link_address;

    LOTTERY_STATE public lottery_state;
    AggregatorV3Interface private dataFeed;

    // Structs and variables to make VRF work properly
    uint32 private callbackGasLimit = 1000000;
    uint32 private numWords = 1;
    uint16 private requestConfirmations = 5;

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords; // Randomness produced by VRF
    }
    mapping(uint256 => RequestStatus) private s_requests; // requestId -> requestStatus
    uint256[] public requestIds;
    uint256 private lastRequestId;

    // Function constructor
    constructor(
        address _priceFeed,
        address _link,
        address _vrfWrapper
    ) VRFV2WrapperConsumerBase(_link, _vrfWrapper) ConfirmedOwner(msg.sender) {
        dataFeed = AggregatorV3Interface(_priceFeed);
        lottery_state = LOTTERY_STATE.CLOSED;
        link_address = _link;
    }

    // ------------------------------------------- UTILITIES

    // A function that returns ETH price in wei precision
    function getPrice() private view returns (uint256) {
        (, int256 answer, , , ) = dataFeed.latestRoundData();
        return (uint256(answer * (10 ** 10))); // Multiply by missing wei precision digits
    }

    // Returns the entrance Fee in USD expressed with 8 decimals
    function getEntranceFeeInUSD() public view returns (uint256) {
        uint256 precision = 10 ** 18;
        uint256 ethPrice = getPrice() / (10 ** 10);
        return ((ENTRANCE_FEE * ethPrice) / precision);
    }

    // Returns the entrance Fee in ETH
    function getEntranceFee() public view returns (uint256) {
        return (ENTRANCE_FEE);
    }

    // This getter will return the number of players in game
    function getPlayersNumber() public view returns (uint256) {
        return players.length;
    }

    // This one returns the random numbers requested by a specific RequestId
    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

    // Withdrawal of Link tokens from the contract
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(link_address);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    // Support function to request randomness (it returns the RequestId)
    function requestRandomWords()
        internal
        onlyOwner
        returns (uint256 requestId)
    {
        require(
            lottery_state == LOTTERY_STATE.OPEN,
            "Lottery isn't even open yet and you want to close it!"
        );
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;

        requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );

        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            fulfilled: false,
            randomWords: new uint256[](0)
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    // We need to override this function to make Chainlink VRF work properly
    // This function is called by the VRF coordinator once the randomness is proved and will extract the winner
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "We are not calculating the winner yet!"
        );

        // Save the VRF answer
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        // Emit event
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );

        // Calculate winner
        // Saving the random numbers
        uint256[] memory random_numbers = s_requests[lastRequestId].randomWords;

        // Calculating winner
        uint256 winner_index = random_numbers[0] % players.length;
        recent_winner = players[winner_index];

        emit WinnerExtracted(random_numbers[0], recent_winner, winner_index);

        // Transfer the balance to the winner
        recent_winner.transfer(address(this).balance);

        // Changing the lottery state to get it ready for a reset
        lottery_state = LOTTERY_STATE.EXTRACTED_WINNER;
    }

    // ------------------------------------------- MAIN FUNCTIONS

    // A function callable only by the owner that opens the game
    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't open a new lottery!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    // The function that allows a user to enter the game
    function enterLottery() public payable {
        require(lottery_state == LOTTERY_STATE.OPEN, "Lottery isn't open!");
        require(
            msg.value == ENTRANCE_FEE,
            "The Entrance Fee is not matching the required one!"
        );
        require(
            !is_player_in_game[msg.sender],
            "You already purchased a ticket!"
        );

        players.push(payable(msg.sender));
        is_player_in_game[msg.sender] = true;
    }

    // A function callable only by the owner that closes the game and select the winner randomly
    function endLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.OPEN,
            "Lottery is not open yet!"
        );
        if (players.length == 0) {
            lottery_state = LOTTERY_STATE.CLOSED;
        } else {
            requestRandomWords();
        }
    }

    function resetLottery(uint256 _players_number) public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.EXTRACTED_WINNER,
            "Lottery is not open yet!"
        );
        // Reset the players
        for (uint i = 0; i < _players_number; i++) {
            is_player_in_game[players[i]] = false;
        }
        players = new address payable[](0);

        // Reset the state
        lottery_state = LOTTERY_STATE.CLOSED;
    }
}
