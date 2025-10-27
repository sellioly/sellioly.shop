# frozen_string_literal: true
require 'liquid'
require 'uri'

# Usage:
# {% paginate items: collection.products, by: 24, param: 'page' %}
#   {% for item in paginate.items %}
#     ...
#   {% endfor %}
#   {% render 'pager', paginate: paginate %}
# {% endpaginate %}
#
# - Reads current page from request params (assigns['request']['params'][param]) when present, otherwise 1.
# - Exposes `paginate` drop with keys: items, current_page, page_size, pages, total, next_url, previous_url.
# - Builds URLs using assigns['current_url'] if available; falls back to query string with param only.

module Tags
  class PaginateTag < Liquid::Block
    Syntax = /(\s*items:\s*(?<items>[^,]+))?(\s*,\s*by:\s*(?<by>\d+))?(\s*,\s*param:\s*(?<param>[^,]+))?/o

    def initialize(tag_name, markup, options)
      super
      m = Syntax.match(markup.to_s)
      @items_expr = m && m[:items]
      @by        = (m && m[:by] ? m[:by].to_i : 24)
      @param     = (m && m[:param] ? m[:param].strip.delete("'\"") : 'page')
    end

    def render(context)
      assigns = context.environments.first || {}

      # read collection.products or any array
      collection = evaluate_expr(context, @items_expr)
      collection = collection.to_liquid if collection.respond_to?(:to_liquid)
      items = collection['data'] || collection['items'] || Array(collection)

      # check for meta from API
      meta = collection['meta'] || assigns['meta'] || {}

      if meta['total'] && meta['per_page'] # ✅ API pagination mode
        page_size = meta['per_page'].to_i
        total     = meta['total'].to_i
        page      = meta['current_page'].to_i
        pages     = meta['last_page'].to_i

        base_url = assigns['current_url']
        paginate_hash = {
          'items'        => items,
          'current_page' => page,
          'page_size'    => page_size,
          'pages'        => pages,
          'total'        => total,
          'next_url'     => (page < pages ? build_url(base_url, @param, page + 1) : nil),
          'previous_url' => (page > 1 ? build_url(base_url, @param, page - 1) : nil)
        }
      else # ⚙️ fallback to in-memory mode
        page = current_page_from(assigns, @param)
        total = items.length
        page_size = [@by, 1].max
        pages = (total.to_f / page_size).ceil
        page = [[page, 1].max, [pages, 1].max].min
        offset = (page - 1) * page_size
        slice = items.slice(offset, page_size) || []
        base_url = assigns['current_url']
        paginate_hash = {
          'items'        => slice,
          'current_page' => page,
          'page_size'    => page_size,
          'pages'        => pages,
          'total'        => total,
          'next_url'     => (page < pages ? build_url(base_url, @param, page + 1) : nil),
          'previous_url' => (page > 1 ? build_url(base_url, @param, page - 1) : nil)
        }
      end

      context.stack do
        context['paginate'] = paginate_hash
        super
      end
    end

    private

    def evaluate_expr(context, expr)
      return [] unless expr
      Liquid::Expression.parse(expr).to_liquid(context)
    rescue Liquid::Error => e
      Rails.logger.error({ at: 'liquid_paginate_tag', err: e.class.name, msg: e.message }.to_json)
      []
    end

    def current_page_from(assigns, param)
      req = assigns['request']
      return 1 unless req.is_a?(Hash) && req['params'].is_a?(Hash)
      p = req['params'][param] || req['params'][param.to_s]
      (p.to_i <= 0) ? 1 : p.to_i
    end

    def build_url(base, param, value)
      if base && !base.empty?
        uri = URI.parse(base) rescue nil
        if uri
          q = URI.decode_www_form(String(uri.query)) rescue []
          q.reject! { |k, _| k == param }
          q << [param, value]
          uri.query = URI.encode_www_form(q)
          return uri.to_s
        end
      end
      # Fallback: relative with only the page param
      "?#{param}=#{value}"
    end
  end
end
