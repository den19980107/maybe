class InvestmentCostEntriesController < ApplicationController
  before_action :set_account

  def index
    @purchase = @account.investment_cost_entries.build(date: Date.current)
    load_ledger
  end

  def create
    @purchase = @account.investment_cost_entries.build(purchase_params)

    if @purchase.save
      redirect_to account_investment_cost_entries_path(@account), notice: "Purchase cost recorded"
    else
      load_ledger
      render :index, status: :unprocessable_entity
    end
  end

  private
    def set_account
      @account = Current.family.accounts.find(params[:account_id])
      raise ActiveRecord::RecordNotFound unless @account.investment_cost_ledger_available?
    end

    def purchase_params
      params.require(:investment_cost_entry).permit(:date, :ticker, :quantity, :price_per_share, :total_paid)
    end

    def load_ledger
      @rows = @account.investment_cost_ledger
      @summary = @rows.each_with_object({}) { |row, result| result[row[:entry].ticker] = row }
    end
end
