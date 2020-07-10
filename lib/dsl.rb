#!/usr/bin/env ruby

require 'pathname'

module Configurable
  def self.with(*attrs)
    not_provided = Object.new

    Module.new do
      attrs.each do |attr|
        define_method attr do |value = not_provided|
          if value === not_provided
            instance_variable_set("@#{attr}", true)
          else
            instance_variable_set("@#{attr}", value)
          end
        end
      end

      attr_writer *attrs
      def configure(&block)
         self.instance_eval(&block)
      end
    end
  end
end


module Cfg
  def self.directory(path, &block)
    dir = CfgDirectory.new(path)
    dir.configure(&block)
    dir.apply
  end

  def self.file(permissions, src: nil, dst: nil, dir: false, diff: true)
    dst = dst || "#{HOME}/#{src}"

    file = CfgFile.new(dst, dir)
    file.install(permissions, src, diff)
  end

  def self.git_folder(folder, repos)
    puts "Updating git folder '#{folder}'"
    puts "-" * 20
    folder = Pathname.new(folder)
    repos.each do |name, url|
      puts "- checking #{name}"
      Utils.git url, folder + name.to_s
    end
  end

  module Utils
    def self.does_differ(src, dst)
        out = `script --return --quiet -c 'git diff --no-index --exit-code "#{dst}" "#{src}"' /dev/null`
        differs = $?.exitstatus == 1
        puts out if differs
        differs
    end

    def self.confirm(text = "Apply Changes?")
      print "#{text} (Y/n): "
      answer = gets.chomp
      answer == "" || answer == "y"
    end

    def self.git(url, location)
        if File.directory?(location + ".git")
            puts "trying to update via git pull"
            FileUtils.cd location do
                puts `git pull`
            end
        else
            puts `git clone --depth 1 #{url} #{location}`
        end
    end
  end

  class FilesystemResource
    include FileUtils

    def initialize(path)
      @path = path
    end

    def exists?()
      File.exists?(@path)
    end
  end

  class CfgDirectory < Cfg::FilesystemResource
    include Configurable.with(:purge, :source)
    def initialize(path)
      super(path)
      @purge = false
    end

    def apply()
      shouldUpdate = true
      sh "rm -rf '#{@path}'" if @purge

      if !@purge && exists?() then
        shouldUpdate = Utils.does_differ @source, @path
        shouldUpdate = Utils.confirm if shouldUpdate
      end
      if shouldUpdate
        sh "install -m 755 -d '#{@path}'"
        sh "cp -Trf #{@source} '#{@path}'"
      end
    end
  end

  class CfgFile < Cfg::FilesystemResource
    def initialize(path, dir)
      super(path)
      @dir = dir
    end

    def install(permissions, src, diff)
      shouldUpdate = true
      if diff && exists?() then
        shouldUpdate = Utils.does_differ src, @path
        shouldUpdate = Utils.confirm if shouldUpdate
      end
      if shouldUpdate then
        if @dir then
          sh "install -pm #{permissions} -d -- #{@path}"
        else
          sh "install -pm #{permissions} -- #{src} #{@path}"
        end
      end
    end
  end
end