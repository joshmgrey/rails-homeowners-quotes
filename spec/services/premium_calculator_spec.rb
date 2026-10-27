require "rails_helper"

RSpec.describe PremiumCalculator do
  let(:today) { Date.new(2026, 10, 27) }
  let(:inputs) do
    { state: "FL", dwelling_coverage_cents: 300_000_00, year_built: 1995, roof_age_years: 8, today: today }
  end

  def premium(**overrides) = described_class.call(**inputs.merge(overrides))

  it "charges the state base rate per $1,000 of coverage" do
    # 300 thousands x 1,200 cents = $3,600
    expect(premium).to eq(3_600_00)
  end

  it "discounts new roofs and surcharges old ones" do
    expect(premium(roof_age_years: 3)).to eq(3_240_00)
    expect(premium(roof_age_years: 18)).to eq(4_500_00)
    expect(premium(roof_age_years: 25)).to eq(5_400_00)
  end

  it "surcharges homes older than 40 years" do
    expect(premium(year_built: 1980)).to eq(4_140_00)
  end

  it "uses each state's own base rate" do
    expect(premium(state: "TX")).to eq(2_850_00)
  end

  it "never goes below the minimum premium" do
    expect(premium(state: "SC", dwelling_coverage_cents: 50_000_00, roof_age_years: 1))
      .to eq(PremiumCalculator::MINIMUM_PREMIUM_CENTS)
  end

  it "raises for a state we do not write in" do
    expect { premium(state: "NY") }.to raise_error(KeyError)
  end
end
