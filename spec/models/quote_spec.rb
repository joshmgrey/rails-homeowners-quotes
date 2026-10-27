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

  describe ".active" do
    it "includes pending quotes that have not expired" do
      quote = create(:quote)

      expect(Quote.active).to contain_exactly(quote)
    end

    it "excludes pending quotes past expiry, even before the job marks them" do
      create(:quote, :past_expiry)

      expect(Quote.active).to be_empty
    end

    it "excludes bound quotes" do
      quote = create(:quote)
      QuoteBinder.call(quote: quote, idempotency_key: "key-1")

      expect(Quote.active).to be_empty
    end

    it "excludes a quote at the exact moment it expires, matching #past_expiry?" do
      freeze_time do
        quote = create(:quote)
        quote.update_column(:expires_at, Time.current)

        expect(quote).to be_past_expiry
        expect(Quote.active).to be_empty
      end
    end

    it "can be chained with other conditions" do
      fl = create(:quote, state: "FL")
      create(:quote, state: "TX")

      expect(Quote.active.where(state: "FL")).to contain_exactly(fl)
    end
  end

  describe "#past_expiry?" do
    it "is false before expires_at and true after" do
      quote = create(:quote)

      expect(quote).not_to be_past_expiry
      travel_to(31.days.from_now) { expect(quote).to be_past_expiry }
    end
  end

  describe "#expired? (the status enum)" do
    it "reflects the status column, not the clock" do
      quote = create(:quote, :past_expiry)

      expect(quote).to be_past_expiry
      expect(quote).not_to be_expired
    end
  end

  describe "status check constraint" do
    it "allows expired" do
      quote = create(:quote)

      expect { quote.update_column(:status, "expired") }.not_to raise_error
    end

    # update_column skips model validations, so this proves the database
    # itself rejects bad values.
    it "rejects values outside the enum at the database level" do
      quote = create(:quote)

      expect { quote.update_column(:status, "cancelled") }
        .to raise_error(ActiveRecord::StatementInvalid, /quotes_status_check/)
    end
  end
end
