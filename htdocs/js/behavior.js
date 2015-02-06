$(document).ready(function(){
  $("#query").autocomplete({
    source: "autocomplete.cgi",
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
});