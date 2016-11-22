# yml_merger

This is a tool that helps to organize the YML in different files.

[source code](https://github.com/hakehuang/yml_merger.git)

# install

```bash
gem install yml_merger
gem install deep_merge
```

# usage:

Please refer to the test.

create a yml file as below

test.yml
```
__load__:
  more.yml
  
<your yml content>

```

```ruby
require 'yml_merger'

@entry_yml = "test.yml"
@search_path  = (Pathname.new(File.dirname(__FILE__)).realpath + 'records/').to_s
merge_unit      = YML_Merger.new(
    @entry_yml, @search_path
	)
merged_data     = merge_unit.process()
puts "creating './merged_data.yml'"
File.write('./merged_data.yml', YAML.dump(merged_data))
```

the test.yml and more.yml content are merged together

# YML oraginzations:

you can using a tree toplogic to orgainize you application, the YML files can be catalogies to three types:

1. the root node which is the entry point of a tree yml

2. the branch node which is the branch pint of a tree yml

3. the leaf node which is the leaf node of a tree.

we recommand that each leaf node shall be uniq feature. and branch node defines the branch shared feature with hierarchy.


# merging rules:

* __load__

indicated some other YML file will be added, this enalbes user to separate yml definitions to different file

```yaml
__load__
  - a.yml
  - b.yml
  - http://yourhost/c.yml

my_definitions:
  ...
```


* __add__

using to refer to a external hash like

```yaml

a:
  __add__:
    - b
  ...

b:
  ...

```
means hash a will include hash be by deep_merge


* __common__

this will be processed after all YML files are loaded and merged into a plain hash

```yaml

a:
  __common__:
    common_settings:
    ...
  b:
  c:
```

then __common__ settings will be processed and result as below

```yaml

a:
  b:
    common_settings:
  c:
    common_settings:

```

* __hierarchy__:

this will be processed during yml file loadding.

file a.yml

```yaml
__load__:
  - b.yml

a:
  some_attr:
    __hierarchy__:
      hiearchy_attr:
        ...
    ta:
      ...

```

file b:
```yaml

a:
  some_attr:
    other_attr:
       ...

```

then the merged result is:

```yaml

a:
  some_attr:
    other_attr:
      hiearchy_attr:
        ...
      ...
    ta:
      hiearchy_attr:
        ...
      ...

```


* __remove__

this will be processed after merged all yml files


file a.yml

```yaml
__load__:
  - b.yml

a:
  some_attr:
    __remove__:
      special_attr:
        ...
    ta:
      ...

```

file b:
```yaml

a:
  some_attr:
    special_attr:
      ...
    other_attr:
      ...

```

then the merged result is:

```yaml

a:
  some_attr:
    other_attr:
      ...
    ta:
      ...

```

* __replace__

this will be processed after merged all yml files


file a.yml

```yaml
__load__:
  - b.yml

a:
  some_attr:
    __replace__:
      special_attr:
        settings_new:
          ...
    ta:
      ...

```

file b:
```yaml

a:
  some_attr:
    special_attr:
      settings_old:
        ...
    other_attr:
      ...

```

then the merged result is:

```yaml

a:
  some_attr:
    special_attr:
      settings_new:
        ...
    other_attr:
      ...
    ta:
      ...
```

* pre-process-merge

this is deprecated feature, you can use __common__ or __hierarchy__ instead

```yaml

a:
  node:
    mode: pre-process-merge
    attribute: required
    pre_process_node:
      msg: this is preprocessing parts
  pre_process_node:
    ...

```
the processing result will be

```yaml

a:
  pre_process_node:
    msg: this is preprocessing parts
    ...

```

* post-process-app


```yaml
a:
  mode: post-process-app
  attribute: required
  ...

b:
  ...

c:
  mode: post-process-app
  attribute: required
  ...

```

process result

```yaml
a:
  ...

c:
  ...

```

this is use to select one or more nodes from a pre-defined node list e.g

file a.yml

```yaml
__load__
  - b.yml

a:
  attribute: required

c:
  attribute: required

```


file b.yml

```yaml
__common__
  mode: post-process-app
  
a:
  ...

b:
  ...

c:
  ...

'''

the result will be

```yaml
a:
  ...

c:
  ...
```

* post-process-lib

```yaml
a:
  mode: post-process-lib
  node_1:
    attribute: required
    ...
  node_2:
    ...
  node_3:
    attribute: required

```

process result

```yaml
a:
  node_1:
    ...
  node_3:
    ...


```

this is use to select one or more nodes from a pre-defined node list e.g

file a.yml

```yaml
__load__
  - b.yml

a:
  f1:
    attribute: required
  f3:
    attribute: required

```


file b.yml

```yaml
a: 
  mode: post-process-lib
  f1:
    ...
  f2:
    ...
  f3:
    ...
  f4:
    ...
  f5:
    ...
  ...
'''

the result will be

```yaml
a:
  f1:
  f3:
```

# merge process

```ruby
       @filestructure = process_file(@ENTRY_YML)
       merge_by_add(@filestructure)
       merge_by_common(@filestructure)
       delete_node(@filestructure,'__common__')
       delete_node(@filestructure,'__load__')
       #delete_node(@filestructure,'__add__')
       post_process(@filestructure)
```

