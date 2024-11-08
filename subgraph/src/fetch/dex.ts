import { constants, decimals } from '@amxx/graphprotocol-utils';
import {
  Address, BigInt
} from '@graphprotocol/graph-ts';
import { Account, ERC20DexPair, ERC20DexStake } from '../../generated/schema';
import { StarterKitERC20Dex } from '../../generated/templates/StarterKitERC20Dex/StarterKitERC20Dex';

export function fetchDex(address: Address): ERC20DexPair {
  let pair = ERC20DexPair.load(address)
  let endpoint = StarterKitERC20Dex.bind(address)

  if (pair === null) {
    pair = new ERC20DexPair(address)
    let nameResult = endpoint.try_name()
    let symbolResult = endpoint.try_symbol()
    let decimalsResult = endpoint.try_decimals()

    pair.name = nameResult.reverted ? '' : nameResult.value
    pair.symbol = symbolResult.reverted ? '' : symbolResult.value
    pair.decimals = decimalsResult.reverted ? 0 : decimalsResult.value
    pair.asAccount = address
  }

  let baseReserveResult = endpoint.try_getBaseTokenBalance()
  let quoteReserveResult = endpoint.try_getQuoteTokenBalance()
  let baseTokenResult = endpoint.try_baseToken()
  let quoteTokenResult = endpoint.try_quoteToken()
  let swapFeeResult = endpoint.try_swapFee()
  let totalSupplyResult = endpoint.try_totalSupply()

  if (!baseReserveResult.reverted && !quoteReserveResult.reverted) {
    let baseReserve = baseReserveResult.value
    let quoteReserve = quoteReserveResult.value

    pair.baseReserveExact = baseReserve
    pair.baseReserve = decimals.toDecimals(pair.baseReserveExact, pair.decimals)
    pair.quoteReserveExact = quoteReserve
    pair.quoteReserve = decimals.toDecimals(pair.quoteReserveExact, pair.decimals)
  }

  pair.baseToken = baseTokenResult.reverted ? constants.ADDRESS_ZERO : baseTokenResult.value
  pair.quoteToken = quoteTokenResult.reverted ? constants.ADDRESS_ZERO : quoteTokenResult.value
  pair.swapFee = swapFeeResult.reverted ? constants.BIGINT_ZERO : swapFeeResult.value

  if (!totalSupplyResult.reverted) {
    let totalSupply = totalSupplyResult.value
    pair.totalSupplyExact = totalSupply
    pair.totalSupply = decimals.toDecimals(totalSupply, pair.decimals)
  }

  let oneBig = constants.BIGINT_ONE.times(BigInt.fromI32(10).pow(pair.decimals))

  let baseTokenPriceResult = endpoint.try_getQuoteToBasePrice(oneBig)
  let quoteTokenPriceResult = endpoint.try_getBaseToQuotePrice(oneBig)

  if (!baseTokenPriceResult.reverted) {
    pair.baseTokenPriceExact = baseTokenPriceResult.value
    pair.baseTokenPrice = decimals.toDecimals(baseTokenPriceResult.value, pair.decimals)
  } else {
    pair.baseTokenPriceExact = constants.BIGINT_ZERO
    pair.baseTokenPrice = constants.BIGDECIMAL_ZERO
  }

  if (!quoteTokenPriceResult.reverted) {
    pair.quoteTokenPriceExact = quoteTokenPriceResult.value
    pair.quoteTokenPrice = decimals.toDecimals(quoteTokenPriceResult.value, pair.decimals)
  } else {
    pair.quoteTokenPriceExact = constants.BIGINT_ZERO
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