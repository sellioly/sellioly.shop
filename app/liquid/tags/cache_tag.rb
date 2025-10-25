# frozen_string_literal: true
require 'liquid'

# Usage:
# {% cache key: "header", vary: locale, ttl: 600 %}
#   ... expensive markup ...
# {% endcache %}
#
# Key parts:
# - Namespaced by shop_id + theme digest (if available) to avoid cross-tenant bleed
# - Vary list resolves values from the Liquid assigns (e.g., locale, currency)
# - TTL optional; default 300s (env FRAGMENT_CACHE_TTL)

module Tags
  class CacheTag < Liquid::Block
    Syntax = /(\s*key:\s*(?<key>[^,]+))?(\s*,\s*vary:\s*(?<vary>[^,]+))?(\s*,\s*ttl:\s*(?<ttl>\d+))?/o

    def initialize(tag_name, markup, options)
      super
      m = Syntax.match(markup.to_s)
      @key_expr  = m && m[:key]
      @vary_expr = m && m[:vary]
      @ttl       = (m && m[:ttl] ? m[:ttl].to_i : (ENV['FRAGMENT_CACHE_TTL'] || 300).to_i)
    end

    def render(context)
      registers = context.registers
      assigns   = context.environments.first || {}

      store   = (registers['fragment_cache'] ||= FragmentCacheStore.new)
      theme   = registers['theme_store']
      shop_id = assigns['shop_id']

      key_str  = evaluate_expr(context, @key_expr) || 'fragment'
      vary_vals = resolve_vary(context, @vary_expr)

      theme_digest = theme&.file_digest('layout/theme.liquid') || 'no-theme'
      ns_key  = ["fc:v1", "shop:#{shop_id}", "theme:#{theme_digest}", "key:#{key_str}", "vary:#{vary_vals.join('|')}"]
      cache_key = ns_key.join(':')

      store.fetch(cache_key, ttl: @ttl) do
        super # render block
      end
    end

    private

    def evaluate_expr(context, expr)
      return nil unless expr
      Liquid::Expression.parse(expr).to_liquid(context)
    rescue StandardError
      nil
    end

    def resolve_vary(context, expr)
      return [] unless expr
      # split by spaces or pipe/comma
      names = expr.to_s.split(/\s*[|,\s]\s*/).reject(&:empty?)
      env = context.environments.first || {}
      names.map { |n| dig_value(env, n) || n }
    end

    def dig_value(env, path)
      # supports dotted paths like "request.locale" or "currency"
      cur = env
      path.to_s.split('.')
        .reduce(cur) { |acc, k| acc.is_a?(Hash) ? acc[k] : nil }
    end
  end
end
