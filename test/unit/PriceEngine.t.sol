// SPDX-License-License: MIT
pragma solidity ^0.8.20;

import '../../src/contracts/ArtistToken.sol';
import '../../src/contracts/ArtistTokenFactory.sol';
import '../../src/contracts/PriceEngine.sol';

import '../../src/mocks/MockFollowNFT.sol';
import '../../src/mocks/MockLensHub.sol';
import '../../src/mocks/MockOracle.sol';
import 'forge-std/Test.sol';

contract PriceEngineTest is Test {
  PriceEngine priceEngine;
  ArtistTokenFactory factory;
  MockLensHub lensHub;
  MockFollowNFT followNFT;
  MockOracle oracle;

  address owner = address(0x1);
  address user = address(0x2);
  uint256 profileId = 1;

  function setUp() public {
    vm.deal(owner, 1000 ether);
    vm.deal(user, 1000 ether);

    lensHub = new MockLensHub();
    followNFT = new MockFollowNFT();
    oracle = new MockOracle();

    lensHub.setProfile(profileId, owner);
    lensHub.setFollowNFT(profileId, address(followNFT));
    lensHub.setPubCount(profileId, 10);
    followNFT.setTotalSupply(100);
    oracle.setMetrics(profileId, 1000, 50, 500, 20);

    factory = new ArtistTokenFactory(address(lensHub), owner);
    priceEngine = new PriceEngine(address(lensHub), address(oracle), address(factory), owner);

    vm.prank(owner);
    priceEngine.depositGHO{value: 100 ether}();

    vm.prank(owner);
    factory.createArtistToken(profileId, 'Test Token', 'TST', 1_000_000, address(priceEngine));
  }

  function testDepositGHO() public {
    uint256 initialBalance = priceEngine.treasuryGHO();
    uint256 depositAmount = 50 ether;

    vm.prank(user);
    priceEngine.depositGHO{value: depositAmount}();

    assertEq(priceEngine.treasuryGHO(), initialBalance + depositAmount);
  }

  function testGetMintPrice() public {
    uint256 price = priceEngine.getMintPrice(profileId);
    assertTrue(price > 0);
  }

  function testUpdateMetricsAndSI() public {
    followNFT.setTotalSupply(200);
    oracle.setMetrics(profileId, 2000, 100, 1000, 40);

    uint256 initialRawValue = priceEngine.prevRawValues(profileId);
    priceEngine.updateMetricsAndSI(profileId);

    assertTrue(priceEngine.prevRawValues(profileId) != initialRawValue);
    assertEq(priceEngine.prevLensFollowers(profileId), 200);
    assertEq(priceEngine.prevLensPublications(profileId), 10);
    assertEq(priceEngine.prevIgFollowers(profileId), 2000);
    assertEq(priceEngine.prevIgPosts(profileId), 100);
    assertEq(priceEngine.prevYtSubscribers(profileId), 1000);
    assertEq(priceEngine.prevYtVideos(profileId), 40);
  }

  function testCalculatePrices() public {
    uint256[] memory profileIds = new uint256[](1);
    profileIds[0] = profileId;

    vm.prank(owner);
    uint256[] memory prices = priceEngine.calculatePrices(profileIds);

    assertEq(prices.length, 1);
    assertTrue(prices[0] > 0);
  }

  function testCalculatePricesInvalidToken() public {
    uint256[] memory profileIds = new uint256[](1);
    profileIds[0] = 2;

    vm.prank(owner);
    vm.expectRevert('Token does not exist');
    priceEngine.calculatePrices(profileIds);
  }

  function testCalculatePricesNonOwner() public {
    uint256[] memory profileIds = new uint256[](1);
    profileIds[0] = profileId;

    vm.prank(user);
    vm.expectRevert();
    priceEngine.calculatePrices(profileIds);
  }
}
