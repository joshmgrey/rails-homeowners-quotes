require "rails_helper"

RSpec.describe ExpireQuotesJob, type: :job do
  it "marks pending quotes past expiry as expired" do
    stale = create(:quote, :past_expiry)

    described_class.perform_now

    expect(stale.reload).to be_expired
  end

  it "leaves pending quotes that have not expired alone" do
    fresh = create(:quote)

    described_class.perform_now

    expect(fresh.reload).to be_pending
  end

  it "never touches bound quotes, even past expiry" do
    quote = create(:quote)
    QuoteBinder.call(quote: quote, idempotency_key: "key-1")
    quote.update_column(:expires_at, 1.minute.ago)

    described_class.perform_now

    expect(quote.reload).to be_bound
  end

  it "treats a quote expiring exactly now as expired" do
    freeze_time do
      quote = create(:quote)
      quote.update_column(:expires_at, Time.current)

      described_class.perform_now

      expect(quote.reload).to be_expired
    end
  end

  it "returns how many quotes it expired and is safe to run again" do
    create_list(:quote, 2, :past_expiry)
    create(:quote)

    expect(described_class.perform_now).to eq(2)
    expect(described_class.perform_now).to eq(0)
  end

  it "can be enqueued" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue("default")
  end
end
