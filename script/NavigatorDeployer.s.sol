// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { LibString } from "solady/src/utils/LibString.sol";

import {
    ReadOnlyOrderValidator
} from "../contracts/helpers/order-validator/lib/ReadOnlyOrderValidator.sol";
import {
    SeaportValidatorHelper
} from "../contracts/helpers/order-validator/lib/SeaportValidatorHelper.sol";
import {
    SeaportValidator
} from "../contracts/helpers/order-validator/SeaportValidator.sol";

import {
    RequestValidator
} from "../contracts/helpers/navigator/lib/RequestValidator.sol";
import {
    CriteriaHelper
} from "../contracts/helpers/navigator/lib/CriteriaHelper.sol";
import {
    ValidatorHelper
} from "../contracts/helpers/navigator/lib/ValidatorHelper.sol";
import {
    OrderDetailsHelper
} from "../contracts/helpers/navigator/lib/OrderDetailsHelper.sol";
import {
    FulfillmentsHelper
} from "../contracts/helpers/navigator/lib/FulfillmentsHelper.sol";
import {
    SuggestedActionHelper
} from "../contracts/helpers/navigator/lib/SuggestedActionHelper.sol";
import {
    ExecutionsHelper
} from "../contracts/helpers/navigator/lib/ExecutionsHelper.sol";
import {
    SeaportNavigator
} from "../contracts/helpers/navigator/SeaportNavigator.sol";

interface ImmutableCreate2Factory {
    function hasBeenDeployed(
        address deploymentAddress
    ) external view returns (bool);

    function findCreate2Address(
        bytes32 salt,
        bytes calldata initializationCode
    ) external view returns (address deploymentAddress);

    function safeCreate2(
        bytes32 salt,
        bytes calldata initializationCode
    ) external payable returns (address deploymentAddress);
}

contract NavigatorDeployer is Script {
    ImmutableCreate2Factory private constant IMMUTABLE_CREATE2_FACTORY =
        ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);
    address private constant CONDUIT_CONTROLLER =
        0x00000000F9490004C11Cef243f5400493c00Ad63;

    bytes32 private constant SALT = bytes32(uint256(0x1));

    function deploy(
        string memory name,
        bytes memory initCode
    ) internal returns (address) {
        bytes32 initCodeHash = keccak256(initCode);
        address deploymentAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(IMMUTABLE_CREATE2_FACTORY),
                            SALT,
                            initCodeHash
                        )
                    )
                )
            )
        );
        bool deployed;
        if (!IMMUTABLE_CREATE2_FACTORY.hasBeenDeployed(deploymentAddress)) {
            deploymentAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2(
                SALT,
                initCode
            );
            deployed = true;
        }
        console.log(
            _pad(deployed ? "Deploying" : "Found", 10),
            _pad(name, 23),
            _pad(LibString.toHexString(deploymentAddress), 43),
            LibString.toHexString(uint256(initCodeHash))
        );
        return deploymentAddress;
    }

    function run() public {
        vm.startBroadcast();
        console.log(
            _pad("State", 10),
            _pad("Name", 23),
            _pad("Address", 43),
            "Initcode hash"
        );

        address seaportValidatorHelper = deploy(
            "SeaportValidatorHelper",
            type(SeaportValidatorHelper).creationCode
        );
        address readOnlyOrderValidator = deploy(
            "ReadOnlyOrderValidator",
            type(ReadOnlyOrderValidator).creationCode
        );
        deploy(
            "SeaportValidator",
            bytes.concat(
                type(SeaportValidator).creationCode,
                abi.encode(
                    readOnlyOrderValidator,
                    seaportValidatorHelper,
                    CONDUIT_CONTROLLER
                )
            )
        );

        address requestValidator = deploy(
            "RequestValidator",
            type(RequestValidator).creationCode
        );
        address criteriaHelper = deploy(
            "CriteriaHelper",
            type(CriteriaHelper).creationCode
        );
        address validatorHelper = deploy(
            "ValidatorHelper",
            type(ValidatorHelper).creationCode
        );
        address orderDetailsHelper = deploy(
            "OrderDetailsHelper",
            type(OrderDetailsHelper).creationCode
        );
        address fulfillmentsHelper = deploy(
            "FulfillmentsHelper",
            type(FulfillmentsHelper).creationCode
        );
        address suggestedActionHelper = deploy(
            "SuggestedActionHelper",
            type(SuggestedActionHelper).creationCode
        );
        address executionsHelper = deploy(
            "ExecutionsHelper",
            type(ExecutionsHelper).creationCode
        );

        deploy(
            "SeaportNavigator",
            bytes.concat(
                type(SeaportNavigator).creationCode,
                abi.encode(
                    requestValidator,
                    criteriaHelper,
                    validatorHelper,
                    orderDetailsHelper,
                    fulfillmentsHelper,
                    suggestedActionHelper,
                    executionsHelper
                )
            )
        );
    }

    function _pad(
        string memory name,
        uint256 n
    ) internal pure returns (string memory) {
        string memory padded = name;
        while (bytes(padded).length < n) {
            padded = string.concat(padded, " ");
        }
        return padded;
    }
}
