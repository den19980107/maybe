class CreateInvestmentCostEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :investment_cost_entries, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.date :date, null: false
      t.string :ticker, null: false
      t.decimal :quantity, precision: 24, scale: 10, null: false
      t.decimal :price_per_share, precision: 24, scale: 10, null: false
      t.decimal :total_paid, precision: 24, scale: 8, null: false
      t.timestamps
    end

    add_index :investment_cost_entries, [ :account_id, :ticker, :date ]
    add_check_constraint :investment_cost_entries, "quantity > 0 AND price_per_share > 0 AND total_paid > 0", name: "investment_cost_entries_positive_amounts"
  end
end
