import {
  TokenAdded as TokenAddedEvent,
} from '../../generated/registry/StarterKitERC20Registry';
import { token } from '../../generated/templates';
import {
  fetchERC20
} from '../fetch/erc20';

export function handleTokenAdded(event: TokenAddedEvent): void {
  let contract = fetchERC20(event.params.tokenAddress)
  contract.extraData = event.params.extraData
  contract.save()

  token.create(event.params.tokenAddress)
}