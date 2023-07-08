// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;

import "forge-std/Test.sol";

contract Benchmark {
    uint256 private cachedGas;
    string private cachedName;

    function benchmarkStart(string memory name) internal {
        require(cachedGas == 0, "benchmark already started");
        cachedGas = 1;
        cachedName = name;
        cachedGas = gasleft();
    }

    function benchmarkEnd() internal {
        uint256 newGasLeft = gasleft();
        // subtract original gas and snapshot gas overhead
        uint256 gasUsed = cachedGas - newGasLeft - 100; // GAS_CALIBRATION = 100
        // reset to 0 so all writes for consistent overhead handling
        cachedGas = 0;

        console.log(cachedName, gasUsed);
    }
}
