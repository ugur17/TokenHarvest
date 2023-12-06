// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Auth {
    enum UserRole {
        Producer,
        Inspector,
        Customer
    }

    struct User {
        string username;
        bytes32 ipfsHash; // IPFS hash for sensitive data like location and phone number
        bool registered;
        UserRole role;
    }

    mapping(address => User) public users;

    event UserRegistered(address userAddress, string username, bytes32 ipfsHash, UserRole role);
    // event UserLoggedIn(address userAddress, string username, UserRole role);
    // event UserLoggedOut(address userAddress);

    modifier onlyRegistered() {
        require(users[msg.sender].registered, "User not registered");
        _;
    }

    modifier onlyRole(UserRole _role) {
        require(users[msg.sender].registered, "User not registered");
        require(users[msg.sender].role == _role, "Insufficient role");
        _;
    }

    function register(string memory _username, bytes32 _ipfsHash, UserRole _role) external {
        require(!users[msg.sender].registered, "User already registered");

        users[msg.sender] = User(_username, _ipfsHash, true, _role);
        emit UserRegistered(msg.sender, _username, _ipfsHash, _role);
    }

    function checkRole(address currentUser) external view returns (UserRole) {
        return users[currentUser].role;
    }

    // function login() external onlyRegistered returns (string memory, UserRole) {
    //     UserInfo storage currentUser = users[msg.sender];
    //     emit UserLoggedIn(msg.sender, currentUser.username, currentUser.role);
    //     return (currentUser.username, currentUser.role);
    // }

    // function logout() external onlyRegistered {
    //     delete users[msg.sender];
    //     emit UserLoggedOut(msg.sender);
    // }
}
