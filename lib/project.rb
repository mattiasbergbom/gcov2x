require_relative './file'
require_relative './line'

module GCOV

  class Project
    
    attr_reader :files, :stats
    attr_accessor :name

    def initialize name=""
      @name = name
      @files = []
      @adding = false
    end

    def <<(file)
      @files << file
      _update_stats unless @adding
    end

    def add_files &block
      # suspend stat updates until done adding files
      fail "add_files requires a block" unless block_given?

      # guard against nested calls
      was_adding = @adding
      @adding = true
      yield
      @adding = was_adding

      _update_stats unless @adding

    end

    def _update_stats
      @stats = { 
        :missed_lines => 0,
        :exec_lines => 0,
        :empty_lines => 0,
        :total_exec => 0,
        :total_lines => 0,
        :lines => 0,
        :coverage => 0.0,
        :hits_per_line => 0
      }

      @files.each do |file|
        @stats[:missed_lines] += file.stats[:missed_lines]
        @stats[:exec_lines] += file.stats[:exec_lines]
        @stats[:total_exec] += file.stats[:total_exec]
        @stats[:empty_lines] += file.stats[:empty_lines]
      end
        
      @stats[:lines] = @stats[:exec_lines] + @stats[:missed_lines]
      @stats[:total_lines] = @stats[:lines] + @stats[:empty_lines]
      @stats[:coverage] = @stats[:exec_lines].to_f / @stats[:lines].to_f
      @stats[:coverage_s] = sprintf("%0.01f%",100.0*@stats[:coverage])
      @stats[:hits_per_line] = @stats[:total_exec].to_f / @stats[:lines]
      @stats[:hits_per_line_s] = sprintf("%0.02f",@stats[:hits_per_line])
    end

    def add_dir path, hash={}
      add_files do 
        if hash[:recursive] == true
          filenames = Dir["#{path}/**/*.gcov"]
        else
          filenames = Dir["#{path}/*.gcov"]
        end
        
        filenames.select{|filename| ( hash[:filter].nil? or !hash[:filter].match(GCOV::File.demangle(filename))) }.map{|filename| GCOV::File.load filename }.each do |file|
          if hash[:filter].nil? or !hash[:filter].match( ::File.realpath(file.meta['Source']) )
            self << file
          end
        end # files
      end
    end

    def add_file path, hash={}
      add_files do
        if hash[:filter].nil? or !hash[:filter].match(GCOV::File.demangle(path)) 
          file = GCOV::File.load(path)
          if hash[:filter].nil? or !hash[:filter].match( ::File.realpath(file.meta['Source']) )
            self << file
          end # if
        end # if
      end # add_files
    end # add_file

    def self.load_dir path, hash={}
      project = GCOV::Project.new
      project.add_dir path, hash
      project
    end

  end
end
