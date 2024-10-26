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
import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

//需要实现 ZoneInterface 接口
contract LumiItemZone is ZoneInterface {
    address public owner;
    address public platformFeeRecipient;
    address public royaltyRecipient;
    uint256 public platformFeePercentage; // 平台费比例，单位是万分之一，例如 200 = 2%
    uint256 public royaltyFeePercentage; // 版税比例

    constructor(address _platformFeeRecipient, address _royaltyRecipient, uint256 _platformFeePercentage, uint256 _royaltyFeePercentage) {
        owner = msg.sender;
        platformFeeRecipient = _platformFeeRecipient;
        royaltyRecipient = _royaltyRecipient;
        platformFeePercentage = _platformFeePercentage;
        royaltyFeePercentage = _royaltyFeePercentage;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    /**
     * @dev Authorizes an order before any token fulfillments from any order have been executed by Seaport.
     *
     * @param zoneParameters The context about the order fulfillment and any
     *                       supplied extraData.
     *
     * @return authorizedOrderMagicValue The magic value that indicates a valid
     *                              order.
     */
    function authorizeOrder(ZoneParameters calldata zoneParameters)
    external
    returns (bytes4 authorizedOrderMagicValue);

    /**
     * @dev 验证订单的有效性，确保 offer 和 consideration 之间满足类型要求。
     * @param zoneParameters 包含 offer 和 consideration 等详细信息的 ZoneParameters 结构体
     * @return valid 表示订单是否有效
     */
    function validateOrder(ZoneParameters calldata zoneParameters)
    external
    view
    returns (bytes4 valid)
    {
        // 调用辅助函数检查 offer 和 consideration 的类型是否合法
        OrderCheckResult memory orderCheckResult = _checkOfferAndConsiderationTypes(zoneParameters);

        // 如果订单类型和物品验证不通过，则返回无效
        if (!orderCheckResult.isValid) {
            return bytes4(0);
        }

        // 调用检查平台费和版税的函数，根据订单类型检查费用是否正确
        bool feesValid = checkFees(zoneParameters, orderCheckResult.orderType);

        // 如果平台费和版税不符合要求，返回无效
        if (!feesValid) {
            return bytes4(0);
        }

        // 如果所有验证通过，返回有效的订单选择器
        return ZoneInterface.validateOrder.selector;
    }

    // 定义结构体来存储订单验证结果和类型
    struct OrderCheckResult {
        bool isValid;
        uint8 orderType; // 0 表示 list，1 表示 offer
    }

    /**
     * @dev 验证订单的有效性，确保 offer 和 consideration 只包含 ERC1155 或 Native，且类型匹配。
     * @param zoneParameters 包含 offer 和 consideration 等详细信息的 ZoneParameters 结构体
     * @return result 返回订单的合法性和类型
     */
    function _checkOfferAndConsiderationTypes(ZoneParameters memory zoneParameters)
    internal
    pure
    returns (OrderCheckResult memory result) {
        bool offerHasNativeOrERC20 = false;
        bool offerHasERC1155 = false;
        uint256 offerERC1155Count = 0;

        bool considerationHasNativeOrERC20 = false;
        bool considerationHasERC1155 = false;
        uint256 considerationERC1155Count = 0;

        // 遍历 offer，确保一侧只包含 Native 或指定 ERC20，另一侧只能有一个 ERC1155
        for (uint256 i = 0; i < zoneParameters.offer.length; i++) {
            if (zoneParameters.offer[i].itemType == ItemType.ERC1155) {
                offerHasERC1155 = true;
                offerERC1155Count++;
            } else if (zoneParameters.offer[i].itemType == ItemType.NATIVE ||
                (zoneParameters.offer[i].itemType == ItemType.ERC20 &&
                    zoneParameters.offer[i].token == specifiedERC20Token)) { // 确保是指定的 ERC20
                offerHasNativeOrERC20 = true;
            } else {
                result.isValid = false;
                return result; // 如果有其他类型的物品，直接返回无效
            }
        }

        // offer 中 ERC1155 数量超过 1 时无效
        if (offerERC1155Count > 1) {
            result.isValid = false;
            return result;
        }

        // 遍历 consideration，确保一侧只包含 Native 或指定 ERC20，另一侧只能有一个 ERC1155
        for (uint256 i = 0; i < zoneParameters.consideration.length; i++) {
            if (zoneParameters.consideration[i].itemType == ItemType.ERC1155) {
                considerationHasERC1155 = true;
                considerationERC1155Count++;
            } else if (zoneParameters.consideration[i].itemType == ItemType.NATIVE ||
                (zoneParameters.consideration[i].itemType == ItemType.ERC20 &&
                    zoneParameters.consideration[i].token == specifiedERC20Token)) {
                considerationHasNativeOrERC20 = true;
            } else {
                result.isValid = false;
                return result; // 如果有其他类型的物品，直接返回无效
            }
        }

        // consideration 中 ERC1155 数量超过 1 时无效
        if (considerationERC1155Count > 1) {
            result.isValid = false;
            return result;
        }

        // 确保 offer 和 consideration 中一方为 ERC1155，另一方为 Native 或 ERC20
        bool isValid = (offerHasERC1155 && considerationHasNativeOrERC20) ||
            (offerHasNativeOrERC20 && considerationHasERC1155);

        result.isValid = isValid;
        result.orderType = offerHasERC1155 ? 0 : 1; // 0 表示 list，1 表示 offer
        return result;
    }

    /**
     * @dev 检查订单中的平台费和版税是否正确。
     * @param zoneParameters 包含 offer 和 consideration 等详细信息的 ZoneParameters 结构体
     * @param orderType 表示订单的类型：0 表示 List（检查 consideration 数组），1 表示 Offer（检查 offer 数组）
     * @return isValid 表示费用是否符合要求
     */
    function checkFees(ZoneParameters memory zoneParameters, uint8 orderType)
    internal
    view
    returns (bool isValid)
    {
        uint256 totalAmount = 0;
        uint256 platformFeeAmount = 0;
        uint256 royaltyFeeAmount = 0;
        // 如果是 Offer，无需检查费用，因为税费卖方承担
        if (orderType==1){
            return true;
        }

        // 根据订单类型选择要检查的数组：如果是 0（List），检查 consideration 数组；如果是 1（Offer），无需检查，因为税费卖方承担
        if (orderType == 0) {
            // 遍历 consideration 项，计算总金额并找到平台费和版税的分配
            for (uint256 i = 0; i < zoneParameters.consideration.length; i++) {
                totalAmount += zoneParameters.consideration[i].amount;

                if (zoneParameters.consideration[i].recipient == platformFeeRecipient) {
                    platformFeeAmount += zoneParameters.consideration[i].amount;
                } else if (zoneParameters.consideration[i].recipient == royaltyRecipient) {
                    royaltyFeeAmount += zoneParameters.consideration[i].amount;
                }
            }

            // 计算平台费和版税应该是多少
            uint256 expectedPlatformFee = (totalAmount * platformFeePercentage) / 10000;
            uint256 expectedRoyaltyFee = (totalAmount * royaltyFeePercentage) / 10000;

            // 检查是否符合预期的费用分配
            bool platformFeeValid = (platformFeeAmount >= expectedPlatformFee);
            bool royaltyFeeValid = (royaltyFeeAmount >= expectedRoyaltyFee);

            // 只有当平台费和版税都符合要求时，订单才是有效的
            return platformFeeValid && royaltyFeeValid;
        }

        return false;  // 如果订单类型不是 0（List）或 1（Offer），返回 false


    }

    // 假设 Schema 是一个包含 Proposal ID 的结构体
    struct Schema {
        uint256 proposalId;
        string description; // 可选
    }

    function getSeaportMetadata()
    external
    view
    override
    returns (string memory name, Schema[] memory schemas) {
        name = "LumiItemZone"; // Zone 的名称

        // 定义并初始化 schemas 数组
        schemas = new Schema ; // 假设有一个 schema，可以按需求添加多个
        schemas[0] = Schema({
            proposalId: 1, // 根据具体情况设定 Proposal ID
            description: "ERC1155 and Native Token Trade Schema" // 可选描述
        });

        return (name, schemas);
    }

    function supportsInterface(bytes4 interfaceId)
    external
    view
    override
    returns (bool) {
        // 检查是否支持 `ZoneInterface` 的 interfaceId
        return interfaceId == type(ZoneInterface).interfaceId;
    }
}