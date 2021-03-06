React = require 'react'
ReactDOM = require 'react-dom'

generateGraphData = require './generate-graph-data'

SVGPathData = require './svg-path-data'

COLOURS = [
  "#e11d21",
  "#fbca04",
  "#009800",
  "#006b75",
  "#207de5",
  "#0052cc",
  "#5319e7",
  "#f7c6c7",
  "#fad8c7",
  "#fef2c0",
  "#bfe5bf",
  "#c7def8",
  "#bfdadc",
  "#bfd4f2",
  "#d4c5f9",
  "#cccccc",
  "#84b6eb",
  "#e6e6e6",
  "#ffffff",
  "#cc317c"
]

classSet = (classes...) -> classes.filter(Boolean).join(' ')

branchCount = (data) ->
  maxBranch = -1
  i = 0

  while i < data.length
    j = 0

    while j < data[i][2].length
      if maxBranch < data[i][2][j][0] or maxBranch < data[i][2][j][1]
        maxBranch = Math.max.apply(Math, [
          data[i][2][j][0]
          data[i][2][j][1]
        ])
      j++
    i++
  maxBranch + 1

distance = (point1, point2) ->
  xs = 0
  ys = 0
  xs = point2.x - point1.x
  xs = xs * xs
  ys = point2.y - point1.y
  ys = ys * ys
  Math.sqrt xs + ys

CommitsGraphMixin =
  getDefaultProps: ->
    y_step: 40
    x_step: 20
    dotRadius: 10
    lineWidth: 5
    offsetPos_x: 0
    offsetPos_y: 0
    selectedStyle:
      strokeWidth: 2
      strokeColour: '#000'
      fillColour: null
    selected: null
    mirror: false
    unstyled: false
    orientation: 'vertical'
  
  getInitialState: ->
    colours: this.props.colours || COLOURS

  componentWillReceiveProps: ->
    @graphData = null
    @branchCount = null
  
  getColour: (branch) ->
    n = this.state.colours.length
    this.state.colours[branch % n]

  cursorPoint: (e) ->
    svg = ReactDOM.findDOMNode(this)
    svgPoint = svg.createSVGPoint()
    svgPoint.x = e.clientX
    svgPoint.y = e.clientY
    svgPoint.matrixTransform svg.getScreenCTM().inverse()

  handleClick: (e) ->
    cursorLoc = @cursorPoint(e)

    smallestDistance = Infinity
    closestCommit = null
    for commit in @renderedCommitsPositions
      commitDistance = distance(cursorLoc, commit)
      if commitDistance < smallestDistance
        smallestDistance = commitDistance
        closestCommit = commit
        closestCommit.x += @props.offsetPos_x
        closestCommit.y += @props.offsetPos_y

    @props.onClick?(closestCommit)

  getGraphData: ->
    @graphData ||= generateGraphData(@props.commits)

  getBranchCount: ->
    @branchCount ||= branchCount(@getGraphData())

  getWidth: ->
    return @props.width if @props.width?
    @getContentWidth()

  getContentWidth: ->
    if @props.orientation is 'horizontal'
      (@getGraphData().length + 2) * @props.x_step
    else
      (@getBranchCount() + 0.5) * @props.x_step

  getHeight: ->
    return @props.height if @props.height?
    @getContentHeight()

  getContentHeight: ->
    if @props.orientation is 'horizontal'
      (@getBranchCount() + 0.5) * @props.y_step
    else
      (@getGraphData().length + 2) * @props.y_step

  getInvert: ->
    if @props.mirror
      0 - @props.width
    else
      0

  getOffset: ->
    @getWidth() / 2 - @getContentWidth() / 2

  renderRouteNode: (svgPathDataAttribute, branch) ->
    unless @props.unstyled
      colour = @getColour(branch)
      style =
        'stroke': colour
        'strokeWidth': @props.lineWidth
        'fill': 'none'

    classes = "commits-graph-branch-#{branch}"

    React.DOM.path
      d: svgPathDataAttribute
      style: style
      className: classes

  renderRoute: (commit_idx, [from, to, branch]) ->
    {x_step, y_step, orientation} = @props
    offset = @getOffset()
    invert = @getInvert()

    svgPath = new SVGPathData

    if orientation is 'horizontal'
      from_x = (commit_idx + 0.5) * x_step
      from_y = offset + invert + (from + 1) * y_step
      to_x = (commit_idx + 0.5 + 1) * x_step
      to_y = offset + invert + (to + 1) * y_step
    else
      from_x = offset + invert + (from + 1) * x_step
      from_y = (commit_idx + 0.5) * y_step
      to_x = offset + invert + (to + 1) * x_step
      to_y = (commit_idx + 0.5 + 1) * y_step


    svgPath.moveTo(from_x, from_y)
    svgPath.lineTo(to_x, to_y)

    @renderRouteNode(svgPath.toString(), branch)

  renderCommitNode: (x, y, sha, dot_branch) ->
    radius = @props.dotRadius

    unless @props.unstyled
      colour = @getColour(dot_branch)
      if sha is @props.selected
        strokeColour = @props.selectedStyle.strokeColour
        strokeWidth = @props.selectedStyle.strokeWidth
        if @props.selectedStyle.fillColour
          colour = @props.selectedStyle.fillColour
      else
        strokeColour = colour
        strokeWidth = 1
      style =
        'stroke': strokeColour
        'strokeWidth': strokeWidth
        'fill': colour

    selectedClass = 'selected' if @props.selected
    classes = classSet("commits-graph-branch-#{dot_branch}", selectedClass)

    React.DOM.circle
      cx: x
      cy: y
      r: radius
      style: style
      onClick: @handleClick
      'data-sha': sha
      className: classes

  renderCommit: (idx, [sha, dot, routes_data, commit]) ->
    [dot_offset, dot_branch] = dot

    # draw dot
    {x_step, y_step, orientation} = @props
    offset = @getOffset()
    invert = @getInvert()

    if orientation is 'horizontal'
      x = (idx + 0.5) * x_step
      y = offset + invert + (dot_offset + 1) * y_step
    else
      x = offset + invert + (dot_offset + 1) * x_step
      y = (idx + 0.5) * y_step

    commitNode = @renderCommitNode(x, y, sha, dot_branch)
    colour = commitNode.props.style.fill

    routeNodes = for route, index in routes_data
      @renderRoute(idx, route)

    @renderedCommitsPositions.push {x, y, sha, commit, colour}

    [commitNode, routeNodes]

  renderGraph: ->
    # reset lookup table of commit node locations
    @renderedCommitsPositions = []

    allCommitNodes = []
    allRouteNodes = []

    for commit, index in @getGraphData()
      [commitNode, routeNodes] = @renderCommit(index, commit)
      allCommitNodes.push commitNode
      allRouteNodes = allRouteNodes.concat routeNodes

    children = [].concat allRouteNodes, allCommitNodes

    height = @getHeight()
    width = @getWidth()
    unless @props.unstyled
      style = {height, width, cursor: 'pointer', marginLeft: @props.offsetPos_x, marginTop: @props.offsetPos_y}

    svgProps = {height, width, style, children}

    React.DOM.svg
      height: height
      width: width
      style: style
      children: children

module.exports = CommitsGraphMixin
