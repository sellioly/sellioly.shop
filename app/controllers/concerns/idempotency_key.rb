# frozen_string_literal: true
module IdempotencyKey
  extend ActiveSupport::Concern

  included do
    before_action :set_idempotency_key
  end

  private

  def set_idempotency_key
    @idempotency_key = request.headers["Idempotency-Key"].presence || request.request_id
  end

  def current_idempotency_key
    @idempotency_key
  end
end
