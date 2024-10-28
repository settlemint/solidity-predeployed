import { PairCreated } from '../../generated/StarterKitERC20DexFactory/StarterKitERC20DexFactory';
import { StarterKitERC20Dex as PairTemplate } from '../../generated/templates';
import { fetchDex } from '../fetch/dex';

export function handlePairCreated(event: PairCreated): void {
  let contract = fetchDex(event.params.pair)
  contract.save()

  PairTemplate.create(event.params.pair)
}
