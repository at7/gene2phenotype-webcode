$( document ).ready(function() {
  nv.addGraph(function() {
    d3.selectAll('.chart').call(function(div){
      var chart = nv.models.pieChart()
        .x(function(d) { return d.label })
        .y(function(d) { return d.value })
        .showLabels(true)
        .width(600)
        .height(400);

      var data = JSON.parse(div.attr('data'));

  //var data = [{"value":1,"label":"not assigned"},{"value":2,"label":"Nonsense"},{"value":1,"label":"Frameshift"},{"value":6,"label":"Missense/In-frame"}];
  //    var data = [{"label": "One","value" : 50,} ,{"label": "Two","value" : 50,} ,];

      div.select('svg').datum(data)
        .transition().duration(1200)
        .call(chart);
      return chart;
    });
  });
});

