import { constants } from '@amxx/graphprotocol-utils';
import {
  Address,
  BigDecimal
} from '@graphprotocol/graph-ts';
import { Account, ERC20DexPair, ERC20DexStake } from '../../generated/schema';
import { StarterKitERC20Dex } from '../../generated/templates/StarterKitERC20Dex/StarterKitERC20Dex';

export function fetchDex(address: Address): ERC20DexPair {
  let pair = ERC20DexPair.load(address)
  let endpoint = StarterKitERC20Dex.bind(address)

  if (pair === null) {
    pair = new ERC20DexPair(address)
    pair.name = endpoint.name()
    pair.symbol = endpoint.symbol()
    pair.decimals = endpoint.decimals()
    pair.asAccount = address
  }

  let baseReserve = endpoint.getBaseTokenBalance()
  let quoteReserve = endpoint.getQuoteTokenBalance()

  pair.baseToken = endpoint.baseToken()
  pair.quoteToken = endpoint.quoteToken()
  pair.swapFee = endpoint.swapFee()

  pair.baseReserveExact = baseReserve
  pair.baseReserve = baseReserve.toBigDecimal()
  pair.quoteReserveExact = quoteReserve
  pair.quoteReserve = quoteReserve.toBigDecimal()

  let totalSupply = endpoint.totalSupply()
  pair.totalSupplyExact = totalSupply
  pair.totalSupply = totalSupply.toBigDecimal()

  // Calculate prices based on reserves
  if (quoteReserve.gt(constants.BIGINT_ZERO) && baseReserve.gt(constants.BIGINT_ZERO)) {
    // Need to adjust for decimals of both tokens
    let baseDecimals = BigDecimal.fromString('1' + '0'.repeat(endpoint.decimals()))
    let quoteDecimals = BigDecimal.fromString('1' + '0'.repeat(endpoint.decimals()))

    pair.baseTokenPrice = quoteReserve.toBigDecimal().div(quoteDecimals)
      .div(baseReserve.toBigDecimal().div(baseDecimals))
    pair.quoteTokenPrice = baseReserve.toBigDecimal().div(baseDecimals)
      .div(quoteReserve.toBigDecimal().div(quoteDecimals))
  } else {
    pair.baseTokenPrice = constants.BIGDECIMAL_ZERO
    pair.quoteTokenPrice = constants.BIGDECIMAL_ZERO
  }

  pair.save()
  return pair as ERC20DexPair
}


export function fetchERC20DexStake(contract: ERC20DexPair, account: Account): ERC20DexStake {
  let id = contract.id.toHex().concat('/').concat(account.id.toHex())
  let balance = ERC20DexStake.load(id)

  if (balance == null) {
    balance = new ERC20DexStake(id)
    balance.pair = contract.id
    balance.account = account.id
    balance.value = constants.BIGDECIMAL_ZERO
    balance.valueExact = constants.BIGINT_ZERO
    balance.save()
  }

  return balance as ERC20DexStake
}