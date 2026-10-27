require "rails_helper"

RSpec.describe PolicyCanceller do
  # Factory quote premium is $3,600 for a Nov 1, 2026 to Nov 1, 2027 term.
  let(:policy) do
    QuoteBinder.call(quote: create(:quote), idempotency_key: "key-1", effective_on: Date.new(2026, 11, 1))
  end

  it "cancels the policy and records the pro rata refund" do
    described_class.call(policy: policy, cancel_on: Date.new(2027, 5, 1))

    policy.reload
    expect(policy).to be_cancelled
    expect(policy.cancelled_on).to eq(Date.new(2027, 5, 1))
    # $3,600 x 184 / 365 days = $1,814.79 (rounded down)
    expect(policy.refund_cents).to eq(1_814_79)
  end

  it "cancels as of today by default" do
    travel_to(Date.new(2027, 5, 1)) { described_class.call(policy: policy) }

    expect(policy.reload.cancelled_on).to eq(Date.new(2027, 5, 1))
  end

  it "refuses to cancel twice and keeps the first refund" do
    described_class.call(policy: policy, cancel_on: Date.new(2027, 5, 1))

    expect { described_class.call(policy: policy, cancel_on: Date.new(2027, 6, 1)) }
      .to raise_error(PolicyCanceller::AlreadyCancelled)
    expect(policy.reload.refund_cents).to eq(1_814_79)
  end

  it "refuses to cancel on or after the expiry date" do
    expect { described_class.call(policy: policy, cancel_on: policy.expires_on) }
      .to raise_error(PolicyCanceller::PolicyExpired)
    expect(policy.reload).to be_active
  end

  describe "database constraints" do
    it "rejects a refund larger than the premium" do
      expect { policy.update_columns(status: "cancelled", cancelled_on: Date.current, refund_cents: policy.premium_cents + 1) }
        .to raise_error(ActiveRecord::StatementInvalid, /policies_refund_range_check/)
    end

    it "rejects a cancelled policy with no refund recorded" do
      expect { policy.update_columns(status: "cancelled", cancelled_on: Date.current) }
        .to raise_error(ActiveRecord::StatementInvalid, /policies_cancellation_check/)
    end
  end
end
