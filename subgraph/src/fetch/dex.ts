import { constants } from '@amxx/graphprotocol-utils';
import {
  Address
} from '@graphprotocol/graph-ts';
import {
  ERC20DexPair,
} from '../../generated/schema';
import { StarterKitERC20Dex } from '../../generated/templates/StarterKitERC20Dex/StarterKitERC20Dex';

export function fetchDex(address: Address): ERC20DexPair {
  let pair = ERC20DexPair.load(address)

  let endpoint = StarterKitERC20Dex.bind(address)
  let baseToken = endpoint.try_baseToken()
  let quoteToken = endpoint.try_quoteToken()

  if (pair === null) {
    pair = new ERC20DexPair(address)

    let name = endpoint.try_name()
    let symbol = endpoint.try_symbol()
    let decimals = endpoint.try_decimals()

    pair.name = name.reverted ? null : name.value
    pair.symbol = symbol.reverted ? null : symbol.value
    pair.decimals = decimals.reverted ? 18 : decimals.value
    pair.asAccount = address
  }

  let baseReserve = endpoint.try_getBaseTokenBalance()
  let quoteReserve = endpoint.try_getQuoteTokenBalance()
  let totalSupply = endpoint.try_totalSupply()
  let swapFee = endpoint.try_swapFee()

  pair.baseToken = baseToken.reverted ? constants.ADDRESS_ZERO : baseToken.value
  pair.quoteToken = quoteToken.reverted ? constants.ADDRESS_ZERO : quoteToken.value
  pair.swapFee = swapFee.reverted ? constants.BIGINT_ZERO : swapFee.value

  pair.baseReserveExact = baseReserve.reverted ? constants.BIGINT_ZERO : baseReserve.value
  pair.baseReserve = baseReserve.reverted
    ? constants.BIGDECIMAL_ZERO
    : baseReserve.value.toBigDecimal()

  pair.quoteReserveExact = quoteReserve.reverted ? constants.BIGINT_ZERO : quoteReserve.value
  pair.quoteReserve = quoteReserve.reverted
    ? constants.BIGDECIMAL_ZERO
    : quoteReserve.value.toBigDecimal()

  pair.totalSupplyExact = totalSupply.reverted ? constants.BIGINT_ZERO : totalSupply.value
  pair.totalSupply = totalSupply.reverted
    ? constants.BIGDECIMAL_ZERO
    : totalSupply.value.toBigDecimal()

  // Calculate prices based on reserves
  if (!baseReserve.reverted && !quoteReserve.reverted && quoteReserve.value.gt(constants.BIGINT_ZERO)) {
    pair.baseTokenPrice = quoteReserve.value.toBigDecimal()
      .div(baseReserve.value.toBigDecimal())
    pair.quoteTokenPrice = baseReserve.value.toBigDecimal()
      .div(quoteReserve.value.toBigDecimal())
  } else {
    pair.baseTokenPrice = constants.BIGDECIMAL_ZERO
    pair.quoteTokenPrice = constants.BIGDECIMAL_ZERO
  }

  pair.save()

  return pair as ERC20DexPair
}
