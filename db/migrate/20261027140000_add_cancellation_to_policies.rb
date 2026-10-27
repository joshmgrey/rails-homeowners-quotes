class AddCancellationToPolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :policies, :status, :string, null: false, default: "active"
    add_column :policies, :cancelled_on, :date
    add_column :policies, :refund_cents, :bigint

    add_check_constraint :policies, "status IN ('active', 'cancelled')", name: "policies_status_check"
    # A cancelled policy has both a date and a refund; an active one has neither.
    add_check_constraint :policies,
      "(status = 'cancelled') = (cancelled_on IS NOT NULL AND refund_cents IS NOT NULL)",
      name: "policies_cancellation_check"
    # Never refund more than was paid.
    add_check_constraint :policies, "refund_cents BETWEEN 0 AND premium_cents", name: "policies_refund_range_check"
  end
end
