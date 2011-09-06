

module HashSql

  def self.included(klass)
    klass.send :include, InstanceMethods
  end

  module InstanceMethods

    attr_accessor :sql_operator
    attr_accessor :sql_comparator

    def sql_where
      if self.instance_of?(Hash)
        build_where
      else
        combine_wheres
      end
    end

    def sql_and
      self.sql_operator = "and"
      return self
    end

    def sql_or
      self.sql_operator = "or"
      return self
    end

    def sql_like
      self.sql_comparator = "like"
      return self
    end


    private

     def build_where
        values = []
        where_string = ""
        self.each do |name, value|
          if where_string != ""
            where_string << " #{sql_operator ? sql_operator : 'and'} "
          end

          if value.instance_of?(Range)
            where_string << "(#{name} BETWEEN ? AND ?)"
            values << value.first
            values << value.last
          elsif self.sql_comparator = "like"
            where_string <<  "#{name} LIKE ?"
            values << '%' + value.to_s + '%'
          else
            where_string <<  "#{name} = ?"
            values << value
          end
        end
        where = [where_string] + values
        return where
      end

      def combine_wheres
        values = []
        where_string = ""
        self.each do |where_hash|
          unless where_hash.empty?
            where = where_hash.sql_where
            if where_string != ""
              where_string << " and "
            end

            where_string << "(#{where[0]})"

            values += where[1..-1]
          end
        end

        [where_string] + values
      end
  end
end

[Array, Hash].each do |klass|
  klass.class_eval do
    include HashSql
  end
end
