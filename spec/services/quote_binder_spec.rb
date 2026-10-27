require "rails_helper"

RSpec.describe QuoteBinder do
  let(:quote) { create(:quote) }

  it "creates a one-year policy at the quoted premium and marks the quote bound" do
    policy = described_class.call(quote: quote, idempotency_key: "key-1", effective_on: Date.new(2026, 11, 1))

    expect(policy).to be_persisted
    expect(policy.premium_cents).to eq(quote.premium_cents)
    expect(policy.expires_on).to eq(Date.new(2027, 11, 1))
    expect(policy.policy_number).to match(/\AHO-[A-Z0-9]{10}\z/)
    expect(quote.reload).to be_bound
  end

  it "returns the same policy when retried with the same key" do
    first = described_class.call(quote: quote, idempotency_key: "key-1")
    second = described_class.call(quote: quote, idempotency_key: "key-1")

    expect(second).to eq(first)
    expect(Policy.count).to eq(1)
  end

  it "refuses to bind a quote twice with a different key" do
    described_class.call(quote: quote, idempotency_key: "key-1")

    expect { described_class.call(quote: quote, idempotency_key: "key-2") }
      .to raise_error(QuoteBinder::AlreadyBound)
  end

  it "refuses to bind a quote past expiry that the job hasn't marked yet" do
    expired = create(:quote, :past_expiry)

    expect { described_class.call(quote: expired, idempotency_key: "key-1") }
      .to raise_error(QuoteBinder::QuoteExpired)
    expect(expired.reload).to be_pending
  end

  it "refuses to bind a quote ExpireQuotesJob already marked expired" do
    expired = create(:quote, :past_expiry)
    ExpireQuotesJob.perform_now

    expect { described_class.call(quote: expired, idempotency_key: "key-1") }
      .to raise_error(QuoteBinder::QuoteExpired)
    expect(expired.reload).to be_expired
  end

  it "refuses a key that was already used for a different quote" do
    described_class.call(quote: quote, idempotency_key: "key-1")

    expect { described_class.call(quote: create(:quote), idempotency_key: "key-1") }
      .to raise_error(QuoteBinder::KeyReused)
  end

  # Transactional tests wrap everything in one transaction on one connection,
  # so other threads could not see the quote. Turn that off and clean up by hand.
  context "when several requests bind the same quote at once" do
    self.use_transactional_tests = false

    after do
      Policy.delete_all
      Quote.delete_all
    end

    it "creates exactly one policy" do
      quote_id = create(:quote).id

      results = Array.new(4) do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            described_class.call(quote: Quote.find(quote_id), idempotency_key: "key-#{i}")
            :bound
          rescue QuoteBinder::AlreadyBound
            :rejected
          end
        end
      end.map(&:value)

      expect(results.count(:bound)).to eq(1)
      expect(results.count(:rejected)).to eq(3)
      expect(Policy.where(quote_id: quote_id).count).to eq(1)
    end
  end
end
