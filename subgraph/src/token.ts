import { BigDecimal, BigInt } from "@graphprotocol/graph-ts"
import {
  Account,
  Token,
  TokenApproval,
  TokenBalance,
  TokenTransfer,
  TokenVolume
} from "../generated/schema"
import {
  Approval as ApprovalEvent,
  StarterKitERC20 as TokenContract,
  Transfer as TransferEvent
} from "../generated/templates/token/StarterKitERC20"

export function handleApproval(event: ApprovalEvent): void {
  let token = Token.load(event.address)
  if (token == null) {
    return
  }

  let ownerId = event.params.owner
  let spenderId = event.params.spender
  let approvalId = `${token.id.toHexString()}-${ownerId}-${spenderId}`

  let approval = TokenApproval.load(approvalId)
  if (approval == null) {
    approval = new TokenApproval(approvalId)
    approval.token = token.id
    approval.owner = ownerId
    approval.spender = spenderId
    approval.createdAt = event.block.timestamp
  }

  approval.valueExact = event.params.value
  approval.value = event.params.value.toBigDecimal().div(BigDecimal.fromString("1e18"))
  approval.updatedAt = event.block.timestamp

  approval.save()

  // Update or create Account entities
  let owner = Account.load(ownerId)
  if (owner == null) {
    owner = new Account(ownerId)
    owner.createdAt = event.block.timestamp
    owner.nativeValue = BigDecimal.zero()
    owner.nativeValueExact = BigInt.zero()
  }
  owner.updatedAt = event.block.timestamp
  owner.lastTransactionTimestamp = event.block.timestamp
  owner.save()

  let spender = Account.load(spenderId)
  if (spender == null) {
    spender = new Account(spenderId)
    spender.createdAt = event.block.timestamp
    spender.nativeValue = BigDecimal.zero()
    spender.nativeValueExact = BigInt.zero()
  }
  spender.updatedAt = event.block.timestamp
  spender.lastTransactionTimestamp = event.block.timestamp
  spender.save()
}

export function handleTransfer(event: TransferEvent): void {
  let token = Token.load(event.address)
  if (token == null) {
    return
  }

  let fromId = event.params.from
  let toId = event.params.to
  let transferId = `${event.transaction.hash.toHexString()}-${event.logIndex.toString()}`

  let transfer = new TokenTransfer(transferId)
  transfer.token = token.id
  transfer.timestamp = event.block.timestamp
  transfer.from = fromId
  transfer.to = toId
  transfer.valueExact = event.params.value
  transfer.value = event.params.value.toBigDecimal().div(BigDecimal.fromString("1e18"))
  transfer.emitter = event.address
  transfer.transaction = event.transaction.hash

  // Update balances
  let fromBalance = TokenBalance.load(`${token.id.toHexString()}-${fromId}`)
  if (fromBalance == null) {
    fromBalance = new TokenBalance(`${token.id.toHexString()}-${fromId}`)
    fromBalance.token = token.id
    fromBalance.account = fromId
    fromBalance.valueExact = BigInt.fromI32(0)
    fromBalance.value = BigDecimal.zero()
    fromBalance.createdAt = event.block.timestamp
  }
  fromBalance.valueExact = fromBalance.valueExact.minus(event.params.value)
  fromBalance.value = fromBalance.valueExact.toBigDecimal().div(BigDecimal.fromString("1e18"))
  fromBalance.updatedAt = event.block.timestamp
  fromBalance.save()

  let toBalance = TokenBalance.load(`${token.id.toHexString()}-${toId}`)
  if (toBalance == null) {
    toBalance = new TokenBalance(`${token.id.toHexString()}-${toId}`)
    toBalance.token = token.id
    toBalance.account = toId
    toBalance.valueExact = BigInt.fromI32(0)
    toBalance.value = BigDecimal.zero()
    toBalance.createdAt = event.block.timestamp
  }
  toBalance.valueExact = toBalance.valueExact.plus(event.params.value)
  toBalance.value = toBalance.valueExact.toBigDecimal().div(BigDecimal.fromString("1e18"))
  toBalance.updatedAt = event.block.timestamp
  toBalance.save()

  transfer.fromBalance = fromBalance.id
  transfer.toBalance = toBalance.id
  transfer.save()

  // Update or create Account entities
  let from = Account.load(fromId)
  if (from == null) {
    from = new Account(fromId)
    from.createdAt = event.block.timestamp
    from.nativeValue = BigDecimal.zero()
    from.nativeValueExact = BigInt.zero()
  }
  from.updatedAt = event.block.timestamp
  from.lastTransactionTimestamp = event.block.timestamp
  from.save()

  let to = Account.load(toId)
  if (to == null) {
    to = new Account(toId)
    to.createdAt = event.block.timestamp
    to.nativeValue = BigDecimal.zero()
    to.nativeValueExact = BigInt.zero()
  }
  to.updatedAt = event.block.timestamp
  to.lastTransactionTimestamp = event.block.timestamp
  to.save()

  // Update Token
  let contract = TokenContract.bind(event.address)
  token.totalSupply = contract.totalSupply()
  token.tokenHolders = BigInt.fromI32(token.tokenHolders.toI32() + (toBalance.valueExact.isZero() ? 1 : 0) - (fromBalance.valueExact.isZero() ? 1 : 0))
  token.updatedAt = event.block.timestamp
  token.value = token.totalSupply.toBigDecimal().div(BigDecimal.fromString("1e18"))
  token.valueExact = token.totalSupply
  token.save()

  // Update TokenVolume
  let volumeId = `${token.id.toHexString()}-${event.block.timestamp.toString()}`
  let volume = TokenVolume.load(volumeId)
  if (volume == null) {
    volume = new TokenVolume(volumeId)
    volume.token = token.id
    volume.timestamp = event.block.timestamp.toI32()
    volume.volume = BigInt.fromI32(0)
    volume.transferCount = 0
  }
  volume.volume = volume.volume.plus(event.params.value)
  volume.transferCount += 1
  volume.save()
}
