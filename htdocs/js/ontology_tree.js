$( document ).ready(function() {
  $.jstree.defaults.core.data = true;
  $.jstree.defaults.core.themes.dots = false;
  $.jstree.defaults.core.themes.icons = false;
  $.jstree.defaults.checkbox.three_state = false;
  $('#jstree_demo_div').jstree({
    
    'core' : {
      'data' : {
        "url" : "populate_onotology_tree.cgi",

        "data" : function (node) {
          return { "id" : node.id };
        }
      }
    },
    "checkbox" : {
      "keep_selected_style" : false
    },
    "plugins" : [ "checkbox", "sort" ]
  });
});

