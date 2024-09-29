import { BigDecimal, BigInt } from "@graphprotocol/graph-ts";
import { TokenAdded as TokenAddedEvent } from "../generated/registry/StarterKitERC20Registry";
import { Account, Registry, Token } from "../generated/schema";
import { token as TokenTemplate } from '../generated/templates';

export function handleTokenAdded(event: TokenAddedEvent): void {
  let registry = Registry.load(event.address)
  if (registry == null) {
    registry = new Registry(event.address)
    registry.createdAt = event.block.timestamp
  }
  registry.updatedAt = event.block.timestamp
  registry.save()

  let tokenAddress = event.params.tokenAddress
  let token = Token.load(tokenAddress)
  if (token == null) {
    token = new Token(tokenAddress)
    token.createdAt = event.block.timestamp
    token.totalSupply = BigInt.fromI32(0)
    token.tokenHolders = BigInt.fromI32(0)
    token.value = BigDecimal.fromString("0")
    token.valueExact = BigInt.fromI32(0)
  }
  token.factory = event.params.factoryAddress
  token.decimals = 18
  token.name = event.params.name
  token.symbol = event.params.symbol
  token.extraData = event.params.extraData
  token.registry = event.address
  token.updatedAt = event.block.timestamp
  token.save()

  let account = Account.load(tokenAddress)
  if (account == null) {
    account = new Account(tokenAddress)
    account.createdAt = event.block.timestamp
  }
  account.asToken = tokenAddress
  account.nativeValue = BigDecimal.fromString("0")
  account.nativeValueExact = BigInt.fromI32(0)
  account.updatedAt = event.block.timestamp
  account.save()

  // Create a new instance of the Token template
  TokenTemplate.create(tokenAddress)
}
