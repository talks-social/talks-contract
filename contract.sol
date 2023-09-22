// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract Test {
    uint256 public chatCount;
    uint256 public offerCount;
    address public immutable owner;
    address public royaltyAddress1;
    address public royaltyAddress2;
    uint256 public serviceFeePercentage;
    mapping(uint256 => Chat) public chats;
    mapping(uint256 => Offer) public offers;
    mapping(address => uint256[]) public chatsByCreator;
    mapping(address => uint256[]) public offersByUser;

    enum OfferType {
        Buy,
        Sell
    }

    struct Chat {
        address creator;
        string name;
        uint256 entryPrice;
        uint256 capacity;
        uint256 royaltyPercentage;
        uint256 lastTransaction;
        uint256 totalTicketsCount;
        uint256 maxTicketsCountPerMember;
        bool isRefunded;
        mapping(address => uint256) membersTicketsCount;
    }

    struct Offer {
        uint256 chatIndex;
        OfferType offerType;
        uint256 ticketsCount;
        uint256 price;
        address creator;
        bool isActive;
    }

    event ChatCreated(
        address indexed creator,
        uint256 indexed chatIndex,
        string name
    );
    event OfferCreated(
        uint256 indexed offerIndex,
        uint256 chatIndex,
        OfferType offerType,
        uint256 ticketsCount,
        uint256 price,
        address indexed creator
    );
    event OfferAccepted(
        uint256 indexed offerIndex,
        uint256 chatIndex,
        OfferType offerType,
        uint256 ticketsCount,
        uint256 price,
        address indexed creator,
        address buyer
    );
    event OfferCancelled(
        uint256 indexed offerIndex,
        uint256 chatIndex,
        OfferType offerType,
        uint256 ticketsCount,
        uint256 price,
        address indexed creator
    );
    event TicketsBought(
        uint256 chatIndex,
        uint256 ticketsCount,
        uint256 totalPrice,
        address indexed buyer
    );
    event TicketsReturned(
        uint256 chatIndex,
        uint256 ticketsCount,
        uint256 refundAmount,
        address indexed member
    );
    event PoolFundsReturned(
        uint256 chatIndex,
        uint256 refundAmount,
        address indexed chatCreator
    );
    event ServiceFeeChanged(uint256 newPercentage);
    event ChatRoyaltyChanged(uint256 chatIndex, uint256 newPercentage);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier onlyChatCreator(uint256 _chatIndex) {
        require(chats[_chatIndex].creator == msg.sender, "Not a chat creator");
        _;
    }

    modifier onlyActiveOffer(uint256 _offerId) {
        require(offers[_offerId].isActive, "Offer is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        serviceFeePercentage = 500; // 5%
    }

    receive() external payable {}

    function getChatIdsByCreatorAddress(address _address)
        external
        view
        returns (uint256[] memory)
    {
        return chatsByCreator[_address];
    }

    function getOfferIdsByCreatorAddress(address _address)
        external
        view
        returns (uint256[] memory)
    {
        return offersByUser[_address];
    }

    function hasAccessToChat(uint256 _chatIndex, address _member)
        external
        view
        returns (bool)
    {
        Chat storage chat = chats[_chatIndex];
        if (_member == chat.creator) {
            return true;
        }
        return chat.membersTicketsCount[_member] > 0;
    }

    /**
     * @dev Sets the royalty addresses for the contract.
     *
     * This function allows the contract owner to set two royalty addresses.
     * Only the contract owner can call this function.
     *
     * @param _royaltyAddress1 The address of the first royalty recipient.
     * @param _royaltyAddress2 The address of the second royalty recipient.
     */
    function setRoyaltyAddresses(
        address _royaltyAddress1,
        address _royaltyAddress2
    ) external onlyOwner {
        royaltyAddress1 = _royaltyAddress1;
        royaltyAddress2 = _royaltyAddress2;
    }

    /**
     * @dev Sets the service fee percentage for the contract.
     *
     * This function allows the contract owner to set the service fee percentage, which
     * represents a percentage of the transaction amount to be charged as a fee.
     * The percentage must be between 0 and 10% (inclusive).
     * Only the contract owner can call this function.
     *
     * Emits a `ServiceFeeChanged` event with the new service fee percentage.
     *
     * @param _percentage The new service fee percentage to be set.
     */
    function setServiceFee(uint256 _percentage) external onlyOwner {
        require(
            _percentage <= 1000,
            "Royalty percentage must be between 0 and 10%"
        );
        serviceFeePercentage = _percentage;
        emit ServiceFeeChanged(_percentage);
    }

    /**
     * @dev Creates a new chat room.
     *
     * This function allows any user to create a new chat room with specified parameters.
     * The chat room's name, entry price, maximum tickets per member, capacity, and royalty
     * percentage are set during creation.
     *
     * Requirements:
     * - The capacity must be greater than 0.
     * - The royalty percentage must be between 0 and 10% (inclusive).
     * - The maximum tickets per member must be greater than 0.
     *
     * Effects:
     * - A new chat room is created and added to the `chats` mapping.
     * - The caller's address is associated with the chat room in the `chatsByCreator` mapping.
     * - Emits a `ChatCreated` event with information about the newly created chat room.
     *
     * @param _name The name of the chat room.
     * @param _entryPrice The entry price for the chat room.
     * @param _maxTicketsCountPerMember The maximum number of tickets each member can purchase.
     * @param _capacity The maximum capacity of the chat room.
     * @param _royaltyPercentage The percentage of royalties to be collected from ticket sales.
     */
    function createChat(
        string memory _name,
        uint256 _entryPrice,
        uint256 _maxTicketsCountPerMember,
        uint256 _capacity,
        uint256 _royaltyPercentage
    ) external {
        require(_capacity > 0, "Number of talkers must be more than 0");
        require(
            _royaltyPercentage <= 1000,
            "Royalty percentage must be between 0 and 10%"
        );
        require(
            _maxTicketsCountPerMember > 0,
            "Max tickets per member must be more than 0"
        );

        Chat storage newChat = chats[chatCount];
        newChat.creator = msg.sender;
        newChat.name = _name;
        newChat.entryPrice = _entryPrice;
        newChat.capacity = _capacity;
        newChat.royaltyPercentage = _royaltyPercentage;
        newChat.maxTicketsCountPerMember = _maxTicketsCountPerMember;

        chatsByCreator[msg.sender].push(chatCount);
        emit ChatCreated(msg.sender, chatCount, _name);

        chatCount++;
    }

    /**
     * @dev Sets the royalty percentage for a specific chat room.
     *
     * This function allows the creator of a chat room to change its royalty percentage.
     *
     * Requirements:
     * - The caller must be the creator of the specified chat room.
     * - The new royalty percentage must be between 0 and 10% (inclusive).
     *
     * Effects:
     * - Updates the royalty percentage for the specified chat room.
     * - Emits a `ChatRoyaltyChanged` event with information about the updated royalty percentage.
     *
     * @param _chatIndex The index of the chat room to update.
     * @param _percentage The new royalty percentage to be set for the chat room.
     */
    function setChatRoyalty(uint256 _chatIndex, uint256 _percentage)
        external
        onlyChatCreator(_chatIndex)
    {
        Chat storage chat = chats[_chatIndex];
        require(
            _percentage <= 1000,
            "Royalty percentage must be between 0 and 10%"
        );
        chat.royaltyPercentage = _percentage;
        emit ChatRoyaltyChanged(_chatIndex, _percentage);
    }

    /**
     * @dev Allows a user to purchase tickets for a chat room.
     *
     * This function allows a user to buy a specified number of tickets for a chat room by
     * sending the correct payment. The payment amount must match the entry price multiplied
     * by the number of tickets being purchased.
     *
     * Requirements:
     * - The number of tickets must be 1 or more.
     * - The payment amount must be correct and match the entry price times the number of tickets.
     * - The chat must have available capacity for the requested number of tickets.
     * - The user must not exceed the maximum number of tickets per member.
     * - The payment is split into three parts: service fee, payment to the contract, and payment to the chat creator.
     *
     * Effects:
     * - Deducts the service fee from the payment.
     * - Splits the remaining payment into two equal parts, sending one part to the contract and one part to the chat creator.
     * - Updates the total ticket count for the chat room and the user's ticket count.
     * - Records the timestamp of the last transaction.
     * - Emits a `TicketsBought` event with information about the purchase.
     *
     * @param _chatIndex The index of the chat room where tickets are being purchased.
     * @param _ticketsCount The number of tickets to purchase.
     */
    function buyTickets(uint256 _chatIndex, uint256 _ticketsCount)
        external
        payable
    {
        require(_ticketsCount >= 1, "Tickets count must be 1 or more");
        Chat storage chat = chats[_chatIndex];
        require(
            msg.value == chat.entryPrice * _ticketsCount,
            "Incorrect payment amount"
        );
        require(
            chat.totalTicketsCount + _ticketsCount <= chat.capacity,
            "Chat is full"
        );
        require(
            chat.membersTicketsCount[msg.sender] + _ticketsCount <=
                chat.maxTicketsCountPerMember,
            "Max tickets per user restriction"
        );
        uint256 serviceFee = getFeeValue(
            chat.entryPrice * _ticketsCount,
            serviceFeePercentage
        );
        uint256 part = (_ticketsCount * chat.entryPrice - serviceFee) / 2;
        require(
            part + part + serviceFee <= msg.value,
            "Value split calculation error"
        );
        _payFee(serviceFee);
        (bool success1, ) = address(this).call{value: part}("");
        (bool success2, ) = chat.creator.call{value: part}("");
        require(success1 && success2, "Unable to send funds");
        chat.totalTicketsCount += _ticketsCount;
        chat.membersTicketsCount[msg.sender] += _ticketsCount;
        chat.lastTransaction = block.timestamp;
        emit TicketsBought(_chatIndex, _ticketsCount, msg.value, msg.sender);
    }

    /**
     * @dev Allows a user to return purchased tickets for a chat room.
     *
     * This function allows a user to return a specified number of purchased tickets for a chat room.
     * The returned tickets will be available for sale again. The user receives a refund for the returned
     * tickets, minus a service fee.
     *
     * Requirements:
     * - The chat room must not be at full capacity.
     * - The user must have the specified number of tickets to return.
     * - The user's tickets in active sell offers must not exceed the specified number of tickets to return.
     *
     * Effects:
     * - Decreases the user's ticket count for the chat room.
     * - Decreases the total ticket count for the chat room.
     * - Deducts a service fee from the refund amount.
     * - Sends the remaining refund amount to the user.
     * - Emits a `TicketsReturned` event with information about the returned tickets and refund.
     *
     * @param _chatIndex The index of the chat room from which tickets are being returned.
     * @param _ticketsCount The number of tickets to return.
     */
    function returnTickets(uint256 _chatIndex, uint256 _ticketsCount) external {
        Chat storage chat = chats[_chatIndex];
        require(
            chat.totalTicketsCount < chat.capacity,
            "Cannot leave a full chat"
        );
        address payable memberAddress = payable(msg.sender);
        uint256 ticketsInOffers = getTotalTicketsCountForMemberInSellOffers(
            msg.sender,
            _chatIndex
        );
        require(
            (ticketsInOffers + _ticketsCount) <=
                chat.membersTicketsCount[msg.sender],
            "Not enough tickets, try to cancel offers if they are"
        );
        uint256 serviceFee = getFeeValue(
            chat.entryPrice * _ticketsCount,
            serviceFeePercentage
        );
        uint256 part = (_ticketsCount * chat.entryPrice - serviceFee) / 2;
        uint256 serviceFeeOnReturn = getFeeValue(part, serviceFeePercentage);
        uint256 refundAmount = part - serviceFeeOnReturn;
        chat.membersTicketsCount[msg.sender] -= _ticketsCount;
        chat.totalTicketsCount -= _ticketsCount;
        _payFee(serviceFeeOnReturn);
        (bool success, ) = memberAddress.call{value: refundAmount}("");
        require(success, "Unable to send funds");
        emit TicketsReturned(
            _chatIndex,
            _ticketsCount,
            refundAmount,
            msg.sender
        );
    }

    /**
     * @dev Creates a new offer for buying or selling chat room tickets.
     *
     * This function allows a user to create a new offer for buying or selling a specified number
     * of chat room tickets at a given price. The user must provide the correct payment for a buy offer.
     *
     * Requirements:
     * - The number of tickets must be greater than 0.
     * - For sell offers, the user must have enough tickets to sell.
     * - For sell offers, the total tickets in active sell offers must not exceed the user's ticket count.
     * - For buy offers, the payment amount must match the total ticket price.
     *
     * Effects:
     * - Creates a new offer and stores it in the `offers` mapping.
     * - Associates the offer with the user in the `offersByUser` mapping.
     * - Emits an `OfferCreated` event with information about the new offer.
     *
     * @param _chatIndex The index of the chat room associated with the offer.
     * @param _offerType The type of the offer, either `OfferType.Sell` or `OfferType.Buy`.
     * @param _ticketsCount The number of tickets being bought or sold.
     * @param _price The price per ticket for the offer (for buy offers) or the total price (for sell offers).
     */
    function createOffer(
        uint256 _chatIndex,
        OfferType _offerType,
        uint256 _ticketsCount,
        uint256 _price
    ) external payable {
        require(_ticketsCount > 0, "Tickets count must be greater than 0");
        uint256 memberTicketCount = getMemberTicketsCount(
            _chatIndex,
            msg.sender
        );
        if (_offerType == OfferType.Sell) {
            require(
                _ticketsCount <= memberTicketCount,
                "Tickets count must be greater than you have"
            );
            uint256 ticketsInOffers = getTotalTicketsCountForMemberInSellOffers(
                msg.sender,
                _chatIndex
            );
            require(
                ticketsInOffers + _ticketsCount <= memberTicketCount,
                "Not enough tickets available for selling"
            );
        }
        if (_offerType == OfferType.Buy) {
            require(
                _ticketsCount * _price == msg.value,
                "Incorrect payment amount"
            );
        }
        Offer memory newOffer = Offer({
            chatIndex: _chatIndex,
            offerType: _offerType,
            ticketsCount: _ticketsCount,
            price: _price,
            creator: msg.sender,
            isActive: true
        });
        offersByUser[msg.sender].push(offerCount);
        offers[offerCount] = newOffer;
        emit OfferCreated(
            offerCount,
            _chatIndex,
            _offerType,
            _ticketsCount,
            _price,
            msg.sender
        );
        offerCount++;
    }

    /**
     * @dev Accepts an offer to buy or sell chat room tickets.
     *
     * This function allows a user to accept an existing offer to buy or sell a specified number
     * of chat room tickets. The appropriate payment or refund is handled based on the offer type.
     *
     * Requirements:
     * - The offer must be active, not yet accepted.
     * - The number of tickets to accept must be greater than zero and not exceed the offer's ticket count.
     * - The user cannot accept their own offer.
     * - For buy offers, the user must have enough tickets to sell.
     * - For sell offers, the payment amount must match the offer's total price.
     *
     * Effects:
     * - Handles payments, refunds, and updates for both buy and sell offers.
     * - Deducts service fees and royalties as appropriate.
     * - Updates the status of the offer (active or inactive) if all tickets are accepted.
     * - Emits an `OfferAccepted` event with information about the accepted offer.
     *
     * @param _offerId The unique identifier of the offer being accepted.
     * @param _ticketsCount The number of tickets to accept from the offer.
     */
    function acceptOffer(uint256 _offerId, uint256 _ticketsCount)
        external
        payable
        onlyActiveOffer(_offerId)
    {
        Offer storage offer = offers[_offerId];
        Chat storage chat = chats[offer.chatIndex];
        uint256 totalPrice = offer.price * _ticketsCount;
        require(_ticketsCount > 0, "Tickets count must be more than zero");
        require(offer.ticketsCount >= _ticketsCount, "Offer has less tickets");
        require(offer.ticketsCount > 0, "Offer has already been accepted");
        require(
            msg.sender != offer.creator,
            "Creator cannot accept their own offer"
        );
        uint256 serviceFee = getFeeValue(totalPrice, serviceFeePercentage);
        uint256 chatRoyalty = getFeeValue(totalPrice, chat.royaltyPercentage);
        uint256 priceWithoutFees = totalPrice - chatRoyalty - serviceFee;

        if (offer.ticketsCount - _ticketsCount == 0) {
            offer.isActive = false;
        }
        if (offer.offerType == OfferType.Buy) {
            require(
                chat.membersTicketsCount[msg.sender] >= _ticketsCount,
                "No tickets on this address"
            );
            chat.membersTicketsCount[offer.creator] += _ticketsCount;
            chat.membersTicketsCount[msg.sender] -= _ticketsCount;
            offer.ticketsCount -= _ticketsCount;
            (bool success, ) = msg.sender.call{value: priceWithoutFees}("");
            require(success, "Unable to send funds");
        }
        if (offer.offerType == OfferType.Sell) {
            require(msg.value == totalPrice, "Incorrect payment amount");
            chat.membersTicketsCount[offer.creator] -= _ticketsCount;
            chat.membersTicketsCount[msg.sender] += _ticketsCount;
            offer.ticketsCount -= _ticketsCount;
            (bool success, ) = offer.creator.call{value: priceWithoutFees}("");
            require(success, "Unable to send funds");
        }
        _payFee(serviceFee);

        (bool successCreator, ) = chat.creator.call{value: chatRoyalty}("");
        require(successCreator, "Unable to send funds");
        emit OfferAccepted(
            _offerId,
            offer.chatIndex,
            offer.offerType,
            _ticketsCount,
            offer.price,
            offer.creator,
            msg.sender
        );
    }

    /**
     * @dev Cancels an active offer to buy or sell chat room tickets.
     *
     * This function allows the creator of an active offer to cancel it. For buy offers,
     * any funds reserved for the offer are refunded to the creator.
     *
     * Requirements:
     * - The offer must be active, not yet accepted.
     * - Only the creator of the offer can cancel it.
     * - For buy offers, the reserved funds are refunded to the creator.
     *
     * Effects:
     * - Cancels the offer and marks it as inactive.
     * - Refunds reserved funds to the creator for buy offers.
     * - Emits an `OfferCancelled` event with information about the cancelled offer.
     *
     * @param _offerId The unique identifier of the offer to cancel.
     */
    function cancelOffer(uint256 _offerId) external onlyActiveOffer(_offerId) {
        Offer storage offer = offers[_offerId];
        require(
            msg.sender == offer.creator,
            "Only the creator can cancel the offer"
        );
        if (offer.offerType == OfferType.Buy) {
            (bool success, ) = offer.creator.call{
                value: offer.ticketsCount * offer.price
            }("");
            require(success, "Unable to send funds");
        }
        offer.ticketsCount = 0;
        offer.isActive = false;
        emit OfferCancelled(
            _offerId,
            offer.chatIndex,
            offer.offerType,
            offer.ticketsCount,
            offer.price,
            msg.sender
        );
    }

    /**
     * @dev Returns the pool funds to the chat room creator.
     *
     * This function allows the creator of a chat room to retrieve the pool funds if certain conditions are met.
     * The chat room must be full, not previously refunded, and a specific time period must have elapsed
     * since the last transaction within the chat room.
     *
     * Requirements:
     * - The chat room must be full to return funds.
     * - The chat room must not have been refunded previously.
     * - A minimum of 30 days must have passed since the chat room was sold out.
     *
     * Effects:
     * - Marks the chat room as refunded.
     * - Deducts the service fee from the pool funds.
     * - Sends the remaining refund amount to the chat room creator.
     * - Emits a `PoolFundsReturned` event with information about the returned funds.
     *
     * @param _chatIndex The index of the chat room for which pool funds are being returned.
     */
    function returnPoolFunds(uint256 _chatIndex)
        external
        onlyChatCreator(_chatIndex)
    {
        Chat storage chat = chats[_chatIndex];
        require(
            chat.totalTicketsCount >= chat.capacity,
            "Chat is not full to return funds"
        );
        require(!chat.isRefunded, "Chat was refunded");
        require(
            block.timestamp > (chat.lastTransaction + 30 days),
            "Can return funds in a month after sold out"
        );
        chat.isRefunded = true;
        uint256 serviceFee = getFeeValue(
            chat.entryPrice * chat.totalTicketsCount,
            serviceFeePercentage
        );
        uint256 part = (chat.totalTicketsCount * chat.entryPrice - serviceFee) /
            2;
        uint256 serviceFeeOnReturn = getFeeValue(part, serviceFeePercentage);
        uint256 refundAmount = part - serviceFeeOnReturn;
        _payFee(serviceFeeOnReturn);
        (bool success, ) = chat.creator.call{value: refundAmount}("");
        require(success, "Unable to send funds");
        emit PoolFundsReturned(_chatIndex, refundAmount, msg.sender);
    }

    function getMemberTicketsCount(uint256 _chatId, address _memberAddress)
        public
        view
        returns (uint256)
    {
        return chats[_chatId].membersTicketsCount[_memberAddress];
    }

    function getFeeValue(uint256 _price, uint256 _percentage)
        public
        pure
        returns (uint256 royaltyAmount)
    {
        royaltyAmount = (_price * _percentage) / 10000;
    }

    function getTotalTicketsCountForMemberInSellOffers(
        address _member,
        uint256 _chatIndex
    ) public view returns (uint256) {
        uint256 totalTicketsCount;
        for (uint256 i = 0; i < offersByUser[_member].length; i++) {
            uint256 offerId = offersByUser[_member][i];
            Offer storage offer = offers[offerId];
            if (
                offer.isActive &&
                offer.chatIndex == _chatIndex &&
                offer.offerType == OfferType.Sell
            ) {
                totalTicketsCount += offer.ticketsCount;
            }
        }
        return totalTicketsCount;
    }

    function _payFee(uint256 _amount) private {
        if (_amount > 0) {
            uint256 royaltyAmount = _amount / 2;
            (bool success1, ) = royaltyAddress1.call{value: royaltyAmount}("");
            (bool success2, ) = royaltyAddress2.call{value: royaltyAmount}("");
            require(success1 && success2, "Unable to send funds");
        }
    }
}
