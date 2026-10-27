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
end
