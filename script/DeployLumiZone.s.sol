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
        uint256 platformFeePercentage = 150;  // 代表 1.5%
        uint256 royaltyFeePercentage = 750;   // 代表 7.5%
        // 初始化动态数组以传递到构造函数中
        address[] memory specifiedAddresses = new address[](3);
        specifiedAddresses[0] = 0x2d501e50F2EE03D2855aeb4d15139D57339BA9dA;
        specifiedAddresses[1] = 0x83199fF5610610a6a8dEc37e01b00Dba60D9E179;
        specifiedAddresses[2] = 0xeb8A03C8a86A78E5A48aDF78Cd9A701311bbBEad;

        address[] memory specifiedERC20Tokens = new address[](1);
        specifiedERC20Tokens[0] = 0x0d127caD283ecB85cA93d9C748c87682E8c969A0;

        // 部署 LumiItemZone 合约
        LumiItemZone zone = new LumiItemZone(
            platformFeeRecipient,
            royaltyRecipient,
            platformFeePercentage,
            royaltyFeePercentage,
            specifiedAddresses,
            specifiedERC20Tokens
        );


        vm.stopBroadcast();
        console.log("Zone contract deployed at:", address(zone));
    }
}