// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import { Seaport } from "seaport-core/src/Seaport.sol";

contract DeploySeaport is Script {
    address private constant CONDUIT_CONTROLLER =
    0xEde768CBd9cb650F96073Ba7E6d5da7d928a315a;  // 可根据需要调整

    function run() public {
        // 开始广播交易
        vm.startBroadcast(vm.envUint("PK"));

        // 使用传统的 CREATE 方法部署 Seaport 合约
        Seaport seaport = new Seaport(CONDUIT_CONTROLLER);

        // 输出部署的 Seaport 合约地址
        console.log("Seaport deployed at:", address(seaport));

        // 停止广播交易
        vm.stopBroadcast();
    }
}