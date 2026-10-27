class AddExpiredToQuoteStatus < ActiveRecord::Migration[8.0]
  # Passing the old expression to remove_check_constraint keeps this reversible.
  # Rolling back fails if any quote is already "expired", which is what you want.
  def change
    remove_check_constraint :quotes, "status IN ('pending', 'bound')", name: "quotes_status_check"
    add_check_constraint :quotes, "status IN ('pending', 'bound', 'expired')", name: "quotes_status_check"
  end
end
