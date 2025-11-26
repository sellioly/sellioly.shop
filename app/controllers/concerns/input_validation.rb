# frozen_string_literal: true

module InputValidation
  extend ActiveSupport::Concern

  included do
    before_action :validate_template_params, only: [
      :request_template_page,
      :request_assets_template,
      :request_asset_content,
      :update_asset_content,
      :create_asset_file,
      :delete_asset_file,
      :create_asset_directory,
      :move_asset_file,
      :upload_asset_file,
      :request_template
    ]
  end

  private

  def validate_template_params
    store_id = request.headers['X-Store-ID'] || request.headers['X-Store-Id'] || params[:shop_id]
    template_id = params[:template_id]

    unless store_id.present?
      render json: {
        error: {
          code: 'validation_error',
          message: 'Store ID is required (X-Store-ID header or shop_id parameter)'
        }
      }, status: :bad_request
      return
    end

    unless template_id.present?
      render json: {
        error: {
          code: 'validation_error',
          message: 'template_id is required'
        }
      }, status: :bad_request
      return
    end
  end

  def template_params
    params.permit(:template_id, :shop_id, :key, :content, :old_key, :new_key, :page, :url_theme, :app_domain, :filename, file: [])
  end
end

