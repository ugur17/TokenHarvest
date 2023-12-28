// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./HarvestToken.sol";

import "./Auth.sol";

error ServiceProvider__YouAreNotServiceProvider();
error ServiceProvider__DepositAmountShouldBeBiggerThanZero();
error ServiceProvider__DescriptionCantBeEmpty();
error ServiceProvider__TransactionNotInRightStatus();
error ServiceProvider__YouDidntOrderThisService();
error ServiceProvider__YouRequestedNonExistService();

contract ServiceProvider is Auth {
    enum TransactionStatus {
        Deposited,
        ServicePromised,
        ServiceProvided,
        SuccessfullyCompleted,
        Disputed,
        Refunded
    }

    struct Service {
        string serviceDetails;
    }

    struct Transaction {
        address producer;
        address serviceProvider;
        uint256 serviceId;
        string orderDetails;
        uint256 depositedAmount;
        TransactionStatus status;
    }

    // (provider address => (service id => Service))
    mapping(address => mapping(uint256 => Service)) public serviceList;
    mapping(uint256 => Transaction) public transactions;
    uint256 public transactionCount;
    HarvestToken public harvestToken;

    event ServiceAdded(address indexed serviceProvider, string description);
    event Deposited(
        address indexed producer,
        address indexed serviceProvider,
        uint256 indexed transactionId
    );
    event ServicePromised(uint256 indexed transactionId);
    event ServiceProvided(uint256 indexed transactionId);
    event ServiceSuccessfullyCompleted(uint256 indexed transactionId);
    event Refund(uint256 indexed transactionId);
    event DisputeRaised(uint256 indexed transactionId);
    event DisputeResolved(uint256 indexed transactionId, TransactionStatus status);

    constructor(address harvestTokenContractAddress) {
        harvestToken = HarvestToken(harvestTokenContractAddress);
        transactionCount = 0;
    }

    modifier onlyValidDescription(string memory description) {
        if (bytes(description).length <= 0) {
            revert ServiceProvider__DescriptionCantBeEmpty();
        }
        _;
    }

    modifier onlyExistService(address serviceProvider, uint256 serviceId) {
        if (bytes(serviceList[serviceProvider][serviceId].serviceDetails).length <= 0) {
            revert ServiceProvider__YouRequestedNonExistService();
        }
        _;
    }

    modifier onlyStatus(uint256 txId, TransactionStatus status) {
        if (transactions[txId].status != status) {
            revert ServiceProvider__TransactionNotInRightStatus();
        }
        _;
    }

    modifier onlyOrderedServiceProvider(uint256 transactionId) {
        if (msg.sender != transactions[transactionId].serviceProvider) {
            revert ServiceProvider__YouAreNotServiceProvider();
        }
        _;
    }

    modifier onlyProducerWhoPlacedOrder(uint256 transactionId) {
        if (transactions[transactionId].producer != msg.sender) {
            revert ServiceProvider__YouDidntOrderThisService();
        }
        _;
    }

    function addService(
        uint256 serviceId,
        string memory serviceDetails
    ) external onlyRole(UserRole.ServiceProvider) onlyValidDescription(serviceDetails) {
        serviceList[msg.sender][serviceId] = Service(serviceDetails);

        emit ServiceAdded(msg.sender, serviceDetails);
    }

    function orderService(
        address serviceProvider,
        uint256 serviceId,
        string memory orderDetails,
        uint256 amount
    ) external onlyRole(UserRole.Producer) onlyValidDescription(orderDetails) {
        if (amount <= 0) {
            revert ServiceProvider__DepositAmountShouldBeBiggerThanZero();
        }

        transactions[transactionCount] = Transaction({
            producer: msg.sender,
            serviceProvider: serviceProvider,
            serviceId: serviceId,
            orderDetails: orderDetails,
            depositedAmount: amount,
            status: TransactionStatus.Deposited
        });
        transactionCount++;
        // take payment from producer
        harvestToken.transferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, serviceProvider, transactionCount - 1);
    }

    function promiseService(
        uint256 transactionId
    )
        external
        onlyRole(UserRole.ServiceProvider)
        onlyStatus(transactionId, TransactionStatus.Deposited)
        onlyOrderedServiceProvider(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        transaction.status = TransactionStatus.ServicePromised;

        emit ServicePromised(transactionId);
    }

    function provideService(
        uint256 transactionId
    )
        external
        onlyRole(UserRole.ServiceProvider)
        onlyStatus(transactionId, TransactionStatus.ServicePromised)
        onlyOrderedServiceProvider(transactionId)
    {
        Transaction storage transaction = transactions[transactionId];
        transaction.status = TransactionStatus.ServiceProvided;

        emit ServiceProvided(transactionId);
    }

    function approveService(
        uint256 transactionId
    ) external onlyRole(UserRole.Producer) onlyProducerWhoPlacedOrder(transactionId) {
        Transaction storage transaction = transactions[transactionId];
        transaction.status = TransactionStatus.SuccessfullyCompleted;

        emit ServiceSuccessfullyCompleted(transactionId);
    }

    function raiseDispute(
        uint256 transactionId
    )
        external
        onlyRole(UserRole.Producer)
        onlyProducerWhoPlacedOrder(transactionId)
        onlyStatus(transactionId, TransactionStatus.ServiceProvided)
    {
        Transaction storage transaction = transactions[transactionId];
        transaction.status = TransactionStatus.Disputed;

        emit DisputeRaised(transactionId);
    }

    function resolveDispute(
        uint256 transactionId,
        bool txSuccessful
    ) external onlyOwner onlyStatus(transactionId, TransactionStatus.Disputed) {
        Transaction storage transaction = transactions[transactionId];
        if (txSuccessful) {
            transaction.status = TransactionStatus.SuccessfullyCompleted;
            harvestToken.transferFrom(
                address(this),
                transaction.serviceProvider,
                transaction.depositedAmount
            );
        } else {
            transaction.status = TransactionStatus.Refunded;
            harvestToken.transferFrom(
                address(this),
                transaction.producer,
                transaction.depositedAmount
            );
        }

        emit DisputeResolved(transactionId, transaction.status);
    }

    function getTransaction(uint256 transactionId) external view returns (Transaction memory) {
        return transactions[transactionId];
    }

    function getContractBalance() external view returns (uint256) {
        return harvestToken.balanceOf(address(this));
    }
}
