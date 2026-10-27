require "rails_helper"

RSpec.describe Quote, type: :model do
  it "prices the quote and sets a 30-day expiry on create" do
    freeze_time do
      quote = create(:quote)

      expect(quote.premium_cents).to eq(3_600_00)
      expect(quote.expires_at).to eq(30.days.from_now)
      expect(quote).to be_pending
    end
  end

  it "rejects states we do not write in" do
    quote = build(:quote, state: "NY")

    expect(quote).not_to be_valid
    expect(quote.errors[:state]).to include("is not a state we write in")
  end

  it "rejects coverage outside the allowed range" do
    expect(build(:quote, dwelling_coverage_cents: 50_000_00)).not_to be_valid
    expect(build(:quote, dwelling_coverage_cents: 5_000_000_00)).not_to be_valid
  end

  it "rejects a malformed zip" do
    expect(build(:quote, zip: "3313")).not_to be_valid
  end

  it "rejects a year built in the future" do
    expect(build(:quote, year_built: Date.current.year + 1)).not_to be_valid
  end

  describe "#expired?" do
    it "is false before expires_at and true after" do
      quote = create(:quote)

      expect(quote).not_to be_expired
      travel_to(31.days.from_now) { expect(quote).to be_expired }
    end
  end
end
