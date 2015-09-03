$( document ).ready(function() {
  $.jstree.defaults.core.data = true;
  $.jstree.defaults.core.themes.dots = false;
  $.jstree.defaults.core.themes.icons = false;
  $.jstree.defaults.checkbox.three_state = false;
  var GFD_id = $('#phenotype_tree span').attr('id');

  $('#phenotype_tree').jstree({
    
    "search" : {
      'ajax' : {
        url : 'populate_onotology_tree.cgi',
        dataType : "json",
        error : function(data, type){
          console.log(type);
        },
        success: function(data, type) {
        }, 
      }
    },

    "checkbox" : {
      "keep_selected_style" : false
    },

    "plugins" : [ "checkbox", "sort", "search" ],

    'core' : {
      'data' : {
        "url" : "populate_onotology_tree.cgi",
        "data" : function (node) {
          return { "id" : node.id,
                   "GFD_id" : GFD_id,
                   "type" : 'expand' };
        }
      }
    },
  });
  $("#search_phenotype").click(function() {
    var phenotype_name = $("#query_phenotype_name").val(); 
    $("#phenotype_tree").jstree("search", phenotype_name);
  });


  $('#phenotype_tree').on('select_node.jstree', function(e, data) {
    var ids_string = $("#update_phenotype_tree input[name=phenotype_ids]").val();
    var list = ids_string.split(',');
    var new_id = data.node.id;
    if (!contains(list, new_id)) {
      list.push(new_id);
      ids_string = list.join();
      $("#update_phenotype_tree input[name=phenotype_ids]").val(list);
    }
    ids_string = $("#update_phenotype_tree input[name=phenotype_ids]").val();
  });

  $('#phenotype_tree').on('deselect_node.jstree', function(e, data){
    var ids_string = $("#update_phenotype_tree input[name=phenotype_ids]").val();
    var list = ids_string.split(',');
    var delete_id = data.node.id;
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i] === delete_id) {
        list.splice(i, 1);
      }
    }
    ids_string = list.join();
    $("#update_phenotype_tree input[name=phenotype_ids]").val(list);
  });


  function contains(a, obj) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] === obj) {
        return true;
      }
    }
    return false;
  }

});



