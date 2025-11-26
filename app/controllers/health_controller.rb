# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def check
    checks = {
      database: database_healthy?,
      storage: storage_healthy?,
      shop_theme: shop_theme_accessible?,
      timestamp: Time.current.iso8601
    }

    all_healthy = checks[:database] && checks[:storage] && checks[:shop_theme]
    status = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? 'healthy' : 'unhealthy',
      checks: checks
    }, status: status
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue StandardError => e
    Rails.logger.error("Health check - Database failed: #{e.message}")
    false
  end

  def storage_healthy?
    storage_path = Rails.root.join('storage')
    File.writable?(storage_path) && File.directory?(storage_path)
  rescue StandardError => e
    Rails.logger.error("Health check - Storage failed: #{e.message}")
    false
  end

  def shop_theme_accessible?
    ShopTheme.first.present?
  rescue StandardError => e
    Rails.logger.error("Health check - ShopTheme failed: #{e.message}")
    false
  end
end

