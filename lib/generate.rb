require 'roo'
require 'roo-xls'
require 'erb'
require 'facets'
require 'fileutils'
require 'optparse'

options = {}
optparse = OptionParser.new do |opts|
  opts.on('-s', '--spreadsheet=FILE', 'cis benchmark excel doc') do |s|
    options[:spreadsheet] = s
  end
  opts.on('-n', '--osname=NAME', 'Operating system name. Eg. windows') do |n|
    options[:osname] = n
  end
  opts.on('-v', '--osversion=VERSION', 'Operating system version. Eg. server2016') do |v|
    options[:osversion] = v
  end
  opts.on('-d', '--manifestdir=DIR', 'Directory to write generated manifests to. Defaults to ./manifests') do |d|
    options[:manifest_dir] = d
  end
end

# Make mandatory args easier
begin
  optparse.parse!
  mandatory = [:spreadsheet, :osname, :osversion]
  missing = mandatory.select{ |param| options[param].nil? }
  unless missing.empty?
    raise OptionParser::MissingArgument.new(missing.join(', '))
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

# Defaults
options[:manifest_dir] = './manifests' if options[:manifest_dir].nil?

# Quick 'n ugly mapping
spreadsheet = options[:spreadsheet]
osname = options[:osname]
osversion = options[:osversion]
manifest_dir = options[:manifest_dir]

# Open Spreadsheet
xls = Roo::Spreadsheet.open(spreadsheet)

puppetmodule = 'cis_' + osname
sheet_regex = %r{^(?<level>Level\s\d)?(\s-\s)?(?<profile>.*)$}
#namespace_regex = %r{\A[a-z][a-z0-9_]*\Z}

# Used to map column to the corresponding header of the sheet
headers = {
  1 => :section,
  2 => :recommendation,
  3 => :title,
  4 => :status,
  5 => :scoring_status,
  6 => :description,
  7 => :rationale_statement,
  8 => :remediation_procedure,
  9 => :audit_procedure,
  10 => :impact_statement,
  11 => :notes,
  12 => :cis_controls,
  13 => :cce_id,
  14 => :references,
}

# easily return parent versions
# https://stackoverflow.com/a/12192707
#class String
#  def split_by_last(char=".")
#    pos = self.rindex(char)
#    pos != nil ? [self[0...pos], self[pos+1..-1]] : [self]
#  end
#end

def section_template()
<<EOT
# @summary A short summary of the purpose of this class
#
# Todo: sanatize section[:description] to add context here
#
# @example
#   include <%= class_name %>
#
class <%= class_name %> (
  Array $benchmark_blacklist = $<%= module_name %>::<%= osversion %>::benchmark_blacklist,
){
<% section[:benchmarks].each do |benchmark_number| %>
  # Benchmark: <%= benchmark_number %>
  # Title: <%= benchmarks[benchmark_number][:title] %>
  # Scoring Status: <%= benchmarks[benchmark_number][:scoring_status] %>
  unless '<%= benchmark_number %>' in $benchmark_blacklist {
    warning('Resource(s) to manage benchmark <%= benchmark_number %> have not been implemented yet.')
  }
<% end %>
}
EOT
end

def main_template()
<<EOT
# @summary A short summary of the purpose of this class
#
# Todo: add description
#
# @example
#   include <%= class_name %>
#
class <%= class_name %> (
  Array $benchmark_blacklist = []
){
<% section[:benchmarks].each do |benchmark_number| %>
  # Benchmark: <%= benchmark_number %>
  # Title: <%= benchmarks[benchmark_number][:title] %>
  # Scoring Status: <%= benchmarks[benchmark_number][:scoring_status] %>
  unless '<%= benchmark_number %>' in $benchmark_blacklist {
    warning('Resource(s) to manage benchmark <%= benchmark_number %> have not been implemented yet.')
  }
<% end %>
}
EOT
end

# remove invalid characters from namespace
def clean_namespace(string)
  namespace_regex = %r{\A[a-z][a-z0-9_]*\Z}
  if matches = string.match(namespace_regex)
    string
  else
    cleaned = string.gsub!(/[^a-z0-9_]/, '')
    cleaned
  end
end

## https://stackoverflow.com/questions/754407/what-is-the-best-way-to-chop-a-string-into-chunks-of-a-given-length-in-ruby
#def chunk(string, size)
#  (0..(string.length-1)/size).map{|i|string[i*size,size]}
#end

class CisClass
  include ERB::Util
  attr_accessor :template, :module_name, :class_name, :section, :benchmarks, :osversion

  def initialize(template, module_name, class_name, section, benchmarks, osversion)
    @template    = template
    @section     = section
    @benchmarks  = benchmarks
    @class_name  = class_name
    @module_name = module_name
    @osversion   = osversion
  end

  def render()
    ERB.new(@template, nil, '-').result(binding)
  end

  def save(file)
    File.open(file, "w+") do |f|
      f.write(render)
    end
  end
end

xls.sheets.each do |sheet_name|
  next if sheet_name == 'License'
  puts ''
  puts '--------------'
  puts sheet_name
  puts '--------------'
  sheet = xls.sheet(sheet_name)

  # contains the parsed information from the excel doc
  # data[row] == { column_header => cell data, ... }
  data = {}

  # iterate over each row and parse each column
  if !sheet.nil?
    # manually limiting for testing
#    last_row = 10
    last_row    = sheet.last_row
    last_column = sheet.last_column

    if !last_row.nil? and !last_column.nil?
      for row in 2..last_row # skip first row (headers)
        data[row] = {}
        for col in 1..last_column
          v = sheet.cell(row, col)
          # only keep columns that have data
          data[row].merge!(headers[col] => v.to_s) unless v.nil?
        end
      end
    else
      puts 'Seems no data in sheet: ' + sheet_name
    end
  end

  sections = {}
  benchmarks = {}

  # map benchmark to document sections
  data.each do |doc_row, column|
    # shorthand since this is used a lot
    section_number = column[:section]

    if column.key?(:recommendation) # if there is a recommendation number then the row describes a benchmark
      # shorthand since this is used a lot
      benchmark_number = column[:recommendation]

      # benchmark numbers should be unique so simply add to benchmarks hash
      benchmarks[benchmark_number] = column

      top_section = section_number.split('.').first
      # logic to add/append to :benchmarks array of the top parent section
      if sections[top_section].has_key?(:benchmarks)
        sections[top_section][:benchmarks] << benchmark_number
      else
        sections[top_section][:benchmarks] = [benchmark_number]
      end

    else # if there is no recommendation number the row describes a section
      unless sections.has_key?(section_number)
        # section numbers are unique so we can pre-populate with the title and description
        sections[section_number] = {:title => column[:title], :description => column[:description]}
      end
    end
  end

  level = nil
  profile = nil
  classname = nil

  class_struct = {}

  sections.each do |section, section_info|
    unless section_info[:benchmarks].nil?
      # debugging output
      puts
      puts section + ' - ' + section_info[:title]
      puts "benchmarks: #{section_info[:benchmarks]}"
      puts "number benchmarks: #{section_info[:benchmarks].count}"

      if matches = sheet_name.match(sheet_regex)
        level = matches[:level]
        profile = matches[:profile]
      else
        puts "Failed to parse sheet name"
      end

      # Figures out the correct classname
      if level.nil?
        classname = puppetmodule + '::' + osversion + '::' + profile.snakecase + '::' + clean_namespace(section_info[:title].snakecase)
      else
        classname = puppetmodule + '::' + osversion + '::' + level.snakecase + '::' + profile.snakecase + '::' + clean_namespace(section_info[:title].snakecase)
      end

      # Initilize ERB class template
      manifest = CisClass.new(section_template, puppetmodule, classname, section_info, benchmarks, osversion)

      # create directory structure
      namespaces = classname.split("::")
      manifest_file =  manifest_dir + '/' + namespaces[1..(namespaces.size - 1)].join('/') + '.pp'
      dirname = File.dirname(manifest_file)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end

      # Write manifest to stdout for debugging
#      puts
#      puts 'Puppet code:'
#      puts manifest.render

      # writes out the manifest file
      manifest.save(manifest_file)
      puts "Manifest written to #{manifest_file}"

    end
  end

end
