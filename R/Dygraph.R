#' dygraphs Plot
#' 
#' ...
#' 
#' @param data data.frame
#' @param x optional character string identifying column in the data for x-axis (TODO: support for vector)
#' If not supplied, attempt is made to detect it from timeBased data columns or rownames
#' @param y optional character string identifying column in the data for y-axis series (TODO: support for vector)
#' @param y2 (not yet supported) optional character string identifying column in the data for secondary y-axis series (TODO: support for vector)
#' @param sync logical default FALSE. Set to TRUE and dygraph will react to highlights and redraws 
#' in other dygraphs on the same page. (TODO: supply vector of chartIds to sync this chart with)
#' @param ... further options passed to the dygraph options slot. See http://dygraphs.com/options.html
#' @params defaults logical. Should some dygraph options defaults be preloaded? Default is TRUE. 
#' Options supplied via ... will still override these defaults.
dgPlot <- dyPlot <- dygraph <- dygraphPlot<- function(data, x, y, y2, sync=FALSE, defaults=TRUE, ...){
  
  myChart <- Dygraph$new()
  myChart$parseData(data, x, y, y2)
  if(defaults)
    myChart$setDefaults(...)
  myChart$setOpts(...) # dygraph javascript options
  myChart$setLib( "." )
  myChart$templates$script = "layouts/chart2.html"
  myChart$setTemplate(afterScript = "<script></script>")
  if(sync)
    myChart$synchronize()
  
  return(myChart$copy())
}

Dygraph <- setRefClass('Dygraph', contains = 'rCharts'
                       , methods = list(
  initialize = function(){
    callSuper()
    params <<- c(params, list(options = list(width=params$width, height=params$height)))
  },
  parseData = function(data, x, y, y2){
    if(missing(x)) #TODO: detect using xts:::timeBased
      x <- names(data)[1]
    if(missing(y))
      y = setdiff(names(data), x)
    data[[x]] <- paste0("#!new Date(", as.numeric(as.POSIXct(data[[x]])) * 1000, ")!#")
    data <- data[,c(x, y)]
    params <<- modifyList(params, getLayer(x=x, data=data, y=y))
    setOpts(labels=c(x, y)) # because lodash drops column names
  },
  setDefaults = function(...){
    args = list(...)
    safe <- function(x) if (length(x)) x else FALSE
    
    # make floating legend more readable by default
    if(safe(args$legendFollow))
      setOpts(labelsDivStyles=list(
        pointerEvents='none', # let mouse events fall through the legend div
        # borderRadius='10px',
        # boxShadow='4px 4px 4px #888',
        # background='none',
        backgroundColor='rgba(255, 255, 255, 0.5)'
      ))
  },
  setOpts = function(...){
    opts <- list(...)
    fix_dygraph_options <- function(x) {
      # dygraph colors parameter accepts JSON array only, no character string
      if(length(x$colors))
        x$colors <- as.list(x$colors)
      return(x)
    }
  
    params$options <<- modifyList(params$options, fix_dygraph_options(opts))
  },
  synchronize = function(){
    setOpts(
      highlightCallback = "#!
        function(e, x, pts, row) {
          for (var j = 0; j < gs.length; j++) {
            gs[j].setSelection(row);
          }
        }!#",
      unhighlightCallback = "#!
        function(e, x, pts, row) {
          for (var j = 0; j < gs.length; j++) {
            gs[j].clearSelection();
          };
        }!#",
      drawCallback = "#!
        function(me, initial) {
          if (blockRedraw || initial) return;
          blockRedraw = true;
          var range = me.xAxisRange();
          var yrange = me.yAxisRange();
          for (var j = 0; j < gs.length; j++) {
            if (gs[j] == me) continue;
            gs[j].updateOptions( {
              dateWindow: range
              // valueRange: yrange // we don't want to sync along y-axis
            } );
          }
          blockRedraw = false;
        }!#"
      )
  })
)

#' Display multiple dygraphs
#' 
#' ...
#' 
#' @param ... list of dygraph objects to display
layout_dygraphs <- function(...) {
  showCharts <- list(...)
  outfile <- file.path(tempdir(),"tmp.Rmd")
  brew("layouts/multi.Rmd", outfile)
  browseURL(knit2html(outfile, outfile))
}