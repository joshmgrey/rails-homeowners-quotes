# Refund for the unused part of a policy term, proportional to days left.
#
# Day counting: coverage runs from effective_on up to (not including)
# expires_on, and a cancellation takes effect at the start of cancel_on. So:
#   - cancelling on effective_on (or earlier) refunds the full premium
#   - cancelling on the last covered day refunds one day
#   - cancelling on or after expires_on refunds nothing
#
# A leap-year term is 366 days, so each day is worth slightly less.
# Integer division rounds down, so the refund never exceeds the unused premium.
class ProRataRefund
  def self.call(...) = new(...).call

  def initialize(premium_cents:, effective_on:, expires_on:, cancel_on:)
    @premium_cents = premium_cents
    @effective_on = effective_on
    @expires_on = expires_on
    @cancel_on = cancel_on
  end

  # Returns the refund in cents.
  def call
    term_days = (@expires_on - @effective_on).to_i
    raise ArgumentError, "expires_on must be after effective_on" unless term_days.positive?

    unused_days = (@expires_on - @cancel_on).to_i.clamp(0, term_days)
    @premium_cents * unused_days / term_days
  end
end
