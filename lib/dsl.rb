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
    dir = Objects::CfgDirectory.new(path)
    dir.configure(&block)
    dir.apply
  end

  def self.file(permissions, src: nil, dst: nil, dir: false, diff: true)
    dst = dst || "#{HOME}/#{src}"

    file = Objects::CfgFile.new(dst, dir)
    file.install(permissions, src, diff)
  end

  def self.git_directory(dir, repos)
    git_directory = Objects::GitDirectory.new(dir, repos)
    git_directory.sync()
  end
end


module Objects
  class FilesystemResource
    include FileUtils

    def initialize(path)
      @path = path
    end

    def exists?()
      File.exists?(@path)
    end
  end

  class CfgDirectory < FilesystemResource
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

  class CfgFile < FilesystemResource
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

  class GitDirectory < FilesystemResource
    def initialize(dir, repos)
      super(dir)
      @repos = repos
    end

    def sync()
      path = Pathname.new(@path)
      puts "Updating git folder '#{path}'"
      FileUtils.mkdir_p path unless exists?

      allowed_dirs = @repos.keys.map { |k| k.to_s }
      to_delete = path.children.select { |name|
        !allowed_dirs.include?(name.basename.to_s)
      }
      if !to_delete.empty?
        puts "-" * 20
        puts "Cleaning up, allowed dirs: " + allowed_dirs.join(", ")
      end
      to_delete.each do |name|
        sh "rm -rf #{path + name}"
      end

      puts "-" * 20
      @repos.each do |name, url|
        puts "- checking #{name}"
        Utils.git url, path + name.to_s
      end
      puts
    end
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
    answer = STDIN.gets.chomp
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
