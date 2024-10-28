import { transactions } from '@amxx/graphprotocol-utils'
import { BigInt } from '@graphprotocol/graph-ts'
import {
  ERC20DexBurn,
  ERC20DexMint,
  ERC20DexSwap
} from '../../generated/schema'
import {
  Burn as BurnEvent,
  Mint as MintEvent,
  Swap as SwapEvent
} from '../../generated/templates/StarterKitERC20Dex/StarterKitERC20Dex'
import { fetchAccount } from '../fetch/account'
import { fetchDex } from '../fetch/dex'

export function handleMint(event: MintEvent): void {
  let pair = fetchDex(event.address)
  let sender = fetchAccount(event.params.sender)

  let mint = new ERC20DexMint(event.transaction.hash.toHexString())
  mint.pair = pair.id
  mint.sender = sender.id
  mint.transaction = transactions.log(event).id
  mint.timestamp = event.block.timestamp
  mint.emitter = event.address

  mint.baseAmountExact = event.params.baseAmount
  mint.baseAmount = event.params.baseAmount.toBigDecimal()
  mint.quoteAmountExact = event.params.quoteAmount
  mint.quoteAmount = event.params.quoteAmount.toBigDecimal()

  mint.save()

  // Update pair reserves
  pair.baseReserveExact = pair.baseReserveExact.plus(event.params.baseAmount)
  pair.baseReserve = pair.baseReserveExact.toBigDecimal()
  pair.quoteReserveExact = pair.quoteReserveExact.plus(event.params.quoteAmount)
  pair.quoteReserve = pair.quoteReserveExact.toBigDecimal()

  // Update prices
  if (pair.quoteReserveExact.gt(BigInt.fromI32(0))) {
    pair.baseTokenPrice = pair.quoteReserve.div(pair.baseReserve)
    pair.quoteTokenPrice = pair.baseReserve.div(pair.quoteReserve)
  }

  pair.save()
}

export function handleBurn(event: BurnEvent): void {
  let pair = fetchDex(event.address)
  let sender = fetchAccount(event.params.sender)

  let burn = new ERC20DexBurn(event.transaction.hash.toHexString())
  burn.pair = pair.id
  burn.sender = sender.id
  burn.transaction = transactions.log(event).id
  burn.timestamp = event.block.timestamp
  burn.emitter = event.address

  burn.baseAmountExact = event.params.baseAmount
  burn.baseAmount = event.params.baseAmount.toBigDecimal()
  burn.quoteAmountExact = event.params.quoteAmount
  burn.quoteAmount = event.params.quoteAmount.toBigDecimal()

  burn.save()

  // Update pair reserves
  pair.baseReserveExact = pair.baseReserveExact.minus(event.params.baseAmount)
  pair.baseReserve = pair.baseReserveExact.toBigDecimal()
  pair.quoteReserveExact = pair.quoteReserveExact.minus(event.params.quoteAmount)
  pair.quoteReserve = pair.quoteReserveExact.toBigDecimal()

  // Update prices
  if (pair.quoteReserveExact.gt(BigInt.fromI32(0))) {
    pair.baseTokenPrice = pair.quoteReserve.div(pair.baseReserve)
    pair.quoteTokenPrice = pair.baseReserve.div(pair.quoteReserve)
  }

  pair.save()
}

export function handleSwap(event: SwapEvent): void {
  let pair = fetchDex(event.address)
  let sender = fetchAccount(event.params.sender)

  let swap = new ERC20DexSwap(event.transaction.hash.toHexString())
  swap.pair = pair.id
  swap.sender = sender.id
  swap.transaction = transactions.log(event).id
  swap.timestamp = event.block.timestamp
  swap.emitter = event.address

  swap.baseAmountInExact = event.params.baseAmountIn
  swap.baseAmountIn = event.params.baseAmountIn.toBigDecimal()
  swap.quoteAmountInExact = event.params.quoteAmountIn
  swap.quoteAmountIn = event.params.quoteAmountIn.toBigDecimal()
  swap.baseAmountOutExact = event.params.baseAmountOut
  swap.baseAmountOut = event.params.baseAmountOut.toBigDecimal()
  swap.quoteAmountOutExact = event.params.quoteAmountOut
  swap.quoteAmountOut = event.params.quoteAmountOut.toBigDecimal()

  swap.save()

  // Update pair reserves
  pair.baseReserveExact = pair.baseReserveExact.plus(event.params.baseAmountIn).minus(event.params.baseAmountOut)
  pair.baseReserve = pair.baseReserveExact.toBigDecimal()
  pair.quoteReserveExact = pair.quoteReserveExact.plus(event.params.quoteAmountIn).minus(event.params.quoteAmountOut)
  pair.quoteReserve = pair.quoteReserveExact.toBigDecimal()

  // Update prices
  if (pair.quoteReserveExact.gt(BigInt.fromI32(0))) {
    pair.baseTokenPrice = pair.quoteReserve.div(pair.baseReserve)
    pair.quoteTokenPrice = pair.baseReserve.div(pair.quoteReserve)
  }

  pair.save()
}
