$( document ).ready(function() {
  $.jstree.defaults.core.data = true;
  $('#jstree_demo_div').jstree({
    
    'core' : {
      'data' : {
        "url" : "populate_onotology_tree.cgi",

        "data" : function (node) {
          return { "id" : node.id };
        }
      }
    }
  });
});

