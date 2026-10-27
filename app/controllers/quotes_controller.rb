class QuotesController < ApplicationController
  def create
    quote = Quote.new(quote_params)

    if quote.save
      render json: quote, status: :created
    else
      render json: { errors: quote.errors.full_messages }, status: :unprocessable_content
    end
  end

  def show
    render json: Quote.find(params[:id])
  end

  # POST /quotes/:id/bind
  # Requires an Idempotency-Key header so a client can safely retry.
  def bind
    key = request.headers["Idempotency-Key"]
    return render(json: { error: "Idempotency-Key header is required" }, status: :bad_request) if key.blank?

    policy = QuoteBinder.call(quote: Quote.find(params[:id]), idempotency_key: key)

    # 201 the first time, 200 when a retry gets back the existing policy.
    render json: policy, status: policy.previously_new_record? ? :created : :ok
  rescue QuoteBinder::AlreadyBound => e
    render json: { error: e.message }, status: :conflict
  rescue QuoteBinder::QuoteExpired, QuoteBinder::KeyReused => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def quote_params
    params.expect(quote: %i[state street_address zip year_built roof_age_years dwelling_coverage_cents])
  end
end
