class PoliciesController < ApplicationController
  def index
    # includes(:quote) loads every policy's quote in one extra query instead of
    # one query per policy (the N+1 problem).
    policies = Policy.includes(:quote).order(:id)
    render json: policies.as_json(include: { quote: { only: %i[street_address zip state] } })
  end

  def show
    render json: Policy.find(params[:id])
  end

  # POST /policies/:id/cancel
  # Cancels as of today and returns the policy with its pro rata refund.
  def cancel
    render json: PolicyCanceller.call(policy: Policy.find(params[:id]))
  rescue PolicyCanceller::AlreadyCancelled => e
    render json: { error: e.message }, status: :conflict
  rescue PolicyCanceller::PolicyExpired => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
