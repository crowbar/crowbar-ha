this_dir = File.dirname(__FILE__)

require File.expand_path("pacemaker/resource/primitive",    this_dir)
require File.expand_path("pacemaker/resource/clone",        this_dir)
require File.expand_path("pacemaker/resource/ms",           this_dir)
require File.expand_path("pacemaker/resource/group",        this_dir)
require File.expand_path("pacemaker/constraint/colocation", this_dir)
require File.expand_path("pacemaker/constraint/location",   this_dir)
require File.expand_path("pacemaker/constraint/order",      this_dir)
