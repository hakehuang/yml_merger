#! ruby -I../

require 'lib/yml_merger'
require 'pathname'


@entry_yml = "test.yml"
@search_path  = (Pathname.new(File.dirname(__FILE__)).realpath + 'records/').to_s

puts @entry_yml, @search_path

merge_unit      = YML_Merger.new(
    @entry_yml, @search_path, logger: @logger
)
merged_data     = merge_unit.process()
puts "creating './merged_data.yml'"
File.write('./merged_data.yml', YAML.dump(merged_data))
