// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
Schema,
ZoneParameters
} from "../../lib/seaport-sol/lib/seaport-core/lib/seaport-types/src/lib/ConsiderationStructs.sol";
//import {SeaportInterface} from "../../lib/seaport-sol/lib/seaport-core/lib/seaport-types/src/interfaces/SeaportInterface.sol";
import {ZoneInterface} from "../../lib/seaport-sol/lib/seaport-core/lib/seaport-types/src/interfaces/ZoneInterface.sol";
import { ItemType } from "../../lib/seaport-sol/lib/seaport-core/lib/seaport-types/src/lib/ConsiderationEnums.sol";

//需要实现 ZoneInterface 接口
contract LumiItemZone is ZoneInterface {
    address public owner;
    address public platformFeeRecipient;
    address public royaltyRecipient;
    uint256 public platformFeePercentage; // 平台费比例，单位是万分之一，例如 200 = 2%
    uint256 public royaltyFeePercentage; // 版税比例

    mapping(address => bool) public specifiedAddresses;
    mapping(address => bool) public specifiedERC20Tokens;


    constructor(
        address _platformFeeRecipient,
        address _royaltyRecipient,
        uint256 _platformFeePercentage,
        uint256 _royaltyFeePercentage,
        address[] memory _specifiedAddresses,      // 初始化指定地址数组
        address[] memory _specifiedERC20Tokens     // 初始化指定 ERC20 代币数组
    ) {
        owner = msg.sender;
        platformFeeRecipient = _platformFeeRecipient;
        royaltyRecipient = _royaltyRecipient;
        platformFeePercentage = _platformFeePercentage;
        royaltyFeePercentage = _royaltyFeePercentage;

        // 设置初始指定地址和 ERC20 代币列表
        for (uint256 i = 0; i < _specifiedAddresses.length; i++) {
            specifiedAddresses[_specifiedAddresses[i]] = true;
        }

        for (uint256 i = 0; i < _specifiedERC20Tokens.length; i++) {
            specifiedERC20Tokens[_specifiedERC20Tokens[i]] = true;
        }
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function addSpecifiedAddress(address _specifiedAddress) external {
        require(msg.sender == owner, "Only owner can add specified address");
        require(!specifiedAddresses[_specifiedAddress], "Address already specified");
        specifiedAddresses[_specifiedAddress] = true;
    }

    function removeSpecifiedAddress(address _specifiedAddress) external {
        require(msg.sender == owner, "Only owner can remove specified address");
        require(specifiedAddresses[_specifiedAddress], "Address not specified");
        specifiedAddresses[_specifiedAddress] = false;
    }

    function addSpecifiedERC20Token(address _specifiedERC20Token) external {
        require(msg.sender == owner, "Only owner can add specified ERC20 token");
        require(!specifiedERC20Tokens[_specifiedERC20Token], "Token already specified");
        specifiedERC20Tokens[_specifiedERC20Token] = true;
    }

    function removeSpecifiedERC20Token(address _specifiedERC20Token) external {
        require(msg.sender == owner, "Only owner can remove specified ERC20 token");
        require(specifiedERC20Tokens[_specifiedERC20Token], "Token not specified");
        specifiedERC20Tokens[_specifiedERC20Token] = false;
    }

    function isSpecifiedAddress(address _address) internal view returns (bool) {
        return specifiedAddresses[_address];
    }

    function isSpecifiedERC20Token(address _token) internal view returns (bool) {
        return specifiedERC20Tokens[_token];
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
    override
    returns (bytes4 authorizedOrderMagicValue){
        // 直接返回预定义的魔法值
        return ZoneInterface.authorizeOrder.selector;
    }

    /**
     * @dev 验证订单的有效性，确保 offer 和 consideration 之间满足类型要求。
     * @param zoneParameters 包含 offer 和 consideration 等详细信息的 ZoneParameters 结构体
     * @return valid 表示订单是否有效
     */
    function validateOrder(ZoneParameters calldata zoneParameters)
    external
    override
    returns (bytes4 valid)
    {
        // 调用辅助函数检查 offer 和 consideration 的类型是否合法
        OrderCheckResult memory orderCheckResult = _checkOfferAndConsiderationTypes(zoneParameters);

        // 如果订单类型和物品验证不通过，则返回无效
        if (!orderCheckResult.isValid) {
            return bytes4(0);
        }

        // 调用检查平台费和版税的函数，根据订单类型检查费用是否正确
        bool feesValid = _checkFees(zoneParameters, orderCheckResult.orderType);

        // 如果平台费和版税不符合要求，返回无效
        if (!feesValid) {
            return bytes4(0);
        }

        // 如果是 offer 类型订单，确保调用者是指定地址
        if (orderCheckResult.orderType == 1 && !isSpecifiedAddress(msg.sender)) {
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
     * @dev 验证订单的有效性，确保。
     * @param zoneParameters 包含 offer 和 consideration 等详细信息的 ZoneParameters 结构体
     * @return result 返回订单的合法性和类型
     */
    function _checkOfferAndConsiderationTypes(ZoneParameters memory zoneParameters)
    internal
    view
    returns (OrderCheckResult memory result) {
        bool offerHasNative = false;
        bool offerHasSpecifiedERC20 = false;
        bool offerHasERC1155 = false;
        uint256 offerERC1155Count = 0;

        bool considerationHasNative = false;
        bool considerationHasSpecifiedERC20 = false;
        bool considerationHasERC1155 = false;
        uint256 considerationERC1155Count = 0;

        // 遍历 offer，确保只包含一种 token 类型（Native 或指定 ERC20），另一侧只能有一个 ERC1155
        for (uint256 i = 0; i < zoneParameters.offer.length; i++) {
            if (zoneParameters.offer[i].itemType == ItemType.ERC1155) {
                offerHasERC1155 = true;
                offerERC1155Count++;
            } else if (zoneParameters.offer[i].itemType == ItemType.NATIVE) {
                // 如果已经存在指定 ERC20，表示混合了不同 token 类型
                if (offerHasSpecifiedERC20) {
                    result.isValid = false;
                    return result; // 无效：混合了 Native 和 ERC20
                }
                offerHasNative = true;
            } else if (zoneParameters.offer[i].itemType == ItemType.ERC20 &&
                isSpecifiedERC20Token(zoneParameters.offer[i].token)) {
                // 如果已经存在 Native，表示混合了不同 token 类型
                if (offerHasNative) {
                    result.isValid = false;
                    return result; // 无效：混合了 Native 和 ERC20
                }
                offerHasSpecifiedERC20 = true;
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

        // 遍历 consideration，确保只包含一种 token 类型（Native 或指定 ERC20），另一侧只能有一个 ERC1155
        for (uint256 i = 0; i < zoneParameters.consideration.length; i++) {
            if (zoneParameters.consideration[i].itemType == ItemType.ERC1155) {
                considerationHasERC1155 = true;
                considerationERC1155Count++;
            } else if (zoneParameters.consideration[i].itemType == ItemType.NATIVE) {
                // 如果已经存在指定 ERC20，表示混合了不同 token 类型
                if (considerationHasSpecifiedERC20) {
                    result.isValid = false;
                    return result; // 无效：混合了 Native 和 ERC20
                }
                considerationHasNative = true;
            } else if (zoneParameters.consideration[i].itemType == ItemType.ERC20 &&
                isSpecifiedERC20Token(zoneParameters.consideration[i].token)) {
                // 如果已经存在 Native，表示混合了不同 token 类型
                if (considerationHasNative) {
                    result.isValid = false;
                    return result; // 无效：混合了 Native 和 ERC20
                }
                considerationHasSpecifiedERC20 = true;
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
        bool isValid = (offerHasERC1155 && (considerationHasNative || considerationHasSpecifiedERC20)) ||
            (considerationHasERC1155 && (offerHasNative || offerHasSpecifiedERC20));

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
    function _checkFees(ZoneParameters memory zoneParameters, uint8 orderType)
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
            uint256 expectedPlatformFee = (totalAmount * platformFeePercentage) / (10000 + platformFeePercentage + royaltyFeePercentage);
            uint256 expectedRoyaltyFee = (totalAmount * royaltyFeePercentage) / (10000 + platformFeePercentage + royaltyFeePercentage);

            // 检查是否符合预期的费用分配
            bool platformFeeValid = (platformFeeAmount >= expectedPlatformFee);
            bool royaltyFeeValid = (royaltyFeeAmount >= expectedRoyaltyFee);

            // 只有当平台费和版税都符合要求时，订单才是有效的
            return platformFeeValid && royaltyFeeValid;
        }

        return false;  // 如果订单类型不是 0（List）或 1（Offer），返回 false


    }

//    // 假设 Schema 是一个包含 Proposal ID 的结构体
//    struct Schema {
//        uint256 proposalId;
//        string description; // 可选
//    }

    function getSeaportMetadata()
    external
    pure
    override
    returns (
        string memory name,
        Schema[] memory schemas // map to Seaport Improvement Proposal IDs
    )
    {
//        schemas = new Schema[];
        name = "LumiZone";
        schemas[0] = Schema({
            id: 1,
            metadata: "ERC1155 and Native Token Trade Schema"
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