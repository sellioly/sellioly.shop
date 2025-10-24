# frozen_string_literal: true

module Theme
  # Responsible for safe reads of theme files and computing per-file digests.
  # Does not mutate global Liquid state.
  class ThemeStore
    attr_reader :root

    def initialize(root:)
      @root = root.to_s
    end

    # ---- JSON templates/schemas ------------------------------------------------
    def read_template_json(name)
      read_json(File.join(@root, "templates", ensure_json(name)))
    end

    def read_layout_json(name)
      read_json(File.join(@root, "layout", ensure_json(name)))
    end

    def read_schema_json(type)
      read_json(File.join(@root, "schemas", ensure_json(type)))
    end

    # ---- Liquid sources --------------------------------------------------------
    def read_liquid(rel_path)
      # rel_path examples: "sections/header.liquid", "layout/theme.liquid", "snippets/card.liquid"
      full = File.join(@root, rel_path)
      return nil unless File.file?(full)
      File.read(full)
    end

    def file_digest(rel_path)
      full = File.join(@root, rel_path)
      return nil unless File.exist?(full)
      stat = File.stat(full)
      "m#{stat.mtime.to_i}s#{stat.size}"
    rescue StandardError
      nil
    end

    def exists?(rel_path)
      File.file?(File.join(@root, rel_path))
    end

    # Liquid-compatible LocalFileSystem for include/snippet/section tags
    def file_system(prefix: "%s.liquid")
      Liquid::LocalFileSystem.new(@root, prefix)
    end

    private

    def read_json(path)
      return nil unless File.file?(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError, Encoding::UndefinedConversionError
      nil
    end

    def ensure_json(name)
      n = name.to_s
      n.end_with?(".json") ? n : (n + ".json")
    end
  end
end
