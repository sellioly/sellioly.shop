# frozen_string_literal: true

# Builds a compact HTML head fragment for product pages.
# Usage: SeoPresenter.product_head(product: presented, shop: shop_hash, current_url: request.original_url)
class SeoPresenter
  def self.product_head(product:, shop:, current_url:)
    new(product, shop, current_url).head
  end

  def initialize(product, shop, current_url)
    @p = product || {}
    @s = shop || {}
    @url = current_url.to_s
  end

  def head
    title = [@p['title'], @s['shop_name']].compact.join(' – ')
    desc  = truncate(strip_tags(@p['description_html']), 155)
    image = Array(@p['images']).first && Array(@p['images']).first['src']

    tags = []
    tags << %(<title>#{escape_html(title)}</title>)
    tags << %(<meta name="description" content="#{escape_html(desc)}"/>) if desc && !desc.empty?
    tags << %(<link rel="canonical" href="#{escape_html(@url)}"/>)

    # OpenGraph
    tags << %(<meta property="og:type" content="product"/>)
    tags << %(<meta property="og:title" content="#{escape_html(title)}"/>)
    tags << %(<meta property="og:description" content="#{escape_html(desc)}"/>) if desc && !desc.empty?
    tags << %(<meta property="og:url" content="#{escape_html(@url)}"/>)
    tags << %(<meta property="og:image" content="#{escape_html(image)}"/>) if image

    # Twitter
    tags << %(<meta name="twitter:card" content="summary_large_image"/>)
    tags << %(<meta name="twitter:title" content="#{escape_html(title)}"/>)
    tags << %(<meta name="twitter:description" content="#{escape_html(desc)}"/>) if desc && !desc.empty?
    tags << %(<meta name="twitter:image" content="#{escape_html(image)}"/>) if image

    # JSON-LD Product
    tags << %(<script type="application/ld+json">#{json_ld_product}</script>)

    tags.join("\n")
  end

  private

  def json_ld_product
    data = {
      '@context' => 'https://schema.org',
      '@type' => 'Product',
      'name' => @p['title'],
      'image' => Array(@p['images']).map { |i| i['src'] }.compact,
      'description' => strip_tags(@p['description_html']),
      'sku' => @p.dig('selected_variant', 'sku'),
      'brand' => { '@type' => 'Brand', 'name' => @p['vendor'] }.compact,
      'offers' => {
        '@type' => 'Offer',
        'url' => @url,
        'priceCurrency' => @p['currency'],
        'price' => cents_to_decimal(@p['price']) || cents_to_decimal(@p.dig('selected_variant', 'price')),
        'availability' => availability(@p),
      }.compact
    }.compact

    JSON.generate(data)
  end

  def availability(p)
    p['available'] ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock'
  end

  def cents_to_decimal(cents)
    return nil unless cents
    format('%.2f', cents.to_i / 100.0)
  end

  def truncate(text, max)
    t = text.to_s
    return t if t.length <= max
    t[0, max - 1] + '…'
  end

  def strip_tags(html)
    ActionController::Base.helpers.strip_tags(html.to_s)
  end

  def escape_html(s)
    CGI.escapeHTML(s.to_s)
  end
end
