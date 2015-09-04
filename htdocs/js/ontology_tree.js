$( document ).ready(function() {
  $.jstree.defaults.core.data = true;
  $.jstree.defaults.core.themes.dots = false;
  $.jstree.defaults.core.themes.icons = false;
  $.jstree.defaults.checkbox.three_state = false;
  var GFD_id = $('#phenotype_tree span').attr('id');

  // store list of phenotypes
  var init_ids_string = $("#update_phenotype_tree input[name=phenotype_ids]").val();
  var init_list = init_ids_string.split(',');

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
  $("#search_phenotype #search_phenotype_button").click(function() {
    var phenotype_name = $("#query_phenotype_name").val(); 
    $('#add_phenotype_info_msg').show();
    $("#phenotype_tree").jstree("search", phenotype_name);
  });

  $('#phenotype_tree').on('after_open.jstree', function(e, data) {
    $('#add_phenotype_info_msg').hide();
  });


  $('#phenotype_tree').on('select_node.jstree', function(e, data) {
    var ids_string = $("#update_phenotype_tree input[name=phenotype_ids]").val();
    var list = [];
    if (ids_string) {
      list = ids_string.split(',');
    }
    var new_id = data.node.id;
    console.log(new_id);
    if (!contains(list, new_id)) {
      list.push(new_id);
      $("#update_phenotype_tree input[name=phenotype_ids]").val(list);
    }
    ids_string = $("#update_phenotype_tree input[name=phenotype_ids]").val();
    if (!(compareArrays(init_list, list))) {
      // show update button
      $("#update_phenotype_tree").css("display", "block"); 
      $("#add_phenotype_bg").attr('class', 'bg-danger');
      $("#add_phenotype_msg").css("display", "block"); 
    } else {
      $("#update_phenotype_tree").css("display", "none"); 
      $("#add_phenotype_bg").attr('class', '');
      $("#add_phenotype_msg").css("display", "none"); 
    }

  });

  $('#phenotype_tree').on('deselect_node.jstree', function(e, data){
    var ids_string = $("#update_phenotype_tree input[name=phenotype_ids]").val();
    var list = []; 
    if (ids_string) {
      list = ids_string.split(',');
    }
    var delete_id = data.node.id;
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i] === delete_id) {
        list.splice(i, 1);
      }
    }
    $("#update_phenotype_tree input[name=phenotype_ids]").val(list);

    if (!(compareArrays(init_list, list))) {
      $("#update_phenotype_tree").css("display", "block"); 
      $("#add_phenotype_bg").attr('class', 'bg-danger');
      $("#add_phenotype_msg").css("display", "block"); 
    } else {
      $("#update_phenotype_tree").css("display", "none"); 
      $("#add_phenotype_bg").attr('class', '');
      $("#add_phenotype_msg").css("display", "none"); 
    }

  });

  function contains(a, obj) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] === obj) {
        return true;
      }
    }
    return false;
  }

  function compareArrays(arr1, arr2) {
    return $(arr1).not(arr2).length === 0 && $(arr2).not(arr1).length === 0;
  }



});
















