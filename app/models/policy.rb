class Policy < ApplicationRecord
  TERM = 1.year

  belongs_to :quote

  enum :status, { active: "active", cancelled: "cancelled" }, validate: true

  validates :policy_number, :idempotency_key, presence: true, uniqueness: true
  validates :quote_id, uniqueness: true
  validates :premium_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :effective_on, :expires_on, presence: true

  def self.generate_number
    "HO-#{SecureRandom.alphanumeric(10).upcase}"
  end

  def as_json(options = {})
    super({
      only: %i[id quote_id policy_number premium_cents effective_on expires_on status cancelled_on refund_cents]
    }.merge(options))
  end
end
