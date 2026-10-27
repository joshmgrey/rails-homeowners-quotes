class CreateQuotes < ActiveRecord::Migration[8.0]
  def change
    create_table :quotes do |t|
      t.string :state, limit: 2, null: false
      t.string :street_address, null: false
      t.string :zip, null: false
      t.integer :year_built, null: false
      t.integer :roof_age_years, null: false
      t.bigint :dwelling_coverage_cents, null: false
      t.bigint :premium_cents, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_check_constraint :quotes, "status IN ('pending', 'bound')", name: "quotes_status_check"
  end
end
