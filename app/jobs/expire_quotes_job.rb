# Marks pending quotes whose expires_at has passed as "expired".
#
# One UPDATE statement, so it's cheap to run often. Bound quotes are never
# touched: if a bind commits first, Postgres re-checks status = 'pending' on
# that row and skips it.
class ExpireQuotesJob < ApplicationJob
  queue_as :default

  # Returns how many quotes were marked expired.
  def perform
    Quote.pending.past_expiry.update_all(status: "expired", updated_at: Time.current)
  end
end
