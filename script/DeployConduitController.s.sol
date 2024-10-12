// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { ConduitController } from "seaport-core/src/conduit/ConduitController.sol";

contract DeployConduitController is Script {
    function run() external {
        // 开始广播交易，使用私钥来签署交易
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署 ConduitController 合约
        ConduitController conduitController = new ConduitController();
        console.log("ConduitController deployed at:", address(conduitController));

        // 停止广播交易
        vm.stopBroadcast();
    }
}