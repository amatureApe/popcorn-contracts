pragma solidity ^0.8.15;

import {BaseVaultInitData, BaseVault} from "../BaseVault.sol";
import {IGauge, IMinter} from "../../adapter/curve/ICurve.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract CurveLP {
    address crv;
    IERC20 asset;
    IGauge gauge;
    IMinter minter;
    address vault;

    modifier onlyVault() {
        require(msg.sender == vault);
        _;
    }

    function __CurveLP__init(address _vault, address _gauge, address _minter, address _asset) internal onlyInitializing {
        gauge = IGauge(_gauge);
        minter = IMinter(_minter);
        crv = IMinter(_minter).token();

        vault = _vault;

        IERC20(_asset).approve(_gauge, type(uint).max);
        asset = IERC20(_asset);

        updateRewardTokens();
    }


    function _claim() internal {
        minter.mint(address(gauge));
    }
    
    /// @dev used to retrieve the current reward tokens in case they've changed.
    /// callable by anyone
    function updateRewardTokens() public override {
        delete rewardTokens;

        // we don't know the exact number of reward tokens. So we brute force it
        // We could use `reward_count()` to get the exact number.  But, that function is only
        // available from LiquidityGaugeV4 onwards.
        
        // Curve only allows 8 reward tokens per gauge
        address[] memory _rewardTokens = new address[](8);
        uint rewardCount = 0;
        for (uint i; i < 8;) {
            try gauge.reward_tokens(i) returns (address token) {
                if (token == address(0)) {
                    // no more reward tokens left
                    break;
                }

                unchecked {++rewardCount;}
                _rewardTokens[i] = token;
            } catch {
                // LiquidityGaugeV1 doesn't implement `reward_tokens()` so we have to add a try/catch block
                // 3pool Gauge: https://etherscan.io/address/0xbfcf63294ad7105dea65aa58f8ae5be2d9d0952a#code
                break;
            }
            unchecked {++i;}
        }
        // CRV token is always a reward token that's not explicitly specified in the gauge contract.
        rewardTokens.push(crv);

        for (uint i; i < rewardCount;) {
            rewardTokens.push(_rewardTokens[i]);
            unchecked {++i;}
        }
    }
    
    function deposit(uint amount) external onlyVault {
        _deposit(amount);
    }

    function _deposit(uint amount) internal {
        gauge.deposit(amount);
    }

    function withdraw(address to, uint amount) external onlyVault {
        gauge.withdraw(amount);
        asset.safeTransfer(to, amount);
    }

    function _totalAssets() internal view override returns (uint) {
        return gauge.balanceOf(address(this));
    }
}
