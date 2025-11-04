# app/controllers/orders_controller.rb
# frozen_string_literal: true

class OrdersController < Api::BaseController
  def initialize(repo: OrderRepository.new)
    super()
    @repo = repo
  end

  # GET /orders/:id
  def show
    result = @repo.show(order_id: params[:id])
    render_result(result) # maps upstream codes → Rails status, JSON body unified
  end

  # POST /orders/:id/cancel
  def cancel
    result = @repo.cancel(order_id: params[:id], idempotency_key: current_idempotency_key)
    render_result(result)
  end
end
