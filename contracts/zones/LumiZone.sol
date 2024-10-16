// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
AdvancedOrder,
CriteriaResolver,
Execution,
Fulfillment,
Order,
OrderComponents,
Schema,
ZoneParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {SeaportInterface} from "../../lib/seaport-sol/lib/seaport-core/lib/seaport-types/src/interfaces/SeaportInterface.sol";
import {ZoneInterface} from "../../lib/seaport-sol/lib/seaport-core/lib/seaport-types/src/interfaces/ZoneInterface.sol";

contract LumiZone is SeaportInterface,ZoneInterface {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev 验证订单的有效性
     * @param zoneParameters 包含 offer 和 consideration 等详细信息的 ZoneParameters 结构体
     * @return valid 表示订单是否有效
     */
    function validateOrder(ZoneParameters calldata zoneParameters) external view override returns (bytes4 valid) {
        // 检查 offer 和 consideration 是否符合要求
        bool isOfferERC1155 = checkOfferIsERC1155(zoneParameters.offer);
        bool isConsiderationNative = checkConsiderationIsNative(zoneParameters.consideration);

        if (isOfferERC1155 && isConsiderationNative) {
            return ZoneInterface.validateOrder.selector;
        }

        // 如果验证失败，返回空选择器
        return bytes4(0);
    }

    /**
     * @dev 检查 offer 是否为 ERC1155 类型
     * @param offer SpentItem[] 订单中的 offer 项
     * @return bool 返回 offer 是否为 ERC1155 类型
     */
    function checkOfferIsERC1155(SpentItem[] memory offer) internal pure returns (bool) {
        for (uint256 i = 0; i < offer.length; i++) {
            if (offer[i].itemType != 3) { // 3 对应 ERC1155 类型
                return false;
            }
        }
        return true;
    }

    /**
     * @dev 检查 consideration 是否为 Native 类型
     * @param consideration ReceivedItem[] 订单中的 consideration 项
     * @return bool 返回 consideration 是否为 Native 类型
     */
    function checkConsiderationIsNative(ReceivedItem[] memory consideration) internal pure returns (bool) {
        for (uint256 i = 0; i < consideration.length; i++) {
            if (consideration[i].itemType != 0) { // 0 对应 Native 类型
                return false;
            }
        }
        return true;
    }
}