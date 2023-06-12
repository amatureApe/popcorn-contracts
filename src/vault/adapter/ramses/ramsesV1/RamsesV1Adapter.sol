// SPDX-License-Identifier: GPL-3.0
// Docgen-SOLC: 0.8.15

pragma solidity ^0.8.15;

import {AdapterBase, IERC20, IERC20Metadata, SafeERC20, ERC20, Math, IStrategy, IAdapter} from "../../abstracts/AdapterBase.sol";
import {WithRewards, IWithRewards} from "../../abstracts/WithRewards.sol";
import {IGauge, ILpToken} from "./IRamsesV1.sol";
import {IPermissionRegistry} from "../../../../interfaces/vault/IPermissionRegistry.sol";

/**
 * @title   Ramses Adapter
 * @author  amatureApe
 * @notice  ERC4626 wrapper for Ramses Vaults.
 *
 * Allows wrapping Ramses Vaults.
 */
contract RamsesV1Adapter is AdapterBase, WithRewards {
    using SafeERC20 for IERC20;
    using Math for uint256;

    string internal _name;
    string internal _symbol;

    /// @notice The Ramses contract
    IGauge public gauge;

    address[] internal _rewardTokens;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    error NotEndorsed(address gauge);
    error InvalidAsset();

    /**
     * @notice Initialize a new Ramses Adapter.
     * @param adapterInitData Encoded data for the base adapter initialization.
     * @param registry - PermissionRegistry to verify the gauge
     * @param ramsesInitData - init data for velo adatper
     * @dev `_gauge` - the gauge address to stake our asset in
     * @dev This function is called by the factory contract when deploying a new vault.
     */
    function initialize(
        bytes memory adapterInitData,
        address registry,
        bytes memory ramsesInitData
    ) external initializer {
        __AdapterBase_init(adapterInitData);

        address _gauge = abi.decode(ramsesInitData, (address));

        // if (!IPermissionRegistry(registry).endorsed(_gauge))
        //     revert NotEndorsed(_gauge);

        gauge = IGauge(_gauge);

        if (gauge.stake() != asset()) revert InvalidAsset();

        _rewardTokens.push(gauge.rewards(0)); // RAM

        _name = string.concat(
            "VaultCraft Ramses ",
            IERC20Metadata(asset()).name(),
            " Adapter"
        );
        _symbol = string.concat("vcVelo-", IERC20Metadata(asset()).symbol());

        IERC20(asset()).approve(address(gauge), type(uint256).max);
    }

    function name()
        public
        view
        override(IERC20Metadata, ERC20)
        returns (string memory)
    {
        return _name;
    }

    function symbol()
        public
        view
        override(IERC20Metadata, ERC20)
        returns (string memory)
    {
        return _symbol;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total amount of underlying tokens the Vault holds.
    /// @return The total amount of underlying tokens the Vault holds.
    function _totalAssets() internal view override returns (uint256) {
        return gauge.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function _protocolDeposit(uint256 amount, uint256) internal override {
        gauge.deposit(amount, 0);
    }

    function _protocolWithdraw(uint256 amount, uint256) internal override {
        gauge.withdraw(amount);
    }

    /*//////////////////////////////////////////////////////////////
                            STRATEGY LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @notice Claim rewards from the Ramses gauge
    function claim() public override onlyStrategy returns (bool success) {
        try gauge.getReward(address(this), _rewardTokens) {
            success = true;
        } catch {}
    }

    /// @notice The tokens rewarded
    function rewardTokens() external view override returns (address[] memory) {
        return _rewardTokens;
    }

    /*//////////////////////////////////////////////////////////////
                      EIP-165 LOGIC
  //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    ) public pure override(WithRewards, AdapterBase) returns (bool) {
        return
            interfaceId == type(IWithRewards).interfaceId ||
            interfaceId == type(IAdapter).interfaceId;
    }
}
