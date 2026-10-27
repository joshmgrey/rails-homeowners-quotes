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

  describe "GET /quotes" do
    def returned_ids = response.parsed_body["quotes"].map { |q| q["id"] }
    def meta = response.parsed_body["meta"]

    it "lists quotes in id order with pagination metadata" do
      quotes = create_list(:quote, 3)

      get "/quotes"

      expect(response).to have_http_status(:ok)
      expect(returned_ids).to eq(quotes.map(&:id))
      expect(meta).to eq("page" => 1, "per_page" => 20, "total" => 3, "total_pages" => 1)
    end

    describe "filtering by state" do
      it "returns only quotes in that state" do
        fl = create(:quote, state: "FL")
        create(:quote, state: "TX")

        get "/quotes", params: { state: "FL" }

        expect(returned_ids).to eq([ fl.id ])
        expect(meta["total"]).to eq(1)
      end

      it "is case-insensitive" do
        fl = create(:quote, state: "FL")

        get "/quotes", params: { state: "fl" }

        expect(returned_ids).to eq([ fl.id ])
      end

      it "returns an empty list for a state with no quotes" do
        create(:quote, state: "FL")

        get "/quotes", params: { state: "NY" }

        expect(returned_ids).to be_empty
        expect(meta["total"]).to eq(0)
      end
    end

    describe "pagination" do
      let!(:quotes) { create_list(:quote, 25) }

      it "returns the first 20 on page 1" do
        get "/quotes"

        expect(returned_ids).to eq(quotes.first(20).map(&:id))
        expect(meta).to include("total" => 25, "total_pages" => 2)
      end

      it "returns the rest on page 2" do
        get "/quotes", params: { page: 2 }

        expect(returned_ids).to eq(quotes.last(5).map(&:id))
        expect(meta["page"]).to eq(2)
      end

      it "returns an empty page past the end" do
        get "/quotes", params: { page: 3 }

        expect(response).to have_http_status(:ok)
        expect(returned_ids).to be_empty
      end

      it "accepts per_page" do
        get "/quotes", params: { per_page: 10, page: 3 }

        expect(returned_ids).to eq(quotes.last(5).map(&:id))
        expect(meta).to include("per_page" => 10, "total_pages" => 3)
      end

      it "caps per_page at 100" do
        get "/quotes", params: { per_page: 500 }

        expect(meta["per_page"]).to eq(100)
      end

      %w[0 -1 abc 1.5].each do |bad|
        it "returns 400 for page=#{bad}" do
          get "/quotes", params: { page: bad }

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body["error"]).to eq("page must be a positive integer")
        end
      end

      it "returns 400 for per_page=0" do
        get "/quotes", params: { per_page: 0 }

        expect(response).to have_http_status(:bad_request)
      end
    end

    it "combines a state filter with pagination" do
      fl = Array.new(3) { create(:quote, state: "FL").tap { create(:quote, state: "TX") } }

      get "/quotes", params: { state: "FL", page: 2, per_page: 2 }

      expect(returned_ids).to eq([ fl.last.id ])
      expect(meta).to eq("page" => 2, "per_page" => 2, "total" => 3, "total_pages" => 2)
    end
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
