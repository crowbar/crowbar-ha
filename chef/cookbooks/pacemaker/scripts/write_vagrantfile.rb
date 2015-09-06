#!/usr/bin/env ruby

# Copyright 2015 Ooyala, Inc. All rights reserved.
#
# This file is licensed under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.

require 'rubygems'
require 'kitchen'
require 'kitchen/cli'
require 'kitchen/command'
require 'thor/shell'
require 'yaml'

##########
# Config #
##########
@disk_path = nil	# Where to write virtual disk file
                        # (set to nil to write to ./vagrant_disks)
@disk_size = '10'	# In GB, can be overridden per suite with
                        # :vagrant_disk_size attribute in .kitchen.yml

def create_objs
  @cli = Kitchen::CLI.new(ARGV)
  @config = Kitchen::Config.new
  options = {
    action: 'fake',
    help: nil,
    config: @config,
    shell: Thor::Shell::Basic.new
  }
  @base = Kitchen::Command::Base.new(ARGV, nil, options)
end

def working_instances(args)
  result = (args.length >= 2 ? filter_instances(args[1]) : all_instances)
  result.keep_if { |i| add_disk?(i) }
end

def all_instances
  result = @config.instances
  result.empty? ? nil : result
end

def filter_instances(regexp)
  result = begin
    @config.instances.get(regexp) || @config.instances.get_all(/#{regexp}/)
  rescue RegexpError
    puts 'Invalid Ruby regular expression'
  end

  result = Array(result)
  result.empty? ? nil : result
end

def vagrant_root(instance)
  instance.nil? ? '' : File.join(
    @config.kitchen_root, %w(.kitchen kitchen-vagrant), instance.name
  )
end

def create_vagrantfiles(instances, yaml)
  instances.each do |i|
    vagrantdir = ::File.join(@config.kitchen_root, 'Vagrantfiles')
    ::Dir.mkdir(vagrantdir) unless ::Dir.exist?(vagrantdir)
    file = ::File.join(vagrantdir, "Vagrantfile-add-disk-#{i.name}.rb")
    if @disk_path.nil?
      path = ::File.join(@config.kitchen_root, 'vagrant_disks')
    else
      path = @disk_path
    end
    ::Dir.mkdir(path) unless ::Dir.exist?(path)
    vdfile = ::File.join(path, "disk-#{i.name}.vdi")
    size = pick_size(i)
    puts "Creating #{file}"
    write_vagrantfile(i, file, vdfile, size)
    add_vagrantfile_entry(i, file, yaml)
  end
end

def pick_size(instance)
  if instance.provisioner[:attributes].key?(:vagrant_disk_size)
    (instance.provisioner[:attributes][:vagrant_disk_size].to_i * 1024).to_i
  else
    (@disk_size.to_i * 1024).to_i
  end
end

def add_disk?(instance)
  instance.provisioner[:attributes].key?(:add_vagrant_disk) \
      && instance.provisioner[:attributes][:add_vagrant_disk]
end

def write_vagrantfile(instance, file, vdfile, size)
  vagrantfile = ::File.open(file, 'w')
  vagrantfile.write(vagrantfile_contents(vdfile, size)) if add_disk?(instance)
  vagrantfile.close
end

# We add the conditional here because the Vagrantfiles are associated with
# a suite in the .kitchen.yml file, but each suite can have more than one
# instance, depending how many platforms are defined.  So, each instance
# will read *all* the Vagrantfiles, but it should only apply the one matching
# its own #{suite}-#{platform}.  test-kitchen doesn't expose the instance
# name to vagrant, so we need to figure it out from kitchen's vagrant path
# (which kitchen chdirs to before running Vagrant) and make sure it matches
# the instance in the Vagrantfile name.  Phew!
def vagrantfile_contents(file, size)
  <<-"EOF"
instance = __FILE__.match(/.*Vagrantfile-add-disk-(.*)\\.rb$/)
if (::Dir.pwd.match(instance[1]))
  disk = "#{file}"
  Vagrant.configure('2') do |c|
    c.vm.provider :virtualbox do |p|
      p.customize ['createhd', '--filename', disk, '--size', '#{size}']
      p.customize ['storageattach', :id,
                   '--storagectl', 'IDE Controller',
                   '--port', '1',
                   '--device', '1',
                   '--type', 'hdd',
                   '--medium', disk]
    end
  end
end
EOF
end

def add_vagrantfile_entry(instance, file, yaml)
  suites = yaml['suites'].select { |s| s['name'] == instance.suite.name }
  suites.each do |s|
    s['driver'] = {} unless s.key?('driver')
    s['driver']['vagrantfiles'] = [] unless s['driver'].key?('vagrantfiles')
    s['driver']['vagrantfiles'] << file
  end
end

def kitchen_yaml
  kitchen_yml = ::File.join(@config.kitchen_root, '.kitchen.yml')
  YAML.load_file(kitchen_yml)
end

def write_kitchen_yaml(yaml)
  kitchen_local = ::File.join(@config.kitchen_root, '.kitchen.local.yml')
  ::File.open(kitchen_local, 'w') do |y|
    y.write yaml.to_yaml
  end
  puts 'Wrote .kitchen.local.yaml'
end

create_objs
instances = working_instances(ARGV)
yaml = kitchen_yaml
create_vagrantfiles(instances, yaml)
write_kitchen_yaml(yaml)
