# Independent, buy-only purchase-cost records. These are not Trades, Entries or Holdings.
# Totals are cumulative purchases, NOT remaining tax basis after sales or splits.
class InvestmentCostEntry < ApplicationRecord
  belongs_to :account

  before_validation :normalize_ticker_and_total

  validates :date, presence: true
  validates :ticker, presence: true, format: { with: /\A[A-Z0-9][A-Z0-9.\-]*\z/, message: "must be a ticker (letters, numbers, dots or hyphens)" }
  validates :quantity, :price_per_share, numericality: { greater_than_or_equal_to: BigDecimal("0.0000000001"), less_than: 100_000_000_000_000 }
  validates :total_paid, numericality: { greater_than_or_equal_to: BigDecimal("0.00000001"), less_than: 10_000_000_000_000_000 }
  validate :eligible_account

  private
    def normalize_ticker_and_total
      self.ticker = ticker&.strip&.upcase
      self.total_paid = quantity * price_per_share if total_paid.nil? && quantity && price_per_share
    end

    def eligible_account
      return if account&.investment_cost_ledger_available?

      errors.add(:account, "must be a manual investment account with a valuation")
    end
end
