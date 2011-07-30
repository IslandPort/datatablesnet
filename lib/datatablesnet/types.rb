
class NoEscape
  def as_json(options = nil) self end #:nodoc:
  def encode_json(encoder) to_s end #:nodoc:

  def initialize text
    @text = text
  end

  def to_s
    @text
  end
end


module ToBoolean
  def self.included(klass)
    klass.send :include, InstanceMethods
  end


  module InstanceMethods
    def to_b
      string = self
      return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
      return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)
      raise ArgumentError.new("invalid value for Boolean: \"#{string}\"")
    end
  end
end

Object.class_eval do
  include ToBoolean
end