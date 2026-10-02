require "test_helper"

class InvestmentCostEntryTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:investment)
    entries(:valuation).update_columns(account_id: @account.id)
  end

  test "cumulative quantity and weighted average use actual total paid including fees" do
    @account.investment_cost_entries.create!(date: Date.new(2025, 1, 2), ticker: "aapl", quantity: 2, price_per_share: 10, total_paid: 22)
    @account.investment_cost_entries.create!(date: Date.new(2025, 1, 1), ticker: "AAPL", quantity: 3, price_per_share: 20)
    @account.investment_cost_entries.create!(date: Date.new(2025, 1, 3), ticker: "MSFT", quantity: 1, price_per_share: 8)

    summary = @account.investment_cost_summary.fetch("AAPL")
    assert_equal BigDecimal("5"), summary[:quantity]
    assert_equal BigDecimal("82"), summary[:total_paid]
    assert_equal BigDecimal("16.4"), summary[:average_cost]
    assert_equal BigDecimal("8"), @account.investment_cost_summary.fetch("MSFT")[:total_paid]
  end

  test "rejects numbers outside database precision before insert" do
    too_small = @account.investment_cost_entries.build(date: Date.current, ticker: "AAPL", quantity: "0.00000000001", price_per_share: "10")
    assert_not too_small.valid?
    assert too_small.errors[:quantity].any?

    too_large = @account.investment_cost_entries.build(date: Date.current, ticker: "AAPL", quantity: "100000000000000", price_per_share: "1")
    assert_not too_large.valid?
    assert too_large.errors[:quantity].any?
  end

  test "requires positive numbers, valid ticker and eligible manual investment with a valuation" do
    entry = @account.investment_cost_entries.build(date: Date.current, ticker: "AAPL", quantity: 0, price_per_share: -1, total_paid: 0)
    assert_not entry.valid?
    assert entry.errors[:quantity].any?
    assert entry.errors[:price_per_share].any?
    assert entry.errors[:total_paid].any?

    entry.assign_attributes(quantity: 1, price_per_share: 5, total_paid: 5, ticker: " ")
    assert_not entry.valid?
    assert entry.errors[:ticker].any?

    entry.ticker = "AAPL"
    entries(:valuation).update_columns(account_id: accounts(:depository).id)
    assert_not entry.valid?
    assert entry.errors[:account].any?
  end
end
