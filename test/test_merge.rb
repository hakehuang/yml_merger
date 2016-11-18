#! ruby -I../

#require 'lib/yml_merger'
require 'pathname'
require 'minitest/autorun'
require 'yml_merger'


class MergeTest < Minitest::Test

  #def initialize(option)
  #	@NAME = "merge"

 # end

  def test_merge
  	@entry_yml = "test.yml"
	@search_path  = (Pathname.new(File.dirname(__FILE__)).realpath + 'records/').to_s
	merge_unit      = YML_Merger.new(
    @entry_yml, @search_path
	)
	merged_data     = merge_unit.process()
	puts "creating './merged_data.yml'"
	File.write('./merged_data.yml', YAML.dump(merged_data))
  end

end
