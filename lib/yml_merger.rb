require 'rubygems'
require "yaml"
require "deep_merge"
require 'fileutils'
require 'open-uri'
require 'uri'
require 'logger'


# implement of deep merge for nested hash and array of hash
class YML_Merger
    attr_accessor :filestructure, :filestack, :ENTRY_YML, :search_paths

    # initialize YML merge
    # Params:
    # - filepath: the entry file name
    # - seatch_paths: rootpath to search all the needed YML files 
    def initialize(filename, search_paths, logger: nil)
        @logger = logger 
        unless (logger)
            @logger = Logger.new(STDOUT)
            @logger.level = Logger::INFO
        end
        @ENTRY_YML           = search_paths + '/' + filename
        @search_paths       = search_paths
        @filestructure = Hash.new()
        @filestack = Array.new()
        # @KEY_LIST = ['__remove__','__load__', '__common__', '__hierarchy__', '__replace__', '__add__']
        @KEY_LIST = %w('__remove__', '__load__', '__common__', '__hierarchy__', '__replace__', '__add__')
    end

    # process the YMLs
    def process
       @filestructure = process_file(@ENTRY_YML)
       merge_by_add(@filestructure)
       merge_by_common(@filestructure)
       delete_node(@filestructure,'__common__')
       delete_node(@filestructure,'__load__')
       #delete_node(@filestructure,'__add__')
       post_process(@filestructure)
    end

  private

    # post process nodes with strong condition
    # execute post-process-lib and post-process-app
    # clean the pre-process-merge node
    # Params:
    # - struct: the hash to be processed
    def post_process(struct)
      return if struct.class != Hash
      merge_by_replace!(struct)
      merge_by_remove!(struct)
      struct.each_key do |key|
        next if Hash != struct[key].class
        if struct.key?('mode') and struct['mode'] == 'post-process-lib'
          if struct[key].has_key?('attribute')
            if struct[key]['attribute'] == 'required'
               @logger.debug "keep #{key}"
            else
               struct.delete(key)
               @logger.debug "deletes #{key}"
               next
            end
          else
            @logger.debug "delete #{key}"
            struct.delete(key)
            next
          end
        end
        if struct[key].key?('mode') and struct[key]['mode'] == 'post-process-app'
          if struct[key].has_key?('attribute')
            if struct[key]['attribute'] == 'required'
              @logger.debug "keep #{key}"
            else
              struct.delete(key)
              @logger.debug "deletes #{key}"
              next
            end
          else
            @logger.debug "delete #{key}"
            struct.delete(key)
            next
          end
        end
        if struct[key].key?('mode') and struct[key]['mode'] == 'pre-process-merge'
            struct.delete(key)
            @logger.debug "deletes #{key}"
            next
        end
        post_process(struct[key])
      end
    end

    def load_file(path)
        if path =~ URI::regexp
          structure = process_file(path)
        else
          structure = process_file(@search_paths + path.tr('\\','/'))
        end
        return structure
    end

    # load and process yml files
    # recursive load and process all files in '__load__' section
    # Params:
    # - file: the path to the yml file
    def process_file(file)
        #check if file is loaded yet
        return if @filestack.include?(file)
        #if not loaded,push to stack
        @filestack.push(file)
        #add globals.yml before load file
        @logger.info file
        content = open(file.tr('\\','/')){|f| f.read}
        content = YAML::load(content, aliases: true)
        return if  content.class == FalseClass
        #if has file dependence load it
        if content['__load__'] != nil
            #load file in reversed sequence
            content['__load__'].reverse_each do |loadfile|
              if loadfile.class == Hash
                structure = Hash.new
                temp_structure = load_file(loadfile.keys[0])
                loadfile.each do |key, value|
                  if value.class == Array
                    value.each do |vt|
                      t = Hash.new
                      t[vt] = Hash.new
                      t[vt].deep_merge(temp_structure[vt])
                      structure.deep_merge(t)
                    end
                  end
                end
              else
                if loadfile =~ URI::regexp
                  structure = process_file(loadfile)
                else
                  structure = process_file(@search_paths + loadfile.gsub('\\','/'))
                end
              end
              content = content.deep_merge(deep_copy(structure))
              pre_process(content)
              merge_by_hierarchy(content)
              #content = content.deep_merge(structure)
            end
        end
        pre_process(content)
        merge_by_hierarchy(content)
        delete_node(content, '__hierarchy__')
        return content
    end

    # load and process yml files
    # recursive load and process all files in '__load__' section
    # Params:
    # - file: the path to the yml file
    def pre_process(struct)
        return if struct.class != Hash
        struct.each_key do |key|
          next if struct[key].class != Hash
          if struct[key].has_key?('mode') and struct[key]['mode'] == 'pre-process-merge'
             if struct[key]['attribute'] == 'required'
                struct[key].each_key do |subkey|
                    if struct.has_key?(subkey) and struct[subkey].class == Hash
                        @logger.debug "pre process #{key} -> #{subkey}"
                        struct[subkey] = struct[subkey].deep_merge(deep_copy(struct[key][subkey]))
                       #struct[subkey] = struct[subkey].deep_merge(struct[key][subkey])
                       #puts struct[subkey].to_yaml
                    end
                end
             end
          end
          pre_process(struct[key])
        end
    end


    # delete all node/subnode which key name is 'key' in 'hash'
    # Params:
    # - struct: the hash
    # - type: the key to delete
    def delete_node(struct, key)
        struct.each_key do |subnode|
            next if struct[subnode] == nil
            struct.delete(key)
            delete_node(struct[subnode],key) if Hash == struct[subnode].class
        end
    end

    # perform merge by "__hierarchy__" struct
    # Params:
    # - struct: the hash
    def merge_by_hierarchy(struct)
        return if Hash != struct.class
        if struct['__hierarchy__'] != nil
            struct.each_key do |subnode|
                next if subnode =~ /^__/ or @KEY_LIST.include?(subnode)
                next if struct[subnode].class != Hash or struct['__hierarchy__'].class != Hash
                struct[subnode] = struct[subnode].deep_merge(deep_copy(struct['__hierarchy__']))
                #struct[subnode] = struct[subnode].deep_merge(struct["__hierarchy__"])
            end
            #struct.delete('__hierarchy__')
        end
        struct.each_key do |subnode|
            merge_by_hierarchy(struct[subnode])
        end
    end

    # perform merge by "__common__" node
    # Params:
    # - struct: the hash
    def merge_by_common(struct)
        return if Hash != struct.class
        if struct['__common__'] != nil
            struct.each_key do |subnode|
                next if @KEY_LIST.include?(subnode)
                next if struct[subnode].class != Hash or struct['__common__'].class != Hash
                struct[subnode] = struct[subnode].deep_merge(deep_copy(struct['__common__']))
                #struct[subnode] = struct[subnode].deep_merge(struct['__common__'])
            end
            struct.delete('__common__')
        end
        struct.each_key do |subnode|
            merge_by_common(struct[subnode])
        end
    end

    # hash deep merge with __add__ recursively
    # Params:
    # - struct: the hash
    # - subnode: the subnode key to be add
    # - addon: the key that idetify the addon module
    def deep_add_merge(struct, subnode, addon)
      return if Hash != struct.class
      return if struct[addon].nil?
      if struct[addon]['__add__'].nil?
        #we do not want the addon module to change the status
        struct[addon]['attribute'] = ""
        #struct[subnode] = struct[subnode].deep_merge(deep_copy(struct[addon]))
        struct[addon]['attribute'] = 'required'
        return
      end
      #if has more addon
      if struct[addon]['__add__'].count != 0
         #puts "add #{addon}"
         struct[addon]['attribute'] = ""
         #struct[subnode] = struct[subnode].deep_merge(deep_copy(struct[addon]))
         struct[addon]['attribute'] = 'required'  
         struct[addon]['__add__'].each do |submodule|         
           deep_add_merge(struct, addon, submodule)
         end
      else
        #puts "add #{addon}"
        struct[addon]['attribute'] = ""
        #struct[subnode] = struct[subnode].deep_merge(deep_copy(struct[addon]))
        struct[addon]['attribute'] = 'required'   
      end
    end

    # perform merge by "__add__" node only applys to application type
    # Params:
    # - struct: the hash to be processed
    def merge_by_add(struct)
        #only scan the top level
        return if Hash != struct.class
        struct.each_key do |subnode|
          next if @KEY_LIST.include?(subnode)
          next if struct[subnode].nil?
          next if struct[subnode].class != Hash
          if struct[subnode].has_key?('__add__')
            struct[subnode]['__add__'].each do |addon|
              next if struct[addon].class != Hash
            begin
              next if struct[subnode]['configuration']['section-type'] != 'application'
              if struct[addon]['configuration']['section-type'] != 'component'
                @logger.warn "WARNING #{addon} is required as component but has not a component attribute"
              end
            rescue
              @logger.warn "no full configuration/section-type with the merge_by_add with #{subnode} add #{addon}"
            end
              deep_add_merge(struct, subnode, addon)
            end
            #struct[subnode].delete('__add__')
          end
        end
    end

    # prepare merge by "__replace__" node
    # Params:
    # - struct: the hash to be processed    
    def merge_by_replace!(struct)
        return if Hash != struct.class
        #get the replace hash
        return if ! struct.has_key?('__replace__')
        temp = Hash.new
        temp = temp.deep_merge(deep_copy(struct['__replace__']))
        temp.each_key do |key|
           next if ! struct.has_key?(key)
           delete_node(struct, key)
           struct[key] = temp[key]
        end
        struct.delete('__replace__')
    end

    # perform merge by "__remove__" node
    # Params:
    # - struct: the hash to be processed
    def merge_by_remove!(struct)
        return if Hash != struct.class
        #get the replace hash
        return if ! struct.has_key?('__remove__')
        temp = Hash.new
        temp = temp.deep_merge(deep_copy(struct['__remove__']))
        temp.each_key do |key|
          next if ! struct.has_key?(key)
          if struct['__remove__'][key] == nil
            delete_node(struct, key)
          else
            if struct['__remove__'][key].class == Array
              arr = Array.new
              arr = deep_copy(struct['__remove__'][key])
              arr.each do |item|
                next if ! struct[key].include?(item)
                struct[key].delete(item)
              end
            elsif struct['__remove__'][key].class == Hash
              hash = Hash.new
              hash = hash.deep_merge(deep_copy(struct['__remove__'][key]))
              hash.each_key do |subkey|
                next if ! struct[key].has_key?(subkey)
                delete_node(struct[key], subkey)
              end
            end
          end
        end
        struct.delete('__remove__')
    end

    # deep copy the hash in compare the shallow copy
    # Params:
    # -o: the hash to be copied 
    def deep_copy(o)
      Marshal.load(Marshal.dump(o))
    end
end
