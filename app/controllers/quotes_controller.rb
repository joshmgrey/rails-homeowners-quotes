class QuotesController < ApplicationController
  PER_PAGE = 20
  MAX_PER_PAGE = 100

  class InvalidParam < StandardError; end

  rescue_from InvalidParam do |e|
    render json: { error: e.message }, status: :bad_request
  end

  # GET /quotes?state=FL&page=2&per_page=20
  def index
    # Ordering by id keeps pages stable: without an ORDER BY, Postgres can
    # return rows in any order, so items could repeat or vanish across pages.
    quotes = Quote.order(:id)
    quotes = quotes.where(state: params[:state].upcase) if params[:state].present?

    page = positive_integer_param(:page, default: 1)
    per_page = [ positive_integer_param(:per_page, default: PER_PAGE), MAX_PER_PAGE ].min
    total = quotes.count

    render json: {
      quotes: quotes.limit(per_page).offset((page - 1) * per_page),
      meta: { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil }
    }
  end

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

  # Integer() raises on "abc" or "1.5", unlike to_i, which would quietly turn
  # them into 0 or 1.
  def positive_integer_param(name, default:)
    value = Integer(params.fetch(name, default).to_s, 10)
    raise ArgumentError unless value.positive?

    value
  rescue ArgumentError
    raise InvalidParam, "#{name} must be a positive integer"
  end

  def quote_params
    params.expect(quote: %i[state street_address zip year_built roof_age_years dwelling_coverage_cents])
  end
end
