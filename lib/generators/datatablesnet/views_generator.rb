# encoding: utf-8

module Datatablesnet
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      source_root File.expand_path('../../../../app/views/datatablesnet', __FILE__)

      desc "Copies views to application"
      class_option :orm

      def copy_table_partial
        copy_file "_table.html.haml", "app/views/datatablesnet/_table.html.haml"
      end
    end
  end
end