#!/usr/bin/env ruby

require 'rugged'

# function to open and read in file
def read_schema(schema)
  file = File.open(schema, 'r')
  data = file.read
  file.close
  data
end

# function
def ii(i)
  i.positive? ? i : ''
end

repo = Rugged::Repository.new('.')
branches = repo.branches.each_name(:local).sort

tokens = []
branches.each do |branch|
  `git checkout "#{branch}" &> /dev/null`
  Dir.glob('schema/*.xsd').map do |schema|
    data = read_schema(schema)
    data.scan(/<xs:\w+|\w+="\w+"|\w+="xs:\w+"/).uniq do |x|
      tokens << x unless tokens.include? x
    end
    data.scan(/<xs:\w+ \w+="\w+"/).uniq do |x|
      tokens << x unless tokens.include? x
    end
  end
  tokens.sort!
end

# create main data array
structure = []
tokens.map.with_index do |token, i|
  structure[i] = []
  branches.each.with_index do |branch, j|
    `git checkout "#{branch}" &> /dev/null`
    structure[i][j] = [token]
    Dir.glob('schema/*.xsd').map do |schema|
      filename = schema.split('/').last
      data = read_schema(schema)
      structure[i][j] << [filename.split('.').first, data.scan(token).size]
    end
  end
end
# jump back to gh-pages default branch
`git checkout gh-pages &> /dev/null`

# common function that prints the chart title
def chart_title(chart_type, ind, branch)
  "#{ind} - Branch #{branch} count of: #{chart_type} grouped by file"
end

# common function to escape double quotes
def escape(s)
  s.gsub('"', '\"')
end

# common function for each chart
def draw_chart(which_chart, data, chart_string, chart_values,
               chart_title, chart_div, width, height, colors)
  %(
        function drawChart#{which_chart}() {
          // Create the data table.
          var data = new google.visualization.DataTable();
          data.addColumn("string", "#{escape(chart_string)}");
          data.addColumn("number", "#{chart_values}");
          data.addRows(#{data});
          // Set chart options
          var options = {"title": "#{escape(chart_title)}",
                         is3D: true,
                         "pieSliceText": "value",
                         colors: #{colors},
                         "width": #{width},
                         "height": #{height},
                         "titleTextStyle": {"color": "black"}};
          // Instantiate and draw our chart, passing in some options.
          var chart = new google.visualization.PieChart(document.getElementById("chart_div_#{chart_div}"));
          chart.draw(data, options);
        }\n)
end

# build all the website pages
def page_build(page_count)
  (0..page_count).map do |i|
    instance_variable_set("@page#{ii i}",
                          instance_variable_get("@page#{ii i}") + $page)
  end
end

# add navigation hyperlinks
def add_links(page_count)
  page = ''
  (0..page_count).map do |i|
    page += %(
            <li><a href="index#{ii i}.html">Page #{i + 1}</a></li>)
  end
  page
end

# remove special characters as they clash with JavaScript's naming conventions
def clean_chart(chart)
  chart.tr('<"=: ', '')
end
# chart size variables
width = 400
height = 330
# start common page region
$page = %(<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- The above 3 meta tags *must* come first in the head;
         any other head content must come *after* these tags -->
    <title>XML Schema Differencing Dashboard</title>
    <!-- Latest compiled and minified CSS -->
    <link rel="stylesheet" href="bootstrap/css/bootstrap.min.css">
    <!-- Optional theme -->
    <link rel="stylesheet" href="bootstrap/css/bootstrap-theme.min.css">
    <style>
      .container-fluid { padding: 0px; }
      .navbar, .navbar-default { padding: 5pt; background-color: rgba(49,37,152,0.8) !important; font-size: 12pt; }
      .navbar, .navbar-default li a { color: #000 !important; }
      .navbar-default .navbar-brand, .navbar-default .navbar-brand:hover { color: #fff; font-size: 15pt; }
      div[id^="chart_div"] > div > div { margin: auto; }
      footer { background-color: rgba(49,37,152,0.8); min-height: 200px; color: #fff !important; }
      footer ul a { color: #fff !important; }
      .selected { background-color: aliceblue; font-weight: bold; }
      .navbar-default li:hover a { background-color: red !important; }
      .nuchecker a { font-weight: bold; }
      h2 { text-align: center; background-color: rgba(49,37,152,0.8); padding: 14px; color: #fff; }
      .navarrows { clear: both; padding-left: 30pt; }
    </style>
  </head>
  <body>
    <!-- Static navbar -->
    <nav class="navbar navbar-default" id="head1">
      <div class="container-fluid">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle collapsed"
                  data-toggle="collapse" data-target="#navbar"
                  aria-expanded="false" aria-controls="navbar">
            <span class="sr-only">Toggle navigation</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="index.html">
            XML Schema Differencing Dashboard
          </a>
        </div>
        <div id="navbar" class="navbar-collapse collapse">
          <ul class="nav navbar-nav">)

# try 50 chart sections per page
page_count = structure.size / 50
(0..page_count).map do |i|
  instance_variable_set("@page#{ii i}", $page)
end
# restart common page region
$page = add_links(page_count)
# continue to build all the pages
page_build(page_count)
# restart common page region
$page = '
          </ul>
        </div>
      </div>
    </nav>
    <div class="container-fluid">'
# continue to build all the pages
page_build(page_count)

# add chart divs to each page
structure.map.with_index do |token, i|
  k = i
  i /= 50
  # put each chart type in its own row
  instance_variable_set("@page#{ii i}",
                        instance_variable_get("@page#{ii i}") + "
      <h2>#{k + 1}. Branch count of schema by #{token[0][0].delete '<'}</h2>
        <div class=\"row\">")
  token.map.with_index(1) do |chart, j|
    data0 = clean_chart(chart[0]) + j.to_s
    instance_variable_set("@page#{ii i}",
                          instance_variable_get("@page#{ii i}") + "\n          <div class=\"col-sm-6 col-md-4 col-lg-3\" id=\"chart_div_#{data0}\"></div>")
  end
  instance_variable_set("@page#{ii i}",
                        instance_variable_get("@page#{ii i}") + '
          <div class="navarrows">
            <a href="#head1">&#8593;</a>
            <a href="#theend">&#8595;</a>
          </div>
        </div>')
end

# restart common page region
$page = '
    </div>
    <footer>
      <div class="container">
        <ul class="list-unstyled">
          <li>
            <a class="github-button" href="https://github.com/jbampton"
               data-size="large" data-show-count="true"
               aria-label="Follow @jbampton on GitHub">Follow @jbampton</a>
          </li>
          <li>
            <a class="github-button"
               href="https://github.com/jbampton/xml-schema-diff"
               data-icon="octicon-star" data-size="large" data-show-count="true"
               aria-label="Star jbampton/xml-schema-diff on GitHub">Star</a>
          </li>
          <li>
            <a class="github-button"
               href="https://github.com/jbampton/xml-schema-diff/subscription"
               data-icon="octicon-eye" data-size="large" data-show-count="true"
               aria-label="Watch jbampton/xml-schema-diff on GitHub">Watch</a>
          </li>
          <li>
            <a class="github-button"
               href="https://github.com/jbampton/xml-schema-diff/fork"
               data-icon="octicon-repo-forked" data-size="large"
               data-show-count="true"
               aria-label="Fork jbampton/xml-schema-diff on GitHub">Fork</a>
          </li>'
# continue to build all the pages
page_build(page_count)
# restart common page region
$page = add_links(page_count)
# continue to build all the pages
page_build(page_count)
# restart common page region
$page = %(
            <li class="nuchecker">
              <a target="_blank" rel="noopener">Valid HTML</a>
            </li>
            <li><a href="#head1">Back to top</a></li>
        </ul>
        <a href="https://info.flagcounter.com/LJf1"
           target="_blank" rel="noopener">
          <img src="https://s04.flagcounter.com/countxl/LJf1/bg_FFFFFF/txt_000000/border_CCCCCC/columns_2/maxflags_250/viewers_0/labels_1/pageviews_0/flags_1/percent_0/"
               alt="Free counters!">
        </a>
        <a id="theend"></a>
      </div>
    </footer>
    <!--Load the AJAX API-->
    <script src="https://www.gstatic.com/charts/loader.js"></script>
    <script src="https://www.google.com/jsapi"></script>
    <!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
    <script src="bootstrap/js/jquery.min.js"></script>
    <!-- Latest compiled and minified JavaScript -->
    <script src="bootstrap/js/bootstrap.min.js"></script>
    <script>
      // Load the Visualization API and the corechart package.
      google.charts.load("current", {"packages":["corechart"]});\n)
# continue to build all the pages
page_build(page_count)

# colors for the pie chart pieces
schema_colors = { 'bar' => '#E6B0AA',
                  'bookstore' => '#F4D03F',
                  'concept' => '#D7BDE2',
                  'dinner-menu' => '#28B463',
                  'foo' => '#A9CCE3',
                  'note' => '#154360',
                  'note2' => '#A3E4D7',
                  'reference' => '#78281F',
                  'saml20assertion_schema' => '#7D6608',
                  'saml20protocol_schema' => '#E67E22',
                  'task' => '#784212',
                  'topic' => '#34495E',
                  'xenc_schema' => '#17202A',
                  'xmldsig_schema' => '#8E44AD' }

# add all the JavaScript for each pie chart to each page
structure.map.with_index do |token, ind|
  token.map.with_index(1) do |chart, j|
    data0 = clean_chart(chart[0]) + j.to_s
    data1 = chart[1..-1]
    colors = data1.map { |d| schema_colors[d[0]] }
    v = 'Values'
    i = ind / 50
    instance_variable_set("@page#{ii i}",
                          instance_variable_get("@page#{ii i}") + "        google.charts.setOnLoadCallback(drawChart#{data0});\n" + draw_chart(data0, data1, chart[0], v, chart_title(chart[0], ind * 3 + j, branches[j - 1]), data0, width, height, colors))
  end
end

# restart common page region
$page = '
      $(document).ready(function () {
         "use strict";
         var last = $(location).attr("href").split("/").pop().split(".")[0].replace(/index/, "");
         var tab = 1;
         if (last !== "") {
           tab = parseInt(last) + 1;
         }
         $(".navbar-nav li:nth-child(" + tab + ")").addClass("selected");
         tab--;
         if (tab === 0) {
           tab = "";
         }
         $(".nuchecker a").attr("href", "https://validator.w3.org/nu/?doc=http%3A%2F%2Fthebeast.me%2Fxml-schema-diff%2Findex" + tab + ".html");
      });
    </script>
    <script async defer src="https://buttons.github.io/buttons.js"></script>
  </body>
</html>'
# finish building all the pages
page_build(page_count)
# write all the HTML pages to files
(0..page_count).map do |i|
  file = File.open("index#{ii i}.html", 'w')
  file.write(instance_variable_get("@page#{ii i}"))
  file.close
end
