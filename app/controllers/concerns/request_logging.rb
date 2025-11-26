# frozen_string_literal: true

module RequestLogging
  extend ActiveSupport::Concern

  included do
    before_action :log_request
    after_action :log_response
  end

  private

  def log_request
    @request_start_time = Time.current
    
    Rails.logger.info({
      at: 'request',
      method: request.method,
      path: request.path,
      store_id: request.headers['X-Store-ID'] || request.headers['X-Store-Id'] || params[:shop_id],
      template_id: params[:template_id],
      ip: request.remote_ip,
      timestamp: @request_start_time.iso8601
    }.to_json)
  end

  def log_response
    duration_ms = if @request_start_time
                    ((Time.current - @request_start_time) * 1000).round(2)
                  else
                    nil
                  end

    Rails.logger.info({
      at: 'response',
      method: request.method,
      path: request.path,
      status: response.status,
      duration_ms: duration_ms,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end

