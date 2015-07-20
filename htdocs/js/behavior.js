$(document).ready(function(){

  $("#query_phenotype_name, #query, #query_gene_name, #query_disease_name").click(function(){
    var id = $(this).attr('id');
    console.log(id);
    $(this).autocomplete({
      source: function(request, response) {
        $.ajax({
          url: "autocomplete.cgi",
          dataType: "json",
          data: {
            term : request.term,
            query_type : id,
          },
          success: function(data, type) {
            items = data;
            response(items);
          },
          error: function(data, type){
            console.log( type);
          }
        });
      },
      minLength: 2,
      select: function(event, ui) {}
    });
  }); 


  $(".phenotype_right").mouseenter(function(){
    $(this).prev().css('background-color', '#D4D8D1');
  }); 

  $(".phenotype_right").mouseleave(function(){
    $(this).prev().css('background-color', 'white');
  }); 

  $(".header_gene_disease").click(function(){
    $header = $(this);
    $content = $header.next();
    $content.toggle(function() {
      $span = $header.children("span");
      if ($(this).is(":visible")) {
        $($span).removeClass("glyphicon glyphicon-chevron-up");
        $($span).addClass("glyphicon glyphicon-chevron-down");
      } else {
        $($span).removeClass("glyphicon glyphicon-chevron-down");
        $($span).addClass("glyphicon glyphicon-chevron-up");
      }
    });
  });

  $(".edit").click(function(){
    $button = $(this);
    $button_parent = $button.parent();
    $this_content = $button.closest(".show_db_content");
    $edit_content = $this_content.next();
    $edit_content.show(function(){
      $button_parent.hide();
    });
  });

  $(".discard").click(function(){
    $button = $(this);
    $this_content = $button.closest(".show_edit_content");
    $prev_content = $this_content.prev();
    $this_content.hide(function(){
      $prev_content.find('.show_toggle_view_button').show();
    });
  });

  $(".show").click(function(){
    $button = $(this);
    $button_parent = $button.parent();
    $this_content = $button.closest(".show_add_comment");
    $show_content = $this_content.next();
    $show_content.show(function(){
      $button_parent.hide();
    });
  });

  $(".discard_add_comment").click(function(){
    $button = $(this);
    $this_content = $button.closest(".add_comment");
    $prev_content = $this_content.prev();
    $this_content.hide(function(){
      $prev_content.show();
    });
  });

  $(".show_add_publication_button").click(function(){
    $button = $(this);
    $button_parent = $button.parent();
    $this_content = $button.closest(".show_add_publication");
    $show_content = $this_content.next();
    $show_content.show(function(){
      $button_parent.hide();
    });
  });

  $(".discard_add_publication").click(function(){
    $button = $(this);
    $this_content = $button.closest(".add_publication");
    $prev_content = $this_content.prev();
    $this_content.hide(function(){
      $prev_content.show();
    });
  });

  $(".find").click(function(){
    function localjsonpcallback(json) {
    };
    var pmid = $(':input.pmid[type=text]').val();
    var europepmcAPI = 'http://www.ebi.ac.uk/europepmc/webservices/rest/search/query=' + pmid + '&format=json&callback=?';

    $.ajax({
      url: europepmcAPI,
      dataType: "jsonp",
      jsonpCallback: 'localjsonpcallback',
      jsonp: 'callback',
    }).done(function(data) {
      var result = data.resultList.result[0];
      var title = result.title;
      // Europ. J. Pediat. 149: 574-576, 1990.
      // journalTitle. journalVolume: pageInfo, pubYear.
      var journalTitle = result.journalTitle;
      var journalVolume = result.journalVolume;
      var pageInfo = result.pageInfo;
      var pubYear = result.pubYear;
      var source = journalTitle + '. ' + journalVolume + ': ' + pageInfo + ', ' + pubYear + '.';

      $(':input.title[type="text"]').val(title);
      $(':input.source[type="text"]').val(source);

    });
  });

  $('#add_publication').submit(function(event){
    var pmid = $(':input.pmid[type="text"]').val();
    var title = $(':input.title[type="text"]').val();
    if ((pmid != '') && (!$.isNumeric(pmid))) {
      event.preventDefault();
      $(".add_publication_feedback").empty();
      $(".add_publication_feedback").append("You need to provide a valid PMID (only numbers e.g. 10094187).");
      $(".add_publication_feedback").removeClass("alert alert-danger").addClass("alert alert-danger");
      return 0;
    } 
    if ((pmid == '') && (title == '') ) { 
      event.preventDefault();
      $(".add_publication_feedback").empty();
      $(".add_publication_feedback").append("You need to provide a valid PMID (only numbers e.g 10094187) or a title.");
      $(".add_publication_feedback").removeClass("alert alert-danger").addClass("alert alert-danger");
      return 0;
    } 
    $(".add_publication_feedback").empty();
    $(".add_publication_feedback").removeClass("alert alert-danger");
    return 1;
  });

});
