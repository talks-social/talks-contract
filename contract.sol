// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

contract Test {
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

    uint256 public chatCount;
    uint256 public offerCount;

    mapping(uint256 => Chat) public chats;
    mapping(uint256 => Offer) public offers;
    mapping(address => uint256[]) public chatsByCreator;
    mapping(address => uint256[]) public offersByUser;

    address public owner;
    address public royaltyAddress1;
    address public royaltyAddress2;
    uint256 public serviceFeePercentage;

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

    constructor() {
        owner = msg.sender;
        serviceFeePercentage = 500; // 5%
    }

    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

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
        return royaltyAmount = (_price * _percentage) / 10000;
    }

    function hasAccessToChat(uint256 _chatIndex, address _member) public view returns (bool) {
        Chat storage chat = chats[_chatIndex];
        if (_member == chat.creator) {
            return true;
        }
        return chat.membersTicketsCount[_member] > 0;
    }

    function setRoyaltyAddresses(
        address _royaltyAddress1,
        address _royaltyAddress2
    ) public onlyOwner {
        royaltyAddress1 = _royaltyAddress1;
        royaltyAddress2 = _royaltyAddress2;
    }

    function setServiceFee(uint256 _percentage) public onlyOwner {
        require(
            _percentage <= 1000,
            "Royalty percentage must be between 0 and 10%"
        );
        serviceFeePercentage = _percentage;
    }

    function payFee(uint256 _amount) private {
        if (_amount > 0) {
            uint256 royaltyAmount = _amount / 2;
            payable(royaltyAddress1).transfer(royaltyAmount);
            payable(royaltyAddress2).transfer(royaltyAmount);
        }
    }

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

    function setChatRoyalty(uint256 _chatIndex, uint256 _percentage) public {
        Chat storage chat = chats[_chatIndex];
        require(chat.creator == msg.sender, "Not a chat creator");
        require(
            _percentage <= 1000,
            "Royalty percentage must be between 0 and 10%"
        );
        chat.royaltyPercentage = _percentage;
    }

    function buyTickets(uint256 _chatIndex, uint256 _ticketsCount)
        public
        payable
    {
        require(_ticketsCount >= 1, "Tickets count must be 1 or more");
        Chat storage chat = chats[_chatIndex];
        require(
            msg.value >= chat.entryPrice * _ticketsCount,
            "Insufficient funds to join chat"
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
        payable(address(this)).transfer(part);
        payable(chat.creator).transfer(part);
        payFee(serviceFee);
        chat.totalTicketsCount += _ticketsCount;
        chat.membersTicketsCount[msg.sender] += _ticketsCount;
        chat.lastTransaction = block.timestamp;
        emit TicketsBought(_chatIndex, _ticketsCount, msg.value, msg.sender);
    }

    function returnTickets(uint256 _chatIndex, uint256 _ticketsCount) public {
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
        payFee(serviceFeeOnReturn);
        memberAddress.transfer(refundAmount);
        emit TicketsReturned(
            _chatIndex,
            _ticketsCount,
            refundAmount,
            msg.sender
        );
    }

    function getTotalTicketsCountForMemberInSellOffers(
        address _member,
        uint256 _chatIndex
    ) public view returns (uint256) {
        uint256 totalTicketsCount = 0;
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
                _ticketsCount * _price <= msg.value,
                "Insufficient payment for buying tickets"
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

    function acceptOffer(uint256 _offerId, uint256 _ticketsCount)
        external
        payable
    {
        Offer storage offer = offers[_offerId];
        Chat storage chat = chats[offer.chatIndex];
        uint256 totalPrice = offer.price * _ticketsCount;
        require(offer.isActive, "Offer is not active");
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
            payable(msg.sender).transfer(priceWithoutFees);
        }
        if (offer.offerType == OfferType.Sell) {
            require(msg.value >= totalPrice, "Incorrect payment amount");
            chat.membersTicketsCount[offer.creator] -= _ticketsCount;
            chat.membersTicketsCount[msg.sender] += _ticketsCount;
            offer.ticketsCount -= _ticketsCount;
            payable(offer.creator).transfer(priceWithoutFees);
        }
        payFee(serviceFee);
        payable(chat.creator).transfer(chatRoyalty);
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

    function cancelOffer(uint256 _offerId) external payable {
        Offer storage offer = offers[_offerId];
        require(offer.isActive, "Offer is not active");
        require(
            msg.sender == offer.creator,
            "Only the creator can cancel the offer"
        );
        if (offer.offerType == OfferType.Buy) {
            payable(offer.creator).transfer(offer.ticketsCount * offer.price);
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

    function returnPoolFunds(uint256 chatIndex) public {
        Chat storage chat = chats[chatIndex];
        require(chat.creator == msg.sender, "Not an owner");
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
        payable(chat.creator).transfer(refundAmount);
        payFee(serviceFeeOnReturn);
        emit PoolFundsReturned(chatIndex, refundAmount, msg.sender);
    }
}
