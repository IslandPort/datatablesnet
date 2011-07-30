require 'datatablesnet/types'

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

  #Options
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
  #Column Options
  # :name
  # :label
  # :render
  # :format

  module_function

  def template_path
    path = File.expand_path('..', __FILE__)
    $:.unshift(path)
    path
  end

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
                   :save_state => "bStateSave"
                   }


    options =
      {
        :show_actions       => true,
        :per_page           => 25,
        :toolbar_external   => false
      }.merge(options)

    index = 0
    columns.each do |column|
      column[:label] = field_to_label(column[:field]) unless column[:label].present?
      if options[:data_url].present?
        options[:data_url] << "?" if column == columns.first
        options[:data_url] << "column_field_#{index.to_s}=#{column[:field]}"
        if column[:view_link].present?
          options[:data_url] << "&column_view_link_#{index.to_s}=#{column[:view_link]}"
        end
        options[:data_url] << "&" unless column == columns.last
      end
      index += 1
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

    table_options["aoColumns"] = datatable_get_column_defs(options,columns)

    config = {:options => options, :columns =>columns, :table_options => table_options}
    config.to_json
    render :file => template_path + "/_table", :locals => { :table_id => id, :columns => columns, :rows => rows, :config => config}
  end

  def datatable_get_column_defs options, columns
    column_defs = []
    column_options_map = {:width => "sWidth",
                          :sortable => "bSortable",
                          :searchable => "bSearchable",
                          :class => "sClass"}


    column_index =0
    columns.each do |column|
      column_options = {}
      column_options_map.each do |k,v|
        if column[k].present?
          column_options[v] = column[k]
        end
      end
      column_options["fnRender"] = NoEscape.new(options[:render]) if column[:render].present?
      column_options["fnRender"] = NoEscape.new("function (obj) {return #{column[:format]}(obj.aData[#{column_index}])}") if column[:format].present?
      if column[:view_link].present? and options[:server_side]
        column_options["fnRender"] = NoEscape.new("function (obj) {return '<a href = ' + obj.aData[#{columns.length}]['urls']['#{column[:field]}'] + '>' + obj.aData[#{column_index}] + '</a>'}")
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
      column_defs << {"bVisible" => false}
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
        return link_to(obj, row.send(column[:view_link]))
      end
    else
      return obj
    end
  end

  def field_to_label(field)
    label = field.gsub(/[_.]/, " ")
    label.to_s.gsub(/\b\w/){$&.upcase}
  end

  def parse_params params
    grid_options = {}
    columns = []
    order_by = {}
    filter_by = {}
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


  def find(klass, params={}, options = {})
    field_filter_where = {}
    all_filter_where = {}

    grid_options = parse_params params


    options[:page] = grid_options[:page]
    options[:per_page] = grid_options[:per_page]

    # Build order by
    grid_options[:order_by].each do |column, order|
      if options[:order].present?
        options[:order] << ", "
      else
        options[:order] = ""
      end
      options[:order] << "#{column} #{order}"
    end

    # Build filter by
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

    if !field_filter_where.empty? or !all_filter_where.empty?
      options[:conditions] = [field_filter_where.sql_like, all_filter_where.sql_or.sql_like].sql_and.sql_where
    end

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

    total_records = klass.count
    if options[:conditions].present?
      klass.count(:conditions => options[:conditions])
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
          url = url_helper.url_for(row.send(view_link))
        end
        meta[:urls][column[:field]] = url
      end
    end
    return meta
  end

end


