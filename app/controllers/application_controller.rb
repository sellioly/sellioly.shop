# app/controllers/application_controller.rb
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ActionController::Cookies  # يضمن توفر helper حتى لو تغيّر الوراثة
  protect_from_forgery with: :null_session
  rescue_from StandardError, with: :log_and_render_error

  private

  # ——— Live storefront bootstrap (domain → store → base args) ———
  # Use this as a before_action in live controllers (not in PreviewController).
  def initialize_shop
    ctx, failure = Shops::ShopContext.new.resolve!(host: request.host, cookies: cookies)
    if failure
      return content_not_found if failure.type == :not_found
      return internal_server_error
    end

    @domain      = ctx.domain
    @shop_id     = ctx.shop_id
    @template_id = ctx.template_id
    @path        = ctx.theme_path
    @store       = ctx.store
    @args        = ctx.base_args

    # Minimal request context for tags/filters (paginate, urls, etc.)
    @args['request']     = { 'params' => request.query_parameters, 'path' => request.path }
    @args['current_url'] = request.original_url
  end

  # ——— Themed page rendering helper (JSON → sections → layout) ———
  # For simple pages that don’t add extra assigns, call: render_page('index.json')
  # For pages that add context (e.g., product), prefer invoking Pages::PageRenderer directly from the action.
  def render_page(template_json, extra_ctx: {})
    result = Pages::PageRenderer.new.render(
      template_name: template_json,
      base_args: (@args || {}).merge('domain' => @domain),
      extra_ctx: extra_ctx,
      theme_path: @path,
      preview: false
    )
    set_page_headers(result)
    render html: result.html.html_safe
  end

  # ——— Headers suggested by the renderer (ETag + Cache-Control) ———
  def set_page_headers(result)
    return unless result&.headers.is_a?(Hash)
    response.set_header('ETag', result.headers['ETag']) if result.headers['ETag']
    response.set_header('Cache-Control', result.headers['Cache-Control']) if result.headers['Cache-Control']
  end

  # ——— Not found (tries themed 404 if theme is loaded) ———
  def content_not_found
    respond_to do |format|
      format.html do
        if @path.present?
          begin
            result = Pages::PageRenderer.new.render(
              template_name: '404.json',
              base_args: (@args || {}).merge('domain' => @domain),
              theme_path: @path,
              preview: false
            )
            set_page_headers(result)
            render html: result.html.html_safe, status: :not_found
          rescue
            render file: Rails.root.join('public/404.html'), layout: true, status: :not_found
          end
        else
          render file: Rails.root.join('public/404.html'), layout: true, status: :not_found
        end
      end
      format.json { render json: { error: 'Not found' }, status: :not_found }
      format.any  { head :not_found }
    end
    true
  end

  # ——— 500s (format-aware) ———
  def internal_server_error
    respond_to do |format|
      format.json { render json: { error: 'Internal server error' }, status: :internal_server_error }
      format.html { render file: Rails.root.join('public/500.html'), layout: true, status: :internal_server_error }
      format.any  { head :internal_server_error }
    end
    true
  end

  # ——— Global error logging + format-aware response (PR #9) ———
  def log_and_render_error(exception)
    Rails.logger.error({
      at: 'exception',
      error: exception.class.name,
      message: exception.message,
      backtrace: exception.backtrace&.take(10),
      path: request.fullpath,
      method: request.method,
      params: request.filtered_parameters
    }.to_json)

    respond_to do |format|
      format.json { render json: { error: 'Internal server error' }, status: :internal_server_error }
      format.html { render file: Rails.root.join('public/500.html'), layout: true, status: :internal_server_error }
      format.any  { head :internal_server_error }
    end
  end
end
