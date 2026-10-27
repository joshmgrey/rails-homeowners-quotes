require "rails_helper"

RSpec.describe ProRataRefund do
  # 365-day term at $3,650, so every day is worth exactly $10 (1,000 cents).
  let(:effective_on) { Date.new(2026, 11, 1) }
  let(:expires_on) { Date.new(2027, 11, 1) }
  let(:premium_cents) { 3_650_00 }

  def refund(cancel_on, **overrides)
    described_class.call(
      premium_cents: premium_cents, effective_on: effective_on, expires_on: expires_on, cancel_on: cancel_on,
      **overrides
    )
  end

  describe "edge days" do
    it "refunds everything when cancelled on the effective date" do
      expect(refund(effective_on)).to eq(3_650_00)
    end

    it "refunds everything when cancelled before the effective date" do
      expect(refund(effective_on - 10)).to eq(3_650_00)
    end

    it "keeps one day when cancelled the day after the effective date" do
      expect(refund(effective_on + 1)).to eq(3_640_00)
    end

    it "refunds one day when cancelled on the last covered day" do
      expect(refund(expires_on - 1)).to eq(10_00)
    end

    it "refunds nothing when cancelled on the expiry date" do
      expect(refund(expires_on)).to eq(0)
    end

    it "refunds nothing when cancelled after expiry" do
      expect(refund(expires_on + 30)).to eq(0)
    end
  end

  it "refunds the unused days mid-term" do
    # May 1 to Nov 1, 2027 is 184 days.
    expect(refund(Date.new(2027, 5, 1))).to eq(1_840_00)
  end

  context "with a leap-year term" do
    # Nov 1, 2027 to Nov 1, 2028 includes Feb 29, 2028: 366 days.
    let(:effective_on) { Date.new(2027, 11, 1) }
    let(:expires_on) { Date.new(2028, 11, 1) }
    let(:premium_cents) { 3_660_00 }

    it "divides by 366 days" do
      expect(refund(effective_on)).to eq(3_660_00)
      expect(refund(expires_on - 1)).to eq(10_00)
    end

    it "counts Feb 29 as a used day" do
      # Mar 1 to Nov 1, 2028 is 245 days.
      expect(refund(Date.new(2028, 3, 1))).to eq(2_450_00)
    end
  end

  it "rounds down to the cent" do
    # $10 premium, 1 of 365 days unused = 2.74 cents
    expect(refund(expires_on - 1, premium_cents: 10_00)).to eq(2)
  end

  it "raises for a term with no days" do
    expect { refund(effective_on, expires_on: effective_on) }.to raise_error(ArgumentError)
  end
end
