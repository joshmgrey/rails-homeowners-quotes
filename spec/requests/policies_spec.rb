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
end
