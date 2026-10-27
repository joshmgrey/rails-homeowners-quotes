# Cancels an active policy and records the pro rata refund.
class PolicyCanceller
  class Error < StandardError; end
  class AlreadyCancelled < Error; end
  class PolicyExpired < Error; end

  def self.call(...) = new(...).call

  def initialize(policy:, cancel_on: Date.current)
    @policy = policy
    @cancel_on = cancel_on
  end

  def call
    # Lock so two concurrent cancels can't both compute and write a refund.
    @policy.with_lock do
      raise AlreadyCancelled, "policy #{@policy.policy_number} is already cancelled" if @policy.cancelled?
      raise PolicyExpired, "policy #{@policy.policy_number} expired on #{@policy.expires_on}" if @cancel_on >= @policy.expires_on

      @policy.update!(
        status: "cancelled",
        cancelled_on: @cancel_on,
        refund_cents: ProRataRefund.call(
          premium_cents: @policy.premium_cents,
          effective_on: @policy.effective_on,
          expires_on: @policy.expires_on,
          cancel_on: @cancel_on
        )
      )
    end

    @policy
  end
end
