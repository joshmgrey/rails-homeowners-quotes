require "rails_helper"

RSpec.describe "Quotes API", type: :request do
  let(:valid_params) do
    {
      quote: {
        state: "FL",
        street_address: "123 Ocean Dr",
        zip: "33139",
        year_built: 1995,
        roof_age_years: 8,
        dwelling_coverage_cents: 300_000_00
      }
    }
  end

  describe "POST /quotes" do
    it "creates a priced quote" do
      post "/quotes", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("premium_cents" => 3_600_00, "status" => "pending")
    end

    it "returns validation errors" do
      post "/quotes", params: { quote: valid_params[:quote].merge(state: "NY") }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("State is not a state we write in")
    end

    # Rails wraps a bare JSON body under the controller's name (ParamsWrapper,
    # on by default), so "quote" is optional for JSON clients.
    it "accepts attributes without the quote wrapper" do
      post "/quotes", params: valid_params[:quote], as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /quotes/:id" do
    it "returns the quote" do
      quote = create(:quote)

      get "/quotes/#{quote.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(quote.id)
    end

    it "returns 404 for an unknown quote" do
      get "/quotes/0"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /quotes/:id/bind" do
    let(:quote) { create(:quote) }

    def bind(key)
      headers = key ? { "Idempotency-Key" => key } : {}
      post "/quotes/#{quote.id}/bind", headers: headers
    end

    it "creates a policy" do
      bind("key-1")

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("quote_id" => quote.id, "premium_cents" => quote.premium_cents)
    end

    it "returns 200 and the same policy on a retry" do
      bind("key-1")
      first_id = response.parsed_body["id"]
      bind("key-1")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(first_id)
    end

    it "returns 409 when the quote is already bound" do
      bind("key-1")
      bind("key-2")

      expect(response).to have_http_status(:conflict)
    end

    it "returns 422 for an expired quote" do
      quote.update_column(:expires_at, 1.minute.ago)
      bind("key-1")

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires an Idempotency-Key header" do
      bind(nil)

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /policies/:id" do
    it "returns the policy" do
      policy = QuoteBinder.call(quote: create(:quote), idempotency_key: "key-1")

      get "/policies/#{policy.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["policy_number"]).to eq(policy.policy_number)
    end
  end
end
