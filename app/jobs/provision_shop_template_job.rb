class ProvisionShopTemplateJob < ApplicationJob
  queue_as :default

  # We provision a single ShopTheme (and update its Shop).
  def perform(shop_theme_id)
    shop_theme = ShopTheme.find(shop_theme_id)
    shop       = shop_theme.shop

    storage = TemplateStorage.new

    # Where this specific theme instance will live on disk
    dest_root = Rails.root.join(
      "storage",
      "shops",
      shop.id.to_s,
      "themes",
      "#{shop_theme.theme_handle}-#{shop_theme.theme_version}"
    )

    # 1) Download zip
    zip_path = storage.download_theme_zip(
      theme_handle:  shop_theme.theme_handle,
      theme_version: shop_theme.theme_version
    )

    begin
      # 2) Extract zip into local folder
      storage.extract_zip(
        zip_path:  zip_path,
        dest_root: dest_root.to_s
      )

      root_path    = "/storage/shops/#{shop.id}/themes/#{shop_theme.theme_handle}-#{shop_theme.theme_version}"
      template_root = root_path # or use parent folder if you prefer

      # 3) Update DB (theme & shop)
      shop_theme.update!(
        root_path:    root_path,
        status:       :active,
        installed_at: Time.current
      )

      shop.update!(
        template_path:        template_root,
        active_shop_theme_id: shop_theme.id,
        active_external_template_id: shop_theme.external_template_id,
        status:               :ready,
        provisioned_at:       Time.current,
        last_error:           nil
      )

      # 4) Optional: notify Laravel that provisioning is done
      notify_laravel_template_created(shop, shop_theme)
    ensure
      # 5) Clean up temp zip
      File.delete(zip_path) if zip_path && File.exist?(zip_path)
    end
  rescue => e
    shop_theme.update!(
      status: :failed
    )
    shop.update!(
      status:     :failed,
      last_error: e.message
    )
    raise e
  end

  private

  def notify_laravel_template_created(shop, shop_theme)
    # webhook_url = ENV["SELLIOLY_TEMPLATE_CREATED_WEBHOOK_URL"]
    # secret      = ENV["SELLIOLY_WEBHOOK_SECRET"]

    # return unless webhook_url.present? && secret.present?

    # payload = {
    #   store_id:       shop.external_store_id,
    #   app_domain:     shop.app_domain,
    #   theme_handle:   shop.theme_handle,
    #   theme_version:  shop.theme_version,
    #   template_path:  template_path,
    #   status:         shop.status
    # }

    # body      = payload.to_json
    # signature = OpenSSL::HMAC.hexdigest("SHA256", secret, body)

    # HTTP.headers(
    #   "Content-Type"         => "application/json",
    #   "X-Sellioly-Signature" => signature
    # ).post(webhook_url, body: body)

    settings_theme = File.read(File.join(Rails.root.to_s, shop.template_path, 'config', 'settings_theme.json'))
    @data = JSON.load settings_theme
    @theme_name = @data['theme_name']
    @theme_version = @data['theme_version']
    @theme_author = @data['theme_author']
    @theme_support_url = @data['theme_support_url']


    HTTP.post("https://api.sellioly.com/ruby/template-created", :form => { 
      'shop_id' => shop.id,
      'app_domain' => shop.app_domain,
      'template_id' => shop_theme.external_template_id,
      'template_path' => shop.template_path, 
      'theme_name' => @theme_name, 
      'theme_version' => @theme_version, 
      'theme_author' => @theme_author
    })
  end
end
