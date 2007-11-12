#          Copyright (c) 2006 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

module Ramaze
  def self.contrib(*args)
    Ramaze::Contrib.load *args
  end

  module Contrib
    class << self
      def load(*contribs)
        contribs.each do |name|
          require 'ramaze/contrib'/name
          const = Ramaze::Contrib.const_get(name.to_s.camel_case)
          Ramaze::Global.contribs << const
          const.startup if const.respond_to?(:startup)
          Inform.dev "Loaded contrib: #{const}"
        end
      end
    end
  end
end