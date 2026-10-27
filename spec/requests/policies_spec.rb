require "rails_helper"

RSpec.describe "Policies API", type: :request do
  def create_policies(count)
    Array.new(count) do
      QuoteBinder.call(quote: create(:quote), idempotency_key: SecureRandom.uuid)
    end
  end

  # Counts the SQL queries a block runs, skipping schema lookups and
  # transaction statements Rails issues on its own.
  def count_queries(&block)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  describe "GET /policies" do
    it "lists policies with their quote's address" do
      policy = create_policies(1).first

      get "/policies"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first).to include(
        "policy_number" => policy.policy_number,
        "quote" => { "street_address" => "123 Ocean Dr", "zip" => "33139", "state" => "FL" }
      )
    end

    it "runs the same number of queries for 1 policy as for 5 (no N+1)" do
      create_policies(1)
      one = count_queries { get "/policies" }

      create_policies(4)
      five = count_queries { get "/policies" }

      expect(response.parsed_body.size).to eq(5)
      expect(five).to eq(one)
    end
  end

  describe "POST /policies/:id/cancel" do
    # Pinned to a 365-day term (Nov 1, 2026 to Nov 1, 2027) so the math below
    # doesn't depend on when the suite runs.
    let(:policy) { travel_to(Date.new(2026, 11, 1)) { create_policies(1).first } }

    it "cancels and returns the refund" do
      travel_to(policy.effective_on + 100) { post "/policies/#{policy.id}/cancel" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "status" => "cancelled",
        "cancelled_on" => (policy.effective_on + 100).iso8601,
        "refund_cents" => policy.premium_cents * 265 / 365
      )
    end

    it "refunds the full premium when cancelled on the effective date" do
      travel_to(policy.effective_on) { post "/policies/#{policy.id}/cancel" }

      expect(response.parsed_body["refund_cents"]).to eq(policy.premium_cents)
    end

    it "returns 409 when the policy is already cancelled" do
      post "/policies/#{policy.id}/cancel"
      post "/policies/#{policy.id}/cancel"

      expect(response).to have_http_status(:conflict)
    end

    it "returns 422 for an expired policy" do
      policy.update_columns(effective_on: 2.years.ago.to_date, expires_on: 1.year.ago.to_date)

      post "/policies/#{policy.id}/cancel"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for an unknown policy" do
      post "/policies/0/cancel"

      expect(response).to have_http_status(:not_found)
    end
  end
end
