class StoreController < ApplicationController

  include StoreHelper
  # before_action :verify_ssl_hook

  public def create
    permitted = params.require(:shop).permit(
      :store_id,
      :app_domain,
      :template_id,
      :theme_handle,
      :theme_version,
      :external_theme_purchase_id
    )

    # Idempotent: find or initialize by external_store_id
    shop = Shop.find_or_initialize_by(external_store_id: permitted[:store_id])

    shop.app_domain = permitted[:app_domain]
    shop.status     ||= "provisioning"
    shop.save!

    # Also idempotent-ish: find existing active theme with same handle/version
    shop_theme = shop.shop_themes.find_by(
      theme_handle:  permitted[:theme_handle],
      theme_version: permitted[:theme_version]
    )

    unless shop_theme
      shop_theme = shop.shop_themes.create!(
        external_template_id:       permitted[:template_id],
        theme_handle:               permitted[:theme_handle],
        theme_version:              permitted[:theme_version],
        root_path:                  "", # will be set by job
        status:                     :installing,
        external_theme_purchase_id: permitted[:external_theme_purchase_id]
      )
    end

    # Enqueue async provisioning (download zip -> extract -> update DB -> webhook)
    ProvisionShopThemeJob.perform_later(shop_theme.id)

    render json: {
      shop_id:      shop.id,
      shop_theme_id: shop_theme.id,
      status:       shop.status,
      theme_status: shop_theme.status
    }, status: :accepted
  rescue ActionController::ParameterMissing => e
    render json: { message: e.message }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  end
end