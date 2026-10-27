# Turns a pending quote into a policy.
#
# Safe to retry: calling it again with the same idempotency key returns the
# policy that was already created instead of raising or creating a second one.
class QuoteBinder
  class Error < StandardError; end
  class AlreadyBound < Error; end
  class QuoteExpired < Error; end
  class KeyReused < Error; end

  def self.call(...) = new(...).call

  def initialize(quote:, idempotency_key:, effective_on: Date.current)
    @quote = quote
    @idempotency_key = idempotency_key
    @effective_on = effective_on
  end

  def call
    existing = Policy.find_by(idempotency_key: @idempotency_key)
    raise KeyReused, "idempotency key was already used for another quote" if existing && existing.quote_id != @quote.id

    policy = nil

    # with_lock reloads the quote under SELECT ... FOR UPDATE, so two
    # concurrent binds of the same quote run one after the other.
    @quote.with_lock do
      policy = @quote.policy

      if policy
        raise AlreadyBound, "quote #{@quote.id} is already bound" unless policy.idempotency_key == @idempotency_key
      else
        # past_expiry? covers both cases: already marked expired by
        # ExpireQuotesJob, or past expires_at but the job hasn't run yet.
        raise QuoteExpired, "quote #{@quote.id} has expired" if @quote.past_expiry?

        policy = @quote.create_policy!(
          policy_number: Policy.generate_number,
          idempotency_key: @idempotency_key,
          premium_cents: @quote.premium_cents,
          effective_on: @effective_on,
          expires_on: @effective_on + Policy::TERM
        )
        @quote.bound!
      end
    end

    policy
  end
end
