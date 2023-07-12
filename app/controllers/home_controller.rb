class HomeController < ApplicationController
  def index
    @path = Rails.root.to_s + ("/storage/template")
    @liquid_instance.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    @template = @liquid_instance.parse(File.read(@path + '/test.liquid')) # Parses and compiles the template
    # @items = @template.root.nodelist
    @test = @template.render('product' => { 'collection' => { 'name' => 'Computer' } }) # => "hi tobi"
  end
end
