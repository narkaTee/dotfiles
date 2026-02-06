# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'digest'

module Cfg
  module Storage
    REPO_PATH = Git::REPO_PATH
    PROFILES_DIR = File.join(REPO_PATH, 'profiles')
    TEMPLATES_DIR = File.join(REPO_PATH, 'templates')

    module_function

    def list_profile_names
      return [] unless Dir.exist?(PROFILES_DIR)

      Dir[File.join(PROFILES_DIR, '*.yaml')].map do |path|
        File.basename(path, '.yaml')
      end
    end

    def load_profile(name)
      path = File.join(PROFILES_DIR, "#{name}.yaml")
      raise ProfileNotFoundError, "Profile not found: #{name}" unless File.exist?(path)

      YAML.safe_load_file(path, symbolize_names: true) || {}
    end

    def save_profile(name, data)
      FileUtils.mkdir_p(PROFILES_DIR)
      path = File.join(PROFILES_DIR, "#{name}.yaml")
      File.write(path, YAML.dump(stringify_keys(data)))
    end

    def delete_profile(name)
      path = File.join(PROFILES_DIR, "#{name}.yaml")
      File.delete(path) if File.exist?(path)
    end

    def load_template(template_name)
      path = File.join(TEMPLATES_DIR, template_name)
      raise TemplateNotFoundError, "Template not found: #{template_name}" unless File.exist?(path)

      File.read(path)
    end

    def save_template(template_name, content)
      FileUtils.mkdir_p(TEMPLATES_DIR)
      path = File.join(TEMPLATES_DIR, template_name)
      File.write(path, content)
    end

    def delete_template(template_name)
      path = File.join(TEMPLATES_DIR, template_name)
      File.delete(path) if File.exist?(path)
    end

    def generate_template_name(content, extension)
      hash = Digest::SHA256.hexdigest(content)[0, 7]
      "#{hash}.#{extension}"
    end

    def stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
      when Array
        obj.map { |v| stringify_keys(v) }
      else
        obj
      end
    end
  end
end
