#! ruby -I../

require_relative '../lib/yml_merger'
require 'pathname'
require 'minitest/autorun'
require 'yaml'
#require 'yml_merger'


class MergeTest < Minitest::Test

  #def initialize(option)
  #	@NAME = "merge"

 # end
  def test_merge_full_feature
  	@entry_yml = "test.yml"
	@search_path  = (Pathname.new(File.dirname(__FILE__)).realpath + 'records/').to_s
	merge_unit      = YML_Merger.new(
    @entry_yml, @search_path
	)
	merged_data     = merge_unit.process()
	#puts "creating './merged_data.yml'"
	#File.write('./merged_data.yml', YAML.dump(merged_data))
	#__replace__
	assert_equal 'I will not be replaced', merged_data['T1']['replace']['remains']['msg']
	assert_equal 'I replace something', merged_data['T1']['replace']['replaced']['msg']
	#__remove__
	assert_equal 'I will not be removed', merged_data['T1']['remove']['remains']['msg']
	#__add__
	assert_equal true, merged_data['T1']['remove']['removed'].nil?
	assert_equal 'Component', merged_data['T1']['__add__'][0]
	assert_equal true, merged_data.has_key?('Component')
	#post_process_lib
	assert_equal 'I am node1', merged_data['T1']['post_process_lib']['node1']['msg']
	assert_equal true, merged_data['T1']['post_process_lib']['node3'].nil?
	assert_equal 'I am node1', merged_data['T1']['post_process_lib']['node1']['msg']
	assert_equal false, merged_data['T1']['post_process_lib']['node2'].nil?
	#post_process_app
	assert_equal false, merged_data.has_key?('T3')
	found_common = false
	found_hierarchy = false
	merged_data['T1']['src']['sample_array'].each do |item|
		if item['path'].include?('help_top')
			found_common = true
		end
		if item['path'].include?('me_hier')
			found_hierarchy = true
		end
	end
	#__common__
	assert_equal true,found_common
	#__hierarchy
	assert_equal true, found_hierarchy
  end

  def test_merge_new_load
 	@entry_yml = "test_new_load_root.yml"
	@search_path  = (Pathname.new(File.dirname(__FILE__)).realpath + 'records/').to_s
	merge_unit      = YML_Merger.new(
    @entry_yml, @search_path
	)
	merged_data     = merge_unit.process()
	#puts merged_data.to_yaml
	assert_equal 'I am from branch a', merged_data['a']['node_root']['branch_a']
	assert_equal  "I am from normal", merged_data['project']['node_root']['branch_normal']
	assert_equal 1, merged_data['project']['node_root']['src'].count
	assert_equal nil, merged_data['b']
	assert_equal nil, merged_data['c']

  end

end
