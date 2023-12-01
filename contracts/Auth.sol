// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserIdentity {
    enum UserRole {
        Uretici,
        Denetleyici,
        Musteri
    }

    struct UserInfo {
        string username;
        bytes32 ipfsHash; // IPFS hash for sensitive data
        bool registered;
        UserRole role;
    }

    mapping(address => UserInfo) public users;

    event UserRegistered(address userAddress, string username, bytes32 ipfsHash, UserRole role);
    event UserLoggedIn(address userAddress, string username, UserRole role);
    event UserLoggedOut(address userAddress);

    modifier onlyRegistered() {
        require(users[msg.sender].registered, "User not registered");
        _;
    }

    modifier onlyRole(UserRole _role) {
        require(users[msg.sender].role == _role, "Insufficient role");
        _;
    }

    function register(string memory _username, bytes32 _ipfsHash, UserRole _role) external {
        require(!users[msg.sender].registered, "User already registered");

        users[msg.sender] = UserInfo(_username, _ipfsHash, true, _role);
        emit UserRegistered(msg.sender, _username, _ipfsHash, _role);
    }

    function login() external onlyRegistered returns (string memory, UserRole) {
        UserInfo storage currentUser = users[msg.sender];
        emit UserLoggedIn(msg.sender, currentUser.username, currentUser.role);
        return (currentUser.username, currentUser.role);
    }

    function logout() external onlyRegistered {
        delete users[msg.sender];
        emit UserLoggedOut(msg.sender);
    }
}
