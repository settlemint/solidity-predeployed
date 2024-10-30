import {
  constants,
  decimals,
  events,
  transactions,
} from '@amxx/graphprotocol-utils';
import { ERC20TokenVolume, ERC20Transfer } from '../../generated/schema';
import {
  Approval as ApprovalEvent,
  Transfer as TransferEvent,
} from '../../generated/templates/token/StarterKitERC20';
import {
  fetchAccount,
} from '../fetch/account';
import {
  fetchERC20,
  fetchERC20Approval,
  fetchERC20Balance,
} from '../fetch/erc20';

export function handleTransfer(event: TransferEvent): void {
  let contract = fetchERC20(event.address)
  let ev = new ERC20Transfer(events.id(event))

  // Set Event interface fields
  ev.emitter = contract.asAccount
  ev.transaction = transactions.log(event).id
  ev.timestamp = event.block.timestamp

  // Set ERC20Transfer specific fields
  ev.contract = contract.id
  ev.value = decimals.toDecimals(event.params.value, contract.decimals)
  ev.valueExact = event.params.value

  if (event.params.from != constants.ADDRESS_ZERO) {
    let from = fetchAccount(event.params.from)
    let fromBalance = fetchERC20Balance(contract, from)
    fromBalance.valueExact = fromBalance.valueExact.minus(event.params.value)
    fromBalance.value = decimals.toDecimals(fromBalance.valueExact, contract.decimals)
    fromBalance.save()
    ev.from = from.id
    ev.fromBalance = fromBalance.id
  }

  if (event.params.to != constants.ADDRESS_ZERO) {
    let to = fetchAccount(event.params.to)
    let toBalance = fetchERC20Balance(contract, to)
    toBalance.valueExact = toBalance.valueExact.plus(event.params.value)
    toBalance.value = decimals.toDecimals(toBalance.valueExact, contract.decimals)
    toBalance.save()
    ev.to = to.id
    ev.toBalance = toBalance.id
  }

  ev.save()

  // Update volume tracking with proper Int8 ID and Timestamp
  let volume = new ERC20TokenVolume("auto")
  volume.token = contract.id
  volume.timestamp = event.block.timestamp.toI32()
  volume.volume = event.params.value
  volume.transferCount = 1
  volume.save()
}

export function handleApproval(event: ApprovalEvent): void {
  let contract = fetchERC20(event.address)

  let owner = fetchAccount(event.params.owner)
  let spender = fetchAccount(event.params.spender)
  let approval = fetchERC20Approval(contract, owner, spender)
  approval.valueExact = event.params.value
  approval.value = decimals.toDecimals(event.params.value, contract.decimals)
  approval.save()
}