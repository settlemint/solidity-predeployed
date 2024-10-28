import {
  constants,
  decimals,
} from '@amxx/graphprotocol-utils';
import {
  Address, Bytes
} from '@graphprotocol/graph-ts';
import {
  TokenSale
} from '../../generated/schema';
import { StarterKitERC20Sale } from '../../generated/templates/sale/StarterKitERC20Sale';

export function fetchERC20Sale(address: Address): TokenSale {
  let sale = TokenSale.load(address)

  let endpoint = StarterKitERC20Sale.bind(address)

  if (sale == null) {
    let pricePerToken = endpoint.try_pricePerToken()
    let minPurchase = endpoint.try_minPurchase()
    let maxPurchase = endpoint.try_maxPurchase()
    let saleActive = endpoint.try_saleActive()
    let tokenForSale = endpoint.try_TOKEN_FOR_SALE()
    let tokenForPayment = endpoint.try_TOKEN_FOR_PAYMENT()
    let owner = endpoint.try_owner()

    sale = new TokenSale(address)
    sale.pricePerToken = pricePerToken.reverted ? constants.BIGDECIMAL_ZERO : decimals.toDecimals(pricePerToken.value, 18)
    sale.pricePerTokenExact = pricePerToken.reverted ? constants.BIGINT_ZERO : pricePerToken.value
    sale.minPurchase = minPurchase.reverted ? constants.BIGINT_ZERO : minPurchase.value
    sale.maxPurchase = maxPurchase.reverted ? constants.BIGINT_ZERO : maxPurchase.value
    sale.saleActive = saleActive.reverted ? false : saleActive.value
    sale.tokenForSale = tokenForSale.reverted ? Bytes.empty() : tokenForSale.value
    sale.tokenForPayment = tokenForPayment.reverted ? Bytes.empty() : tokenForPayment.value
    sale.owner = owner.reverted ? Bytes.empty() : owner.value
    sale.save()
  }

  return sale
}
