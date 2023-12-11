// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

error Auth__InvalidNameOrEmail();
error Auth__AlreadyRegistered();
error Auth__UserNotRegistered();
error Auth__InsufficientRole();

contract Auth {
    /* Type Declarations */
    enum UserRole {
        Producer,
        Inspector,
        Customer
    }
    struct User {
        string username;
        string email;
        bool registered;
        UserRole role;
    }
    /* State Variables */
    mapping(address => User) public users;

    /* Events */
    event UserRegistered(
        address indexed userAddress,
        string username,
        string indexed email,
        UserRole indexed role
    );

    /* Modifiers */
    modifier onlyRegistered() {
        if (users[msg.sender].registered == false) {
            revert Auth__UserNotRegistered();
        }
        _;
    }

    modifier onlyRole(UserRole _role) {
        if (users[msg.sender].registered == false) {
            revert Auth__UserNotRegistered();
        }
        if (users[msg.sender].role != _role) {
            revert Auth__InsufficientRole();
        }
        _;
    }

    modifier onlyValidNameAndEmail(string memory name, string memory email) {
        if (bytes(name).length == 0 || bytes(email).length == 0) {
            revert Auth__InvalidNameOrEmail();
        }
        _;
    }

    /* Functions */
    function register(
        string memory _username,
        string memory email,
        UserRole _role
    ) external onlyValidNameAndEmail(_username, email) {
        if (users[msg.sender].registered) {
            revert Auth__AlreadyRegistered();
        }
        users[msg.sender] = User(_username, email, true, _role);
        emit UserRegistered(msg.sender, _username, email, _role);
    }

    function checkRole(address currentUser) external view returns (UserRole) {
        return users[currentUser].role;
    }
}
