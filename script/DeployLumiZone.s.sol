pragma solidity ^0.8.13;
import {LumiItemZone} from "../contracts/zones/LumiItemZone.sol";
import {Script} from "forge-std/Script.sol";
import "forge-std/Script.sol";

contract DeployLumiZone is Script {
    function run() public {
        vm.startBroadcast();

        // 填写平台费收款人、版税收款人地址、平台费百分比和版税百分比
        address platformFeeRecipient = 0x2d501e50F2EE03D2855aeb4d15139D57339BA9dA; // 替换为实际的平台费收款人地址
        address royaltyRecipient = 0x83199fF5610610a6a8dEc37e01b00Dba60D9E179;         // 替换为实际的版税收款人地址
        uint256 platformFeePercentage = 150;  // 代表 2.5%
        uint256 royaltyFeePercentage = 750;   // 代表 5%

        // 部署 LumiItemZone 合约
        LumiItemZone zone = new LumiItemZone(
            platformFeeRecipient,
            royaltyRecipient,
            platformFeePercentage,
            royaltyFeePercentage
        );


        vm.stopBroadcast();
        console.log("Zone contract deployed at:", address(zone));
    }
}