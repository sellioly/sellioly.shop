# frozen_string_literal: true

module Theme
  # Compiles Liquid templates and caches the compiled AST keyed by theme + file digest.
  class TemplateCompiler
    def initialize(cache: default_cache)
      @cache = cache
    end

    # rel_path e.g. "sections/hero.liquid", "layout/theme.liquid", "snippets/card.liquid"
    def compile(theme_store:, rel_path:)
      source = theme_store.read_liquid(rel_path)
      return nil unless source
      digest = theme_store.file_digest(rel_path) || "nodigest"
      key = cache_key(theme_store.root, rel_path, digest)

      if rails_cache?
        Rails.cache.fetch(key) { Liquid::Template.parse(source) }
      else
        @cache.fetch(key) { Liquid::Template.parse(source) }
      end
    end

    private

    def cache_key(root, rel_path, digest)
      ["liquid", root, rel_path, digest].join(":")
    end

    def rails_cache?
      defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
    end

    def default_cache
      TemplateCache.new
    end
  end
end
