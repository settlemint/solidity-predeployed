import { constants, decimals, transactions } from '@amxx/graphprotocol-utils';
import { Address } from '@graphprotocol/graph-ts';
import {
  ERC20DexBurn,
  ERC20DexMint,
  ERC20DexPairSnapshot,
  ERC20DexSwap,
  EmergencyWithdraw,
  FeeUpdate
} from '../../generated/schema';
import {
  Burn as BurnEvent,
  EmergencyWithdraw as EmergencyWithdrawEvent,
  FeeUpdated as FeeUpdatedEvent,
  Mint as MintEvent,
  Swap as SwapEvent
} from '../../generated/templates/StarterKitERC20Dex/StarterKitERC20Dex';
import { fetchAccount } from '../fetch/account';
import { fetchDex } from '../fetch/dex';
import { fetchERC20 } from '../fetch/erc20';

export function handleMint(event: MintEvent): void {
  let pair = fetchDex(event.address)
  let sender = fetchAccount(event.params.sender)
  let baseContract = fetchERC20(Address.fromBytes(pair.baseToken))
  let quoteContract = fetchERC20(Address.fromBytes(pair.quoteToken))

  let mint = new ERC20DexMint(event.transaction.hash.toHexString())
  mint.pair = pair.id
  mint.sender = sender.id
  mint.transaction = transactions.log(event).id
  mint.timestamp = event.block.timestamp
  mint.emitter = event.address

  mint.baseAmountExact = event.params.baseAmount
  mint.baseAmount = decimals.toDecimals(mint.baseAmountExact, baseContract.decimals)
  mint.quoteAmountExact = event.params.quoteAmount
  mint.quoteAmount = decimals.toDecimals(mint.quoteAmountExact, quoteContract.decimals)
  mint.liquidityExact = event.params.liquidity
  mint.liquidity = decimals.toDecimals(mint.liquidityExact, baseContract.decimals)

  mint.save()

  let snapshot = new ERC20DexPairSnapshot("auto")
  snapshot.pair = pair.id
  snapshot.baseReserve = pair.baseReserve
  snapshot.baseReserveExact = pair.baseReserveExact
  snapshot.quoteReserve = pair.quoteReserve
  snapshot.quoteReserveExact = pair.quoteReserveExact
  snapshot.totalSupply = pair.totalSupply
  snapshot.totalSupplyExact = pair.totalSupplyExact
  snapshot.baseTokenPrice = pair.baseTokenPrice
  snapshot.baseTokenPriceExact = pair.baseReserveExact
  snapshot.quoteTokenPrice = pair.quoteTokenPrice
  snapshot.quoteTokenPriceExact = pair.quoteReserveExact
  snapshot.volumeBaseToken = event.params.baseAmount.toBigDecimal()
  snapshot.volumeBaseTokenExact = event.params.baseAmount
  snapshot.volumeQuoteToken = event.params.quoteAmount.toBigDecimal()
  snapshot.volumeQuoteTokenExact = event.params.quoteAmount
  snapshot.txCount = constants.BIGINT_ONE
  snapshot.liquidity = event.params.liquidity.toBigDecimal()
  snapshot.liquidityExact = event.params.liquidity
  snapshot.save()
}

export function handleBurn(event: BurnEvent): void {
  let pair = fetchDex(event.address)
  let sender = fetchAccount(event.params.sender)
  let baseContract = fetchERC20(Address.fromBytes(pair.baseToken))
  let quoteContract = fetchERC20(Address.fromBytes(pair.quoteToken))

  let burn = new ERC20DexBurn(event.transaction.hash.toHexString())
  burn.pair = pair.id
  burn.sender = sender.id
  burn.transaction = transactions.log(event).id
  burn.timestamp = event.block.timestamp
  burn.emitter = event.address

  burn.baseAmountExact = event.params.baseAmount
  burn.baseAmount = decimals.toDecimals(burn.baseAmountExact, baseContract.decimals)
  burn.quoteAmountExact = event.params.quoteAmount
  burn.quoteAmount = decimals.toDecimals(burn.quoteAmountExact, quoteContract.decimals)
  burn.liquidityExact = event.params.liquidity
  burn.liquidity = decimals.toDecimals(burn.liquidityExact, baseContract.decimals)

  burn.save()

  let snapshot = new ERC20DexPairSnapshot("auto")
  snapshot.pair = pair.id
  snapshot.baseReserve = pair.baseReserve
  snapshot.baseReserveExact = pair.baseReserveExact
  snapshot.quoteReserve = pair.quoteReserve
  snapshot.quoteReserveExact = pair.quoteReserveExact
  snapshot.totalSupply = pair.totalSupply
  snapshot.totalSupplyExact = pair.totalSupplyExact
  snapshot.baseTokenPrice = pair.baseTokenPrice
  snapshot.baseTokenPriceExact = pair.baseReserveExact
  snapshot.quoteTokenPrice = pair.quoteTokenPrice
  snapshot.quoteTokenPriceExact = pair.quoteReserveExact
  snapshot.volumeBaseToken = event.params.baseAmount.toBigDecimal()
  snapshot.volumeBaseTokenExact = event.params.baseAmount
  snapshot.volumeQuoteToken = event.params.quoteAmount.toBigDecimal()
  snapshot.volumeQuoteTokenExact = event.params.quoteAmount
  snapshot.txCount = constants.BIGINT_ONE
  snapshot.liquidity = event.params.liquidity.toBigDecimal()
  snapshot.liquidityExact = event.params.liquidity
  snapshot.save()
}

export function handleSwap(event: SwapEvent): void {
  let pair = fetchDex(event.address)
  let sender = fetchAccount(event.params.sender)
  let baseContract = fetchERC20(Address.fromBytes(pair.baseToken))
  let quoteContract = fetchERC20(Address.fromBytes(pair.quoteToken))

  let swap = new ERC20DexSwap(event.transaction.hash.toHexString())
  swap.pair = pair.id
  swap.sender = sender.id
  swap.transaction = transactions.log(event).id
  swap.timestamp = event.block.timestamp
  swap.emitter = event.address

  swap.baseAmountInExact = event.params.baseAmountIn
  swap.baseAmountIn = decimals.toDecimals(swap.baseAmountInExact, baseContract.decimals)
  swap.quoteAmountInExact = event.params.quoteAmountIn
  swap.quoteAmountIn = decimals.toDecimals(swap.quoteAmountInExact, quoteContract.decimals)
  swap.baseAmountOutExact = event.params.baseAmountOut
  swap.baseAmountOut = decimals.toDecimals(swap.baseAmountOutExact, baseContract.decimals)
  swap.quoteAmountOutExact = event.params.quoteAmountOut
  swap.quoteAmountOut = decimals.toDecimals(swap.quoteAmountOutExact, quoteContract.decimals)

  swap.save()

  let snapshot = new ERC20DexPairSnapshot("auto")
  snapshot.pair = pair.id
  snapshot.baseReserve = pair.baseReserve
  snapshot.baseReserveExact = pair.baseReserveExact
  snapshot.quoteReserve = pair.quoteReserve
  snapshot.quoteReserveExact = pair.quoteReserveExact
  snapshot.totalSupply = pair.totalSupply
  snapshot.totalSupplyExact = pair.totalSupplyExact
  snapshot.baseTokenPrice = pair.baseTokenPrice
  snapshot.baseTokenPriceExact = pair.baseReserveExact
  snapshot.quoteTokenPrice = pair.quoteTokenPrice
  snapshot.quoteTokenPriceExact = pair.quoteReserveExact
  snapshot.volumeBaseToken = event.params.baseAmountIn.plus(event.params.baseAmountOut).toBigDecimal()
  snapshot.volumeBaseTokenExact = event.params.baseAmountIn.plus(event.params.baseAmountOut)
  snapshot.volumeQuoteToken = event.params.quoteAmountIn.plus(event.params.quoteAmountOut).toBigDecimal()
  snapshot.volumeQuoteTokenExact = event.params.quoteAmountIn.plus(event.params.quoteAmountOut)
  snapshot.liquidity = constants.BIGDECIMAL_ZERO
  snapshot.liquidityExact = constants.BIGINT_ZERO
  snapshot.txCount = constants.BIGINT_ONE
  snapshot.save()
}

export function handleEmergencyWithdraw(event: EmergencyWithdrawEvent): void {
  let pair = fetchDex(event.address)
  let token = fetchERC20(event.params.token)

  let withdraw = new EmergencyWithdraw(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )

  withdraw.pair = pair.id
  withdraw.token = token.id
  withdraw.amount = event.params.amount
  withdraw.timestamp = event.block.timestamp
  withdraw.transaction = transactions.log(event).id
  withdraw.emitter = event.address

  withdraw.save()
  pair.save()
}

export function handleFeeUpdated(event: FeeUpdatedEvent): void {
  let pair = fetchDex(event.address)

  let feeUpdate = new FeeUpdate(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  )

  feeUpdate.pair = pair.id
  feeUpdate.oldFee = event.params.oldFee
  feeUpdate.newFee = event.params.newFee
  feeUpdate.timestamp = event.block.timestamp
  feeUpdate.transaction = transactions.log(event).id
  feeUpdate.emitter = event.address
  feeUpdate.save()
}
