# Toy rating model. Real carriers use filed rate tables per state; this is just
# enough arithmetic to have something worth testing.
class PremiumCalculator
  # Annual base rate per $1,000 of dwelling coverage, in cents.
  BASE_RATES = {
    "FL" => 1_200,
    "TX" => 950,
    "LA" => 1_100,
    "AL" => 800,
    "SC" => 700
  }.freeze

  MINIMUM_PREMIUM_CENTS = 500_00
  OLD_HOME_AGE = 40

  def self.call(...) = new(...).call

  def initialize(state:, dwelling_coverage_cents:, year_built:, roof_age_years:, today: Date.current)
    @state = state
    @dwelling_coverage_cents = dwelling_coverage_cents
    @year_built = year_built
    @roof_age_years = roof_age_years
    @today = today
  end

  # Returns the annual premium in cents.
  def call
    thousands_of_coverage = @dwelling_coverage_cents / 100_000.0
    premium = thousands_of_coverage * BASE_RATES.fetch(@state) * roof_factor * home_age_factor

    [ premium.round, MINIMUM_PREMIUM_CENTS ].max
  end

  private

  # Older roofs are the biggest driver of wind and hail claims.
  def roof_factor
    case @roof_age_years
    when 0..5 then 0.9
    when 6..15 then 1.0
    when 16..20 then 1.25
    else 1.5
    end
  end

  def home_age_factor
    @today.year - @year_built > OLD_HOME_AGE ? 1.15 : 1.0
  end
end
