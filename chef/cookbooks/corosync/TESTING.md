TESTING doc
========================

Bundler
-------
A ruby environment with Bundler installed is a prerequisite for using
the testing harness shipped with this cookbook. At the time of this
writing, it works with Ruby 2.0 and Bundler 1.5.3. All programs
involved, with the exception of Vagrant, can be installed by cd'ing
into the parent directory of this cookbook and running "bundle install"

Rakefile
--------
The Rakefile ships with a number of tasks, each of which can be ran
individually, or in groups. Typing "rake" by itself will perform style
checks with Rubocop and Foodcritic, ChefSpec with rspec, and
integration with Test Kitchen using the Vagrant driver by
default.Alternatively, integration tests can be ran with Test Kitchen
cloud drivers.

```
$ rake -T
rake cleanup                     # Clean up generated files
rake cleanup:kitchen_destroy     # Destroy test-kitchen instances
rake integration                 # Run full integration
rake integration:vagrant_setup   # Setup the test-kitchen vagrant instances
rake integration:vagrant_verify  # Verify the test-kitchen vagrant instances
```

Integration Testing
-------------------
Integration testing is performed by Test Kitchen. Test Kitchen will
use the Vagrant driver to instantiate machines and apply cookbooks.
After a successful converge, tests are uploaded and ran out of band of
Chef. Tests should be designed to ensure that a recipe has
accomplished its goal.

Integration Testing using Vagrant
---------------------------------
Integration tests can be performed on a local workstation using
Virtualbox or VMWare. Detailed instructions for setting this up can be
found at the [Bento](https://github.com/chef/bento) project web site.

Integration tests using Vagrant can be performed with
```
bundle exec rake integration
```
