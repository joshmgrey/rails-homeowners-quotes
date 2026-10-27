class Quote < ApplicationRecord
  VALID_FOR = 30.days
  MIN_COVERAGE_CENTS = 100_000_00
  MAX_COVERAGE_CENTS = 2_000_000_00

  has_one :policy, dependent: :restrict_with_error

  enum :status, { pending: "pending", bound: "bound" }, validate: true

  # Quotes a homeowner could still bind. Uses > (not >=) to match #expired?,
  # so a quote is never both active and expired at the same instant.
  scope :active, -> { pending.where("expires_at > ?", Time.current) }

  validates :state, inclusion: { in: PremiumCalculator::BASE_RATES.keys, message: "is not a state we write in" }
  validates :street_address, presence: true
  validates :zip, format: { with: /\A\d{5}\z/ }
  validates :year_built, numericality: { only_integer: true, greater_than: 1800, less_than_or_equal_to: -> { Date.current.year } }
  validates :roof_age_years, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :dwelling_coverage_cents, numericality: {
    only_integer: true,
    greater_than_or_equal_to: MIN_COVERAGE_CENTS,
    less_than_or_equal_to: MAX_COVERAGE_CENTS
  }

  # Runs after validation passes, so the calculator always gets clean inputs.
  before_create :assign_premium_and_expiry

  def expired?
    expires_at <= Time.current
  end

  def as_json(options = {})
    super({
      only: %i[id state street_address zip year_built roof_age_years dwelling_coverage_cents premium_cents status expires_at]
    }.merge(options))
  end

  private

  def assign_premium_and_expiry
    self.premium_cents = PremiumCalculator.call(
      state: state,
      dwelling_coverage_cents: dwelling_coverage_cents,
      year_built: year_built,
      roof_age_years: roof_age_years
    )
    self.expires_at = VALID_FOR.from_now
  end
end
