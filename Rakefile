#
# Copyright 2011-2013, Dell
# Copyright 2013-2015, SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

begin
  require "sprockets/standalone"

  Sprockets::Standalone::RakeTask.new(:assets) do |task, sprockets|
    task.assets = [
      "**/application.js"
    ]

    task.sources = [
      "crowbar_framework/app/assets/javascripts"
    ]

    task.output = "crowbar_framework/public/assets"

    task.compress = true
    task.digest = true

    sprockets.js_compressor = :closure
    sprockets.css_compressor = :sass
  end

  namespace :assets do
    def available_assets
      Pathname.glob(
        File.expand_path(
          "../crowbar_framework/public/assets/**/*",
          __FILE__
        )
      )
    end

    def digested_regex
      /(-{1}[a-z0-9]{32}*\.{1}){1}/
    end

    task :setup_logger do
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO
    end

    task non_digested: :setup_logger do
      available_assets.each do |asset|
        next if asset.directory?
        next unless asset.to_s =~ digested_regex

        simple = asset.dirname.join(
          asset.basename.to_s.gsub(digested_regex, ".")
        )

        if simple.exist?
          simple.delete
        end

        @logger.info "Symlinking #{simple}"
        simple.make_symlink(asset.basename)
      end
    end

    task clean_dangling: :setup_logger do
      available_assets.each do |asset|
        next if asset.directory?
        next if asset.to_s =~ digested_regex

        next unless asset.symlink?

        # exist? is enough for checking the symlink target as it resolves the
        # link target and checks if that really exists. The check for having a
        # symlink is already done above.
        unless asset.exist?
          @logger.info "Removing #{asset}"
          asset.delete
        end
      end
    end
  end

  Rake::Task["assets:compile"].enhance do
    Rake::Task["assets:non_digested"].invoke
    Rake::Task["assets:clean_dangling"].invoke
  end
rescue
end

unless ENV["PACKAGING"] && ENV["PACKAGING"] == "yes"
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)

  task :syntaxcheck do
    system("for f in `find -name \*.rb`; do echo -n \"Syntaxcheck $f: \"; ruby -c $f || exit $? ; done")
    exit $?.exitstatus
  end

  task default: [
    :spec,
    :syntaxcheck,
    "rubydeps:svg"
  ]
end

IGNORED_CLASSES = ["RSpec::Core::ExampleGroup"]
DUMP_FILE = "rubydeps.dump"
DOT_FILE  = "rubydeps.dot"
SVG_FILE  = "rubydeps.svg"

file DUMP_FILE do
  sh "RUBYDEPS=y rspec"
end

file DOT_FILE => DUMP_FILE do
  ignore_regexp = IGNORED_CLASSES.join "|"
  sh "rubydeps --class-name-filter='^(?!#{ignore_regexp})'"
  dot = File.read(DOT_FILE)
  dot.gsub!("rankdir=LR", "rankdir=TB")
  # Unfortunately due to https://github.com/dcadenas/rubydeps/issues/4
  # we need to manually exclude some superfluous dependencies which
  # go in the wrong direction.
  dot.gsub!(/\\\n/, "")
  dot.gsub!(/^(?=\s+Object )/, "#")
  dot.gsub!(/^(?=\s+"Pacemaker::Resource::Meta" ->)/, "#")
  dot.gsub!(/^(?=\s+"Pacemaker::CIBObject" ->)/, "#")
  dot.gsub!(/^(?=\s+"Chef::Mixin::Pacemaker::StandardCIBObject" -> "(?!Pacemaker::CIBObject))/, "#")
  dot.gsub!(/^(?=\s+"Chef::Mixin::Pacemaker::RunnableResource" -> "(?!Pacemaker::CIBObject))/, "#")
  File.open(DOT_FILE, "w") { |f| f.write(dot) }
end

file SVG_FILE => DOT_FILE do
  sh "dot -Tsvg #{DOT_FILE} > #{SVG_FILE}"
end

namespace :rubydeps do
  desc "Clean rubydeps dump"
  task :clean do
    FileUtils.rm_f([DUMP_FILE])
  end

  desc "Regenerate #{DUMP_FILE}"
  task dump: DUMP_FILE

  desc "Regenerate #{DOT_FILE}"
  task dot: DOT_FILE

  desc "Regenerate #{SVG_FILE}"
  task svg: SVG_FILE
end
