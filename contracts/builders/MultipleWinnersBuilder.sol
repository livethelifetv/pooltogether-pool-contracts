// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "./ControlledTokenBuilder.sol";
import "../prize-strategy/multiple-winners/MultipleWinnersProxyFactory.sol";

/* solium-disable security/no-block-members */
contract MultipleWinnersBuilder {

  event MultipleWinnersCreated(address indexed prizeStrategy);

  struct MultipleWinnersConfig {
    RNGInterface rngService;
    uint256 prizePeriodStart;
    uint256 prizePeriodSeconds;
    string ticketName;
    string ticketSymbol;
    string sponsorshipName;
    string sponsorshipSymbol;
    uint256 ticketCreditLimitMantissa;
    uint256 ticketCreditRateMantissa;
    bool useGSN;
    uint256 numberOfWinners;
    bool splitExternalErc20Awards;
  }

  MultipleWinnersProxyFactory public multipleWinnersProxyFactory;
  ControlledTokenBuilder public controlledTokenBuilder;
  address public trustedForwarder;

  constructor (
    MultipleWinnersProxyFactory _multipleWinnersProxyFactory,
    ControlledTokenBuilder _controlledTokenBuilder,
    address _trustedForwarder
  ) public {
    require(address(_multipleWinnersProxyFactory) != address(0), "MultipleWinnersBuilder/multipleWinnersProxyFactory-not-zero");
    require(address(_controlledTokenBuilder) != address(0), "MultipleWinnersBuilder/token-builder-not-zero");
    multipleWinnersProxyFactory = _multipleWinnersProxyFactory;
    trustedForwarder = _trustedForwarder;
    controlledTokenBuilder = _controlledTokenBuilder;
  }

  function createMultipleWinners(
    PrizePool prizePool,
    MultipleWinnersConfig memory prizeStrategyConfig,
    uint8 decimals,
    address owner
  ) external returns (MultipleWinners) {
    MultipleWinners mw = multipleWinnersProxyFactory.create();

    Ticket ticket = _createTicket(
      prizeStrategyConfig.ticketName,
      prizeStrategyConfig.ticketSymbol,
      decimals,
      prizePool,
      prizeStrategyConfig.useGSN
    );

    ControlledToken sponsorship = _createSponsorship(
      prizeStrategyConfig.sponsorshipName,
      prizeStrategyConfig.sponsorshipSymbol,
      decimals,
      prizePool,
      prizeStrategyConfig.useGSN
    );

    mw.initializeMultipleWinners(
      prizeStrategyConfig.useGSN ? trustedForwarder : address(0),
      prizeStrategyConfig.prizePeriodStart,
      prizeStrategyConfig.prizePeriodSeconds,
      prizePool,
      ticket,
      sponsorship,
      prizeStrategyConfig.rngService,
      prizeStrategyConfig.numberOfWinners
    );

    if (prizeStrategyConfig.splitExternalErc20Awards) {
      mw.setSplitExternalErc20Awards(true);
    }

    mw.transferOwnership(owner);

    emit MultipleWinnersCreated(address(mw));

    return mw;
  }

  function createMultipleWinnersFromExistingPrizeStrategy(
    PeriodicPrizeStrategy prizeStrategy,
    uint256 numberOfWinners
  ) external returns (MultipleWinners) {
    MultipleWinners mw = multipleWinnersProxyFactory.create();

    mw.initializeMultipleWinners(
      prizeStrategy.trustedForwarder(),
      prizeStrategy.prizePeriodStartedAt(),
      prizeStrategy.prizePeriodSeconds(),
      prizeStrategy.prizePool(),
      prizeStrategy.ticket(),
      prizeStrategy.sponsorship(),
      prizeStrategy.rng(),
      numberOfWinners
    );

    mw.transferOwnership(msg.sender);

    emit MultipleWinnersCreated(address(prizeStrategy));

    return mw;
  }

  function _createTicket(
    string memory name,
    string memory token,
    uint8 decimals,
    PrizePool prizePool,
    bool useGSN
  ) internal returns (Ticket) {
    return controlledTokenBuilder.createTicket(
      ControlledTokenBuilder.ControlledTokenConfig(
        name,
        token,
        decimals,
        prizePool,
        useGSN
      )
    );
  }

  function _createSponsorship(
    string memory name,
    string memory token,
    uint8 decimals,
    PrizePool prizePool,
    bool useGSN
  ) internal returns (ControlledToken) {
    return controlledTokenBuilder.createControlledToken(
      ControlledTokenBuilder.ControlledTokenConfig(
        name,
        token,
        decimals,
        prizePool,
        useGSN
      )
    );
  }
}
