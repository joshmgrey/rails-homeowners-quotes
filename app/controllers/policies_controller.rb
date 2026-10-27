class PoliciesController < ApplicationController
  def show
    render json: Policy.find(params[:id])
  end
end
