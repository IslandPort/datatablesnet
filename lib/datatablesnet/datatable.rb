require 'datatablesnet/types'
require 'datatablesnet/hash_sql'
require 'uri'

module Datatable

  class UrlHelper
    include Rails.application.routes.url_helpers
    #default_url_options[:routing_type] = :path

    def url_for(options = {})
      options ||= {}
      url = case options
      when String
        super
      when Hash
        super
      when :back
        super
      else
        polymorphic_path(options)
      end

      url
    end
  end



  module_function

  def template_path
    path = File.expand_path('..', __FILE__)
    $:.unshift(path)
    path
  end



  # The main method for generating the necessary javascript and html to display a datatable.
  # This supports both ajax and non-ajax datatables.
  #
  # The following ar the input parameters:
  #
  # * <tt>id</tt> - The html id of the datatable
  # * <tt>columns</tt> - Array of columns to be displayed. Each column is represented by a hash containing
  # column configuration
  # * <tt>rows</tt> - Rows to be displayed if the table is non-ajax
  # * <tt>options</tt> - Table options
  #
  # The following are the table options:
  #
  # :sort_by
  # :additional_data
  # :search
  # :search_label
  # :processing
  # :persist_state
  # :per_page
  # :no_records_message
  # :auto_width
  # :row_callback
  # :show_actions
  # :info_callback
  #
  # The following are Column Options
  # :name
  # :label
  # :render
  # :format
  def datatable_tag id, columns = [], rows = nil, options = {}
    options_map = {:sort_by => "aaSorting",
                   :search => "bFilter",
                   :search_label => "sSearch",
                   :processing => "bProcessing",
                   :persist_state => "bSaveState",
                   :per_page => "iDisplayLength",
                   :no_records_message => "sZeroRecords",
                   :auto_width => "bAutoWidth",
                   :dom => "sDom",
                   :data_url => "sAjaxSource",
                   :server_side => "bServerSide",
                   :auto_scroll => "bScrollInfinite",
                   :pagination_type => "sPaginationType",
                   :paginate => "bPaginate",
                   :save_state => "bStateSave",
                   }


    options =
      {
        :show_actions       => false,
        :per_page           => 25,
        :toolbar_external   => false,
        :show_only_when_searched => false,
        :checkboxes => false
      }.merge(options)

    if options[:data_url].present?
      url = URI::split(options[:data_url])
    end
    
    index = 0
    columns.each do |column|
      column[:label] = field_to_label(column[:field]) unless column[:label].present?
      if options[:data_url].present?
        options[:data_url] << "?" if column == columns.first and url[7] == nil
        options[:data_url] << "&" if column == columns.first and url[7] != nil
        options[:data_url] << "column_field_#{index.to_s}=#{column[:field]}"
        if column[:view_link].present?
          options[:data_url] << "&column_view_link_#{index.to_s}=#{column[:view_link]}"
        end
        options[:data_url] << "&" unless column == columns.last
      end
      index += 1
    end

    if options[:show_only_when_searched]
      options[:data_url] << "&show_only_when_searched=true"
    end

    if options[:toolbar].present? or options[:toolbar_external]
      options[:dom]='<"toolbar">lfrtip'
    end

    table_options = {}
    options_map.each do |k,v|
      if options[k].present?
        table_options[v] = options[k]
      end
    end

    if options[:language].present?
      puts "language present"
      table_options["oLanguage"] = datatable_get_language_defs(options[:language])
    end

    table_options["fnInfoCallback"] = NoEscape.new(options[:info_callback]) if options[:info_callback].present?

    table_options["aoColumns"] = datatable_get_column_defs(options,columns)

    config = {:options => options, :columns =>columns, :table_options => table_options}
    config.to_json
    
    render :partial => "datatablesnet/table", :locals => { :table_id => id, :columns => columns, :rows => rows, :config => config}
  end

  def datatable_get_language_defs options
    language_options_map = {:info_empty => "sInfoEmpty",
                            :info_filtered => "sInfoFiltered",
                            :empty_table => "sEmptyTable",
                            :zero_records => "sZeroRecords"}

    language_options = {}
    language_options_map.each do |k,v|
      if options[k].present?
        language_options[v] = options[k]
      end
    end
    language_options
  end

  def datatable_get_column_defs options, columns
    column_defs = []
    column_options_map = {:width => "sWidth",
                          :sortable => "bSortable",
                          :searchable => "bSearchable",
                          :class => "sClass"}


    if options[:checkboxes]
      column_defs << nil
    end

    column_index =0
    columns.each do |column|
      column_options = {}
      column_options_map.each do |k,v|
        if column[k].present?
          column_options[v] = column[k] unless k==:width and request.env['HTTP_USER_AGENT'] =~ /Firefox/
        end
      end
      column_options["fnRender"] = NoEscape.new(options[:render]) if column[:render].present?
      column_options["fnRender"] = NoEscape.new("function (obj) {return #{column[:format]}(obj.aData[#{column_index}])}") if column[:format].present?
      if column[:view_link].present? and options[:server_side]
        column_options["fnRender"] = NoEscape.new("function (obj) {if(obj.aData[#{columns.length}]['urls']['#{column[:field]}']!=null) {return '<a href = ' + obj.aData[#{columns.length}]['urls']['#{column[:field]}'] + '>' + obj.aData[#{column_index}] + '</a>'} else {return obj.aData[#{column_index}]} }")
      end

      unless column_options.empty?
        column_defs << column_options
      else
        column_defs << nil
      end
      column_index+=1
    end

    if options[:show_actions]
      column_defs << nil
    end

    if options[:server_side]
      if request.env['HTTP_USER_AGENT'] =~ /Firefox/
        column_defs << {"sClass" => "hidden"}
      else
        column_defs << {"bVisible" => false}
      end
    end

    return column_defs
  end

  def get_field_data obj, field
    attrs = field.split('.')
    attrs.each do |attr|
      if obj
        obj = obj.send attr
      else
        return ""
      end
    end
    return obj
  end

  def datatable_get_column_data row, column
    obj = get_field_data(row, column[:field])

    if column[:view_link].present?
      if column[:view_link] == "."
        return link_to(obj, row)
      else
        link_obj = row.send(column[:view_link])
        if link_obj
          return link_to(obj, link_obj)
        else
          return obj
        end
      end
    else
      return obj
    end
  end

  def field_to_label(field)
    label = field.gsub(/[_.]/, " ")
    label.to_s.gsub(/\b\w/){$&.upcase}
  end

  def parse_params klass, params
    grid_options = {}
    columns = []
    order_by = {}
    filter_by = {}

    if params["show_only_when_searched"].present?
      grid_options[:show_only_when_searched] = true
    else
      grid_options[:show_only_when_searched] = false
    end

    (0..params[:iColumns].to_i-2).each do |index|
      column = {}
      column[:field] = params["column_field_#{index}"]
      column[:searchable] = params["bSearchable_#{index}"].to_b
      column[:sortable] = params["bSortable_#{index}"].to_b
      column[:index] = index
      if params["column_view_link_#{index}"].present?
        column[:view_link] = params["column_view_link_#{index}"]
      end
      columns << column
      if params["iSortCol_#{index}"].present?
        order_column_index = params["iSortCol_#{index}"]
        order_column = params["column_field_#{order_column_index}"]
        order_column_order = params["sSortDir_#{index}"] || "DESC"
        order_by[order_column] = order_column_order
      end
      if params["sSearch_#{index}"].present?
        filter_by[column[:field]] = params["sSearch_#{index}"]
      end
    end

    search_by = {}
    params.each do |key, value|
      if key =~ /query_.*/ and !value.empty?
        if key =~ /.*_to/
          field_name = key[6..-4]
          field_name.sub!('__', '.')
          search_by[field_name] = {} unless search_by[field_name].present?
          search_by[field_name][:to] = convert_param(klass, field_name, value)
        elsif key =~ /.*_from/
          field_name = key[6..-6]
          field_name.sub!('__', '.')
          search_by[field_name] = {} unless search_by[field_name].present?
          search_by[field_name][:from] = convert_param(klass, field_name,value)
        else
          field_name = key[6..-1]
          field_name.sub!('__', '.')
          search_by[field_name] = convert_param(klass, field_name, value)
        end
      end
    end

    grid_options[:search_by] = search_by
    grid_options[:columns] = columns
    grid_options[:order_by] = order_by
    grid_options[:filter_by] = filter_by
    grid_options[:page] = (params[:iDisplayStart].to_i/params[:iDisplayLength].to_i rescue 0)+1
    grid_options[:per_page] = params[:iDisplayLength]
    if params["sSearch"].present?
      grid_options[:search] = params["sSearch"]
    end

    grid_options
  end

  def convert_param klass, field_name, value
    attrs = field_name.split('.')
    attrs.each_with_index do |attr, index|
      if index == attrs.size - 1
        field_name = attr
      else
        puts "Getting association: #{attr}"
        klass = klass.reflect_on_association(attr.to_sym).klass
      end
    end

    case klass.columns_hash[field_name].type
      when :string
        klass.validators_on(field_name).each do |validator|
          if validator.instance_of?(ActiveModel::Validations::NumericalityValidator)
            if validator.options[:only_integer]
                value = value.to_i
            end
          end
        end
      when :date, :datetime
        value = Date.parse(value)
      when :integer, :float, :decimal
        value = value.to_i
    end
    value
  end


  def build_condition(klass, params={}, options = {})
    grid_options = parse_params klass, params
    build_condition_internal(klass, grid_options, options[:conditions].present? ? options[:conditions] : nil)
  end

  def build_condition_internal(klass, grid_options, conditions)
    field_filter_where = {}
    all_filter_where = {}
    search_filter_where = {}

    grid_options[:filter_by].each do |column, value|
      field_filter_where[column] = value
    end

    # Search all searchable columns
    if grid_options[:search].present?
      grid_options[:columns].each do |column|
        if column[:searchable].to_b
          all_filter_where[column[:field]] = grid_options[:search]
        end
      end
    end

    #process search_by
    grid_options[:search_by].each do |column, value|
      if value.instance_of?(Hash)
        if value[:to].present?
          search_filter_where[column] = (value[:from]..value[:to])
        else
          search_filter_where[column] = value[:from]
        end
      else
        search_filter_where[column] = value
      end
    end

    if !field_filter_where.empty? or !all_filter_where.empty? or !search_filter_where.empty?
      sql_where = [field_filter_where.sql_like, all_filter_where.sql_or.sql_like, search_filter_where.sql_and].sql_and.sql_where
      if conditions
        if conditions.instance_of?(Array)
          condition_string = conditions[0]
          condition_params = conditions[1..-1]
        else
          condition_string = conditions
          condition_params = []
        end
        condition_string << " and (" << sql_where[0] << ")"
        condition_params += sql_where[1..-1]
        conditions = [condition_string] + condition_params
      else
        conditions = sql_where
      end
    end
    conditions
  end

  def find(klass, params={}, options = {})
    puts params.to_json

    grid_options = parse_params klass, params

    options[:page] = grid_options[:page]
    options[:per_page] = grid_options[:per_page]

    # Build order by
    grid_options[:order_by].each do |column, order|
      if column
        if options[:order].present?
          options[:order] << ", "
        else
          options[:order] = ""
        end
        options[:order] << "#{column} #{order}"
      end
    end

    if grid_options[:show_only_when_searched]
      if grid_options[:search_by].empty?
        json_data = {:sEcho => params[:sEcho],
             :iTotalRecords =>  0,
             :iTotalDisplayRecords => 0,
             :aaData => []}
        return json_data
      end
    end

    # Build filter by
    options[:conditions] = build_condition_internal(klass, grid_options, options[:conditions].present? ? options[:conditions] : nil)

    puts options[:conditions]

    rows = klass.paginate options

    objects = []
    rows.each do |row|
      object = []
      grid_options[:columns].each do |column|
        object << get_field_data(row, column[:field])
      end

      meta = build_row_meta row, grid_options
      object << meta
      objects << object
    end


    include = []
    if options[:include].present?
      include = options[:include]
    end

    total_records = klass.count :include => include
    if options[:conditions].present?
      total_display_records = klass.count(:conditions => options[:conditions], :include => include)
    else
      total_display_records = total_records
    end
    json_data = {:sEcho => params[:sEcho],
                 :iTotalRecords =>  total_records,
                 :iTotalDisplayRecords => total_display_records,
                 :aaData => objects
    }
    return json_data
  end


  def build_row_meta row, grid_options
    url_helper = UrlHelper.new
    meta={}
    meta[:urls] = {}
    grid_options[:columns].each do |column|
      if column[:view_link].present?
        view_link = column[:view_link]
        if view_link == "."
          url = url_helper.url_for(row)
        else
          link_obj = row.send(view_link)
          if link_obj
            url = url_helper.url_for(link_obj)
          else
            url = nil
          end
        end
        meta[:urls][column[:field]] = url
      end
    end
    return meta
  end

end


