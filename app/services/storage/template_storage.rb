require "aws-sdk-s3"
require "zip"
require "securerandom"

module Storage
  class TemplateStorage
  def initialize(
    bucket: ENV.fetch("SELLIOLY_TEMPLATES_BUCKET"),
    region: ENV.fetch("AWS_REGION", "eu-west-3")
  )
    @bucket = bucket
    @client = Aws::S3::Client.new(region: region)
  end

  # Download a theme zip from S3 to a local temp file.
  #
  # theme_handle:  "hyper"
  # theme_version: "1.0.0"
  #
  # returns: absolute path to local zip file
  def download_theme_zip(theme_handle:, theme_version:)
    key = "themes/#{theme_handle}/#{theme_version}.zip"

    tmp_root   = Rails.root.join("tmp", "themes")
    FileUtils.mkdir_p(tmp_root)

    filename   = "#{theme_handle}-#{theme_version}-#{SecureRandom.hex(6)}.zip"
    local_path = tmp_root.join(filename)

    @client.get_object(
      bucket: @bucket,
      key:    key,
      response_target: local_path.to_s
    )

    local_path.to_s
  end

  # Extract a zip file into dest_root, preserving inner structure.
  #
  # zip_path:   path to local zip
  # dest_root:  base directory for extraction, e.g. "storage/shops/123/themes/hyper-1.0.0"
  def extract_zip(zip_path:, dest_root:)
    FileUtils.mkdir_p(dest_root)

    Zip::File.open(zip_path) do |zip_file|
      zip_file.each do |entry|
        next if entry.name_is_directory?

        target_path = File.join(dest_root, entry.name)
        FileUtils.mkdir_p(File.dirname(target_path))

        # Overwrite if exists
        entry.extract(target_path) { true }
      end
    end
  end
end
