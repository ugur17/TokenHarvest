// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ProducerContract.sol";
import "./InspectorContract.sol";

contract MainContract {
    /* State variables */
    ProducerContract[] private s_producerContracts;
    InspectorContracts[] private s_inspectorContracts;

    /**
     * @dev This is the function to add new ProducerContract instance to the "s_producerContracts" list
     * @param _producerContract new ProducerContract parameter to add to the list
     */
    function addProducerContract(ProducerContract _producerContract) external {
        s_producerContracts.push(_producerContract);
    }
}
