class CreatePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :policies do |t|
      # One policy per quote, enforced by the database, not just the model.
      t.references :quote, null: false, foreign_key: true, index: { unique: true }
      t.string :policy_number, null: false, index: { unique: true }
      t.string :idempotency_key, null: false, index: { unique: true }
      t.bigint :premium_cents, null: false
      t.date :effective_on, null: false
      t.date :expires_on, null: false

      t.timestamps
    end
  end
end
