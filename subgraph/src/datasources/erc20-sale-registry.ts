import {
  SaleAdded as SaleAddedEvent,
} from '../../generated/saleregistry/StarterKitERC20SaleRegistry';
import { sale } from '../../generated/templates';
import { fetchERC20Sale } from '../fetch/erc20-sale';

export function handleSaleAdded(event: SaleAddedEvent): void {
  let contract = fetchERC20Sale(event.params.saleAddress)
  contract.save()

  sale.create(event.params.saleAddress)
}
