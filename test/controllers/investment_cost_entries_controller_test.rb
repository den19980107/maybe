require "test_helper"

class InvestmentCostEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @account = accounts(:investment)
    entries(:valuation).update_columns(account_id: @account.id)
  end

  test "creates a buy without touching balances, holdings, entries, valuations or sync" do
    balance = @account.balance
    valuation = entries(:valuation).attributes
    holdings = @account.holdings.pluck(:id, :qty, :amount)

    assert_difference "InvestmentCostEntry.count", 1 do
      assert_no_difference [ "Entry.count", "Trade.count", "Valuation.count", "Holding.count", "Balance.count" ] do
        assert_no_enqueued_jobs do
          post account_investment_cost_entries_path(@account), params: {
            investment_cost_entry: { date: "2025-01-02", ticker: "AAPL", quantity: "2", price_per_share: "10", total_paid: "22" }
          }
        end
      end
    end

    assert_redirected_to account_investment_cost_entries_path(@account)
    assert_equal balance, @account.reload.balance
    assert_equal valuation, entries(:valuation).reload.attributes
    assert_equal holdings, @account.holdings.pluck(:id, :qty, :amount)
    assert_equal BigDecimal("22"), @account.investment_cost_entries.last.total_paid
  end

  test "rejects invalid numbers without writing" do
    assert_no_difference "InvestmentCostEntry.count" do
      post account_investment_cost_entries_path(@account), params: {
        investment_cost_entry: { date: "2025-01-02", ticker: "AAPL", quantity: "-1", price_per_share: "0" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "ledger displays cumulative purchase labels and running totals" do
    @account.investment_cost_entries.create!(date: Date.new(2025, 1, 2), ticker: "AAPL", quantity: 2, price_per_share: 10, total_paid: 22)
    get account_investment_cost_entries_path(@account)
    assert_response :success
    assert_select "h1", text: "Investment purchase-cost ledger"
    assert_select "h2", text: "Cumulative purchases by ticker"
    assert_select "p", /not remaining cost basis/
    assert_select "td", text: "22.00"
  end

  test "other family's account is not accessible for index or create" do
    other = Account.create!(family: families(:empty), name: "Other brokerage", currency: "USD", balance: 100, accountable: Investment.new)
    entries(:valuation).update_columns(account_id: other.id)
    assert other.investment_cost_ledger_available?
    get account_investment_cost_entries_path(other)
    assert_response :not_found
    assert_no_difference "InvestmentCostEntry.count" do
      post account_investment_cost_entries_path(other), params: {
        investment_cost_entry: { date: "2025-01-02", ticker: "AAPL", quantity: "1", price_per_share: "10" }
      }
    end
    assert_response :not_found
  end

  test "only manual investment accounts with valuations can use ledger" do
    get account_investment_cost_entries_path(accounts(:depository))
    assert_response :not_found
    entries(:valuation).update_columns(account_id: accounts(:depository).id)
    get account_investment_cost_entries_path(@account)
    assert_response :not_found

    entries(:valuation).update_columns(account_id: @account.id)
    @account.update_columns(plaid_account_id: plaid_accounts(:one).id)
    get account_investment_cost_entries_path(@account)
    assert_response :not_found
  end
end
