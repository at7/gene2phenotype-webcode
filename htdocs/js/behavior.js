$(document).ready(function(){
  $("#query").autocomplete({
    source: "autocomplete.cgi",
    minLength: 2,
    select: function(event, ui) {}
  });
  $("#query_gene_name").autocomplete({
    source: "autocomplete_gene_name.cgi",
    minLength: 2,
    select: function(event, ui) {}
  });
  $("#query_disease_name").autocomplete({
    source: "autocomplete_disease_name.cgi",
    minLength: 2,
    select: function(event, ui) {}
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
    $this_content = $button.closest(".gene_disease_attributes");
    $edit_content = $this_content.next();
    $edit_content.show(function(){
      $button_parent.hide();
    });
  });

  $(".discard").click(function(){
    $button = $(this);
    $this_content = $button.closest(".edit_gene_disease");
    $prev_content = $this_content.prev();
    $this_content.hide(function(){
      $prev_content.find('.edit_attributes').show();
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


});
