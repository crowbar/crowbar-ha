;(function($, doc, win) {
  'use strict';

  function StonithNodePlugins(el, options) {
    this.root = $(el);
    this.html = {
       table_row: '<tr data-id="{0}"><td>{0}</td><td><input type="text" class="form-control" value="{1}"/></td></tr>'
    };

    this.options = $.extend(
      {
        storage: '#proposal_attributes',
        deployment_storage: '#proposal_deployment',
        path: 'stonith/per_node/nodes',
        watchedRoles: ['pacemaker-cluster-founder', 'pacemaker-cluster-member']
      }
    );

    this.initialize();
  }

  StonithNodePlugins.prototype._ignore_event = function(evt, data) {
    var self = this;

    var row_id = '[data-id="{0}"]'.format(data.id);
    var row    = $(evt.target).find(row_id)

    if (self.options.watchedRoles.indexOf(data.role) == -1) { return true; }
    if (evt.type == 'nodeListNodeAllocated' && row.length > 0) { return true; }
    if (evt.type == 'nodeListNodeUnallocated' && row.length == 0) { return true; }

    return false;
  };

  StonithNodePlugins.prototype.initialize = function() {
    var self = this;

    // Update nodes that have been moved around in deployment
    self.updateNodesFromDeployment();
    // Render what we already have
    self.renderPluginParams();
    // And start listening on changes
    self.registerEvents();
  };

  StonithNodePlugins.prototype.registerEvents = function() {
    var self = this;

    // Update JSON on input changes
    this.root.find('tbody tr').live('change', function(evt) {
      var elm = $(this);
      var id  = elm.data('id');
      var key = '{0}/params'.format(id);
      var val = elm.find('input').val();

      self.writeJson(key, val, "string");
    });

    // Append new table row and update JSON on node alloc
    this.root.on('nodeListNodeAllocated', function(evt, data) {
      if (self._ignore_event(evt, data)) { return; }

      $(this).find('tbody').append(self.html.table_row.format(data.id, ''));

      var key = '{0}/params'.format(data.id);
      var val = "";

      self.writeJson(key, val, "string");
    });

    // Remove the table row and update JSON on node dealloc
    this.root.on('nodeListNodeUnallocated', function(evt, data) {
      if (self._ignore_event(evt, data)) { return; }

      $(this).find('[data-id="{0}"]'.format(data.id)).remove();
      self.removeJson(data.id, null, "map");
    });
  };

  StonithNodePlugins.prototype.updateNodesFromDeployment = function() {
    var self = this;

    var plugin_params = self.retrievePluginParams();

    // Get a membership hash on both sides
    var existing_nodes = {};
    var deployed_nodes = {};

    $.each(plugin_params, function(node, value) { existing_nodes[node] = true; });

    $.each(self.options.watchedRoles, function(index, role) {
      var role_path  = 'elements/{0}'.format(role);
      var role_nodes = $(self.options.deployment_storage).readJsonAttribute(role_path);
      $.each(role_nodes, function(index, node) { deployed_nodes[node] = true; });
    });

    // Then update all those nodes which have been removed from deployment
    for (var existing_node in existing_nodes) {
       if (!deployed_nodes[existing_node]) { self.removeJson(existing_node, null, "map"); }
    }
    // and those which have been added
    for (var deployed_node in deployed_nodes) {
       if (!existing_nodes[deployed_node]) {
         var key = '{0}/params'.format(deployed_node);
         var val = "";
         self.writeJson(key, val, "string");
       }
    }
  };

  // Initial render
  StonithNodePlugins.prototype.renderPluginParams = function() {
    var self = this;

    var params = $.map(self.retrievePluginParams(), function(value, node_id) {
      return self.html.table_row.format(node_id, value.params);
    });
    this.root.find('tbody').html(params.join(''));
  };

  // FIXME: these could be refactored into a common plugin
  StonithNodePlugins.prototype.retrievePluginParams = function() {
    return $(this.options.storage).readJsonAttribute(
      this.options.path,
      {}
    );
  };

  StonithNodePlugins.prototype.writeJson = function(key, value, type) {
    return $(this.options.storage).writeJsonAttribute(
      '{0}/{1}'.format(
        this.options.path,
        key
      ),
      value,
      type
    );
  };

  StonithNodePlugins.prototype.removeJson = function(key, value, type) {
    return $(this.options.storage).removeJsonAttribute(
      '{0}/{1}'.format(
        this.options.path,
        key
      ),
      value,
      type
    );
  };

  $.fn.stonithNodePlugins = function(options) {
    return this.each(function() {
      new StonithNodePlugins(this, options);
    });
  };
}(jQuery, document, window));

function update_no_quorum_policy(evt, init) {
  var no_quorum_policy_el = $('#crm_no_quorum_policy');
  var non_forced_policy = no_quorum_policy_el.data('non-forced');
  var was_forced_policy = no_quorum_policy_el.data('is-forced');
  var non_founder_members = $('#pacemaker-cluster-member').children().length;

  if (non_forced_policy == undefined) {
    non_forced_policy = "stop";
  }

  if (evt != undefined) {
    // 'nodeListNodeAllocated' is fired after the element has been added, so
    // nothing to do. However, 'nodeListNodeUnallocated' is fired before the
    // element is removed, so we need to fix the count.
    if (evt.type == 'nodeListNodeUnallocated') { non_founder_members -= 1; }
  }

  if (non_founder_members > 1) {
    if (was_forced_policy) {
      no_quorum_policy_el.val(non_forced_policy);
      no_quorum_policy_el.removeData('non-forced');
    }
    no_quorum_policy_el.data('is-forced', false)
    no_quorum_policy_el.removeAttr('disabled');
  } else {
    if (!init && !was_forced_policy) {
      no_quorum_policy_el.data('non-forced', no_quorum_policy_el.val());
    }
    no_quorum_policy_el.data('is-forced', true)
    no_quorum_policy_el.val("ignore");
    no_quorum_policy_el.attr('disabled', 'disabled');
  }
}

$(document).ready(function($) {
  $('#stonith_per_node_container').stonithNodePlugins();

  // FIXME: apparently using something else than
  // $('#stonith_per_node_container') breaks the per-node table :/
  $('#stonith_per_node_container').on('nodeListNodeAllocated', function(evt, data) {
    update_no_quorum_policy(evt, false)
  });
  $('#stonith_per_node_container').on('nodeListNodeUnallocated', function(evt, data) {
    update_no_quorum_policy(evt, false)
  });

  update_no_quorum_policy(undefined, true)
});
