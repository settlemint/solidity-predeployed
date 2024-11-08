import { PairCreated } from '../../generated/DexFactory/DexFactory';
import { Dex as PairTemplate } from '../../generated/templates';
import { fetchDex } from '../fetch/dex';

export function handlePairCreated(event: PairCreated): void {
  let contract = fetchDex(event.params.pair)
  contract.save()

  PairTemplate.create(event.params.pair)
}
