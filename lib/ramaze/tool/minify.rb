#          Copyright (c) 2008 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

# Localize helps transforming arbitrary text into localized forms using
# a simple regular expression and substituting occurences with predefined
# snippets stored in YAML files.
#
# == Usage:
#
#   Ramaze::Dispatcher::Action::FILTER << Ramaze::Tool::Localize

module Ramaze
  module Tool
    class Minify

      # Enable Localization
      trait :enable => true

      class << self

        include Trinity

        # Enables being plugged into Dispatcher::Action::FILTER

        def call(response, options = {})
          return response unless trait[:enable]
          return response if response.body.nil?
          return response if response.body.respond_to?(:read)
          response.body = localize_body(response.body, options)
          response
        end

        # Localizes a response body.  It reacts to a regular expression as given
        # in trait[:regex].  Every 'entity' in it will be translated, see
        # `localize` for more information.

        def localize_body(body, options)
          locale =
            if languages.include?(response["Content-Language"])
              response["Content-Language"]
            else
              (session[:LOCALE] || set_session_locale).to_s
            end

          body.gsub!(trait[:regex]) do
            localize($1, locale) unless $1.to_s.empty?
          end

          store(locale, default_language) if trait[:collect]

          body
        end

        # Localizes a single 'entity'.  If a translation in the chosen language is
        # not available, it falls back to the default language.

        def localize(str, locale)
          dict = dictionary
          dict[locale] ||= {}
          dict[default_language] ||= {}

          trans = dict[locale][str] ||= dict[default_language][str] ||= str
        rescue Object => ex
          Log.error(ex)
          str
        end

        # Sets session[:LOCALE] to one of the languages defined in the dictionary.
        # It first tries to honor the browsers accepted languages and then falls
        # back to the default language.

        def set_session_locale
          session[:LOCALE] = default_language
          accepted_langs = request.locales << default_language

          mapping = trait[:mapping]
          dict = dictionary

          accepted_langs.each do |language|
            if mapped = mapping.find{|k,v| k === language }
              language = mapped[1]
            end

            if dict.key?(language)
              session[:LOCALE] = language
              break
            end
          end

          session[:LOCALE]
        end

        # Returns the dictionary used for translation.

        def dictionary
          trait[:languages].map! {|x| x.to_s }.uniq!
          trait[:dictionary] || load(*languages)
        end

        # Load given locales from disk and save it into the dictionary.

        def load(*locales)
          Log.debug "loading locales: #{locales.inspect}"

          dict = trait[:dictionary] || {}

          locales.each do |locale|
            begin
              dict[locale] = YAML.load_file(file_for(locale))
            rescue Errno::ENOENT
              dict[locale] = {}
            end
          end

          trait[:dictionary] = dict
        end

        # Stores given locales from the dictionary to disk.

        def store(*locales)
          locales.uniq.compact.each do |locale|
            file = file_for(locale)
            data = dictionary[locale].ya2yaml

            Log.dev "saving localized to: #{file}"
            File.open(file, 'w+'){|fd| fd << data }
          end
        rescue Errno::ENOENT => e
          Log.error e
        end

        # Call trait[:file] with the passed locale if it reponds to that,
        # otherwise we call #to_s and % with the locale on it.

        def file_for(locale)
          file_source = trait[:file]

          if file_source.respond_to?(:call)
            file = file_source.call(locale)
          else
            file = file_source.to_s % locale
          end
        end

        # alias for trait[:languages]

        def languages
          trait[:languages]
        end

        # alias for trait[:default_language]

        def default_language
          trait[:default_language]
        end
      end
    end
  end
end
