// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/src/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        NFTMarketplace marketplace = new NFTMarketplace();

        console.log("NFTMarketplace deployed to: ", address(marketplace));

        vm.stopBroadcast();
    }
}