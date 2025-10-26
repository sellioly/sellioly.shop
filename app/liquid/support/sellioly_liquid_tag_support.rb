# frozen_string_literal: true
require 'liquid'


module Support
  module SelliolyLiquidTagSupport
    NAME_REGEX = /\A[a-z0-9\/_-]+\z/.freeze
    DEFAULT_MAX_INCLUDE_DEPTH = (ENV['LIQUID_MAX_INCLUDE_DEPTH'] || 10).to_i

    def extract_name(markup)
      name = markup.to_s.strip.delete("'").split(',').first.to_s
      validate_name!(name)
      name
    end

    def validate_name!(name)
      raise Liquid::ArgumentError, "Illegal template name '#{name}'" unless NAME_REGEX.match?(name)
      raise Liquid::ArgumentError, "Illegal template name '#{name}' (.. not allowed)" if name.include?('..')
    end

    def parse_attributes(markup)
      attrs = {}
      markup.scan(Liquid::TagAttributes) { |key, value| attrs[key] = parse_expression(value) }
      attrs
    end

    def env_from(context)
      {
        store:     context.registers['theme_store'],
        compiler:  context.registers['compiler'],
        renderer:  context.registers['renderer'],
        preview:   !!context.registers['preview'],
        depth_key: 'include_depth'
      }
    end

    def build_params(context, attributes)
      attributes.each_with_object({}) { |(k, v), h| h[k] = context.evaluate(v) }
    end

    def guard_include_depth!(context, env)
      context.registers[env[:depth_key]] ||= 0
      context.registers[env[:depth_key]] += 1
      if context.registers[env[:depth_key]] > DEFAULT_MAX_INCLUDE_DEPTH
        raise Liquid::ArgumentError, "Max include depth (#{DEFAULT_MAX_INCLUDE_DEPTH}) exceeded"
      end
    end

    def unguard_include_depth(context, env)
      context.registers[env[:depth_key]] = [context.registers[env[:depth_key]].to_i - 1, 0].max
    end

    def render_missing(env, rel_path, message:)
      if env[:preview]
        "<!-- #{message} (#{rel_path}) -->"
      else
        Rails.logger.warn({ at: 'liquid_tag', file: rel_path, msg: message }.to_json)
        ""
      end
    end

    def render_liquid_file(context, rel_path, assigns_extra: {})
      env = env_from(context)
      store, compiler, renderer = env.values_at(:store, :compiler, :renderer)
      return render_missing(env, rel_path, message: 'Theme env missing') unless store && compiler && renderer
      return render_missing(env, rel_path, message: 'Missing theme file') unless store.exists?(rel_path)

      compiled = compiler.compile(theme_store: store, rel_path: rel_path)
      return render_missing(env, rel_path, message: 'Compile failed') unless compiled

      assigns = context.environments.first.dup
      assigns.merge!(assigns_extra) if assigns_extra

      renderer.render(compiled, assigns: assigns, theme_store: store).to_s
    end

    def resolve_first_existing(env, candidates)
      Array(candidates).each do |rel|
        return rel if theme_exists?(env, rel)
      end
      # If nothing exists, return the first; read will raise a helpful error later
      candidates.first
    end

    def theme_exists?(env, relative_path)
      if env[:theme_store]&.respond_to?(:exists?)
        env[:theme_store].exists?(relative_path)
      else
        root = env[:fs_root].to_s
        File.file?(File.join(root, relative_path))
      end
  end
end
