# frozen_string_literal: true

# Normalizes product data for themes without changing existing payloads.
# - Keeps raw API product in @args['product'] (unchanged)
# - Adds normalized context in @args['product_presented']
# - All money values exposed in integer cents (avoid float issues)
# - Selected variant resolved via ?variant=ID or option params (?size=M&color=Blue)
# - Description sanitized to a safe HTML subset
# - Image info prepared for filters (image_url)
class ProductPresenter
  # Public: Build a normalized product context for Liquid themes.
  # params: request params (variant or option selections)
  # currency: shop currency, e.g., "USD"
  def self.call(product:, params:, currency:)
    return nil unless product.is_a?(Hash)

    new(product, params, currency).present
  end

  def initialize(product, params, currency)
    @product  = product
    @params   = params || {}
    @currency = currency
  end

  def present
    selected_variant = resolve_selected_variant

    {
      'id' => @product['id'] || @product['product_id'],
      'handle' => @product['handle'],
      'title' => @product['title'] || @product['name'],
      'vendor' => @product['vendor'],
      'type' => @product['type'],
      'sku' => selected_variant && (selected_variant['sku'] || selected_variant['variant_sku']),
      'description_html' => sanitize_html(@product['description_html'] || @product['description']),
      'options' => normalize_options(@product['options']),
      'selected_variant' => normalize_variant(selected_variant),
      'variants' => Array(@product['variants']).map { |v| normalize_variant(v) },
      'available' => !!(selected_variant ? variant_available?(selected_variant) : @product['available']),
      'price' => cents(selected_variant && (selected_variant['price'] || selected_variant['variant_price']) || @product['price']),
      'compare_at_price' => cents(selected_variant && (selected_variant['compare_at_price'] || selected_variant['variant_compare_at_price']) || @product['compare_at_price']),
      'price_range' => compute_price_range(@product['variants']),
      'images' => normalize_images(@product['images'] || @product['media']),
      'currency' => @currency,
      'url' => "/products/#{@product['handle']}",
    }.tap do |h|
      # helpful flags
      h['on_sale'] = on_sale?(h['price'], h['compare_at_price'])
      h['low_stock'] = low_stock?(selected_variant || @product)
    end
  end

  private

  def resolve_selected_variant
    variants = Array(@product['variants'])
    return nil if variants.empty?

    # Priority 1: ?variant=ID
    if (vid = @params[:variant] || @params['variant'])
      found = variants.find { |v| v['id'].to_s == vid.to_s || v['variant_id'].to_s == vid.to_s }
      return found if found
    end

    # Priority 2: option params (?size=M&color=Blue)
    if (opts = normalize_options(@product['options'])).any?
      selection = {}
      opts.each do |opt|
        key = (opt['name'] || '').to_s.downcase
        selection[key] = (@params[opt['name']] || @params[key])&.to_s
      end
      if selection.values.any?(&:present?)
        found = variants.find { |v| option_match?(v, selection) }
        return found if found
      end
    end

    # Default: first available, else first
    variants.find { |v| variant_available?(v) } || variants.first
  end

  def option_match?(variant, selection)
    variant_values = Array(variant['option_values'] || [variant['option1'], variant['option2'], variant['option3']]).compact.map(&:to_s)
    # selection order follows product.options order; compare case-insensitively
    desired = selection.values.compact.map { |s| s.to_s.downcase }
    return false if desired.empty?
    variant_values.map { |s| s.to_s.downcase }[0, desired.length] == desired
  end

  def normalize_options(options)
    Array(options).map do |o|
      if o.is_a?(Hash)
        { 'id' => o['id'], 'name' => o['name'] || o['option_name'], 'values' => Array(o['values'] || o['option_values']) }
      else
        { 'name' => o.to_s, 'values' => [] }
      end
    end
  end

  def normalize_variant(v)
    return nil unless v
    {
      'id' => v['id'] || v['variant_id'],
      'title' => v['title'] || v['variant_title'],
      'sku' => v['sku'] || v['variant_sku'],
      'available' => variant_available?(v),
      'price' => cents(v['price'] || v['variant_price']),
      'compare_at_price' => cents(v['compare_at_price'] || v['variant_compare_at_price']),
      'option_values' => Array(v['option_values'] || [v['option1'], v['option2'], v['option3']]).compact,
      'url' => variant_url(v)
    }
  end

  def variant_available?(v)
    available = v['available']
    return available unless available.nil?
    inv = v['inventory_quantity'] || v['inventory']
    inv.nil? ? true : inv.to_i > 0
  end

  def normalize_images(images)
    Array(images).map do |img|
      if img.is_a?(Hash)
        { 'src' => img['src'] || img['url'], 'alt' => img['alt'] || '' }
      else
        { 'src' => img.to_s, 'alt' => '' }
      end
    end
  end

  def compute_price_range(variants)
    vs = Array(variants)
    cents_list = vs.map { |v| cents(v['price'] || v['variant_price']) }.compact
    return nil if cents_list.empty?
    { 'min' => cents_list.min, 'max' => cents_list.max }
  end

  def on_sale?(price, compare)
    p = price.to_i
    c = compare.to_i
    c > p && p > 0
  end

  def low_stock?(entity)
    qty = entity['inventory_quantity'] || entity['inventory']
    qty && qty.to_i > 0 && qty.to_i <= (ENV['LOW_STOCK_THRESHOLD'] || 5).to_i
  end

  def variant_url(v)
    vid = v['id'] || v['variant_id']
    h = @product['handle']
    vid ? "/products/#{h}?variant=#{vid}" : "/products/#{h}"
  end

  def cents(value)
    return nil if value.nil?
    # Accept integer cents, decimal strings, or floats
    if value.is_a?(Integer)
      value
    elsif value.is_a?(Float)
      (value * 100).round
    else
      str = value.to_s
      return nil if str.empty?
      (BigDecimal(str) * 100).to_i
    end
  rescue ArgumentError
    nil
  end

  def sanitize_html(html)
    ActionController::Base.helpers.sanitize(html.to_s, tags: %w[p br b i strong em ul ol li a img h1 h2 h3 h4 h5 h6 span], attributes: %w[href src alt title])
  end
end
