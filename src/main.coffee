# =============================================================================
# Set up canvas
# =============================================================================

canvasEl = document.querySelector("#c")
ctx = canvasEl.getContext("2d")

resize = ->
  rect = canvasEl.getBoundingClientRect()
  canvasEl.width = rect.width
  canvasEl.height = rect.height
  render()

init = ->
  window.addEventListener("resize", resize)
  canvasEl.addEventListener("pointerdown", pointerDown)
  canvasEl.addEventListener("pointermove", pointerMove)
  canvasEl.addEventListener("pointerup", pointerUp)
  idleLoop()
  resize()

idleLoop = ->
  idle()
  requestAnimationFrame(idleLoop)

# =============================================================================
# Model
# =============================================================================

class Point
  constructor: (@x, @y) ->
  coordinates: ["x", "y"]

class DistanceConstraint
  constructor: (@p1, @p2, @quadrance) ->
  coordinates: ["p1", "p2"]
  points: -> [@p1, @p2]
  error: ->
    q = math.quadrance(@p1, @p2)
    e = Math.sqrt(q) - Math.sqrt(@quadrance)
    return e*e

class AngleConstraint
  constructor: (@p1, @p2, @angle) ->
  points: -> [@p1, @p2]
  error: ->
    cos = Math.cos(@angle)
    sin = Math.sin(@angle)
    u = (@p2.x - @p1.x)*cos + (@p2.y - @p1.y)*sin
    projectionx = @p1.x + u*cos
    projectiony = @p1.y + u*sin

    q = math.quadrance(@p2, new Point(projectionx, projectiony))
    return q

model = {
  points: []
  constraints: []
}


# =============================================================================
# UI State
# =============================================================================

uistate = {
  movingPoint: null
  lastPoints: []
}


# =============================================================================
# Render
# =============================================================================

clear = ->
  ctx.save()
  ctx.setTransform(1, 0, 0, 1, 0, 0)
  width = ctx.canvas.width
  height = ctx.canvas.height
  ctx.clearRect(0, 0, width, height)
  ctx.restore()

drawPoint = (point, color = "#000") ->
  ctx.beginPath()
  ctx.arc(point.x, point.y, 2.5, 0, Math.PI*2)
  ctx.fillStyle = color
  ctx.fill()

drawLine = (p1, p2, color = "#000") ->
  ctx.beginPath()
  ctx.moveTo(p1.x, p1.y)
  ctx.lineTo(p2.x, p2.y)
  ctx.lineWidth = 1
  ctx.strokeStyle = color
  ctx.stroke()

drawArc = (center, r, a1, a2, color = "#000") ->
  ctx.beginPath()
  ctx.arc(center.x, center.y, r, a1, a2)
  ctx.lineWidth = 1
  ctx.strokeStyle = color
  ctx.stroke()

render = ->
  clear()
  for point in model.points
    if point.fixed
      drawPoint(point, "black")
    else
      drawPoint(point, "grey")
  for constraint in model.constraints
    if constraint instanceof DistanceConstraint
      drawLine(constraint.p1, constraint.p2, "blue")
    if constraint instanceof AngleConstraint
      drawLine(constraint.p1, constraint.p2, "red")


# =============================================================================
# Manipulation
# =============================================================================

findPointNear = (p) ->
  for point in model.points
    if math.quadrance(p, point) < 100
      return point
  return undefined


pointerDown = (e) ->
  p = new Point(e.clientX, e.clientY)

  foundPoint = findPointNear(p)
  if !foundPoint
    model.points.push(p)
    foundPoint = p

  uistate.movingPoint = foundPoint
  if uistate.lastPoints[0] != foundPoint
    uistate.lastPoints.unshift(foundPoint)

  render()

pointerMove = (e) ->
  if uistate.movingPoint
    uistate.movingPoint.x = e.clientX
    uistate.movingPoint.y = e.clientY

    enforceConstraints()

  render()

pointerUp = (e) ->
  if uistate.movingPoint
    uistate.movingPoint = null

  render()


idle = ->
  enforceConstraints()
  render()


key "d", ->
  p1 = uistate.lastPoints[0]
  p2 = uistate.lastPoints[1]

  quadrance = math.quadrance(p1, p2)

  constraint = new DistanceConstraint(p1, p2, quadrance)
  model.constraints.push(constraint)

  render()


key "a", ->
  p1 = uistate.lastPoints[0]
  p2 = uistate.lastPoints[1]

  angle = math.angle(p1, p2)

  constraint = new AngleConstraint(p1, p2, angle)
  model.constraints.push(constraint)

  render()


key "f", ->
  p = uistate.lastPoints[0]
  p.fixed = true


# =============================================================================
# Math
# =============================================================================

math = {}

math.quadrance = (p1, p2) ->
  dx = p2.x - p1.x
  dy = p2.y - p1.y
  return dx*dx + dy*dy

math.angle = (p1, p2) ->
  dx = p2.x - p1.x
  dy = p2.y - p1.y
  return Math.atan2(dy, dx)

math.normalize = (p) ->
  d = Math.sqrt(p.x*p.x + p.y*p.y)
  return new Point(p.x / d, p.y / d)

# =============================================================================
# Constraints
# =============================================================================

enforceConstraints = ->
  epsilon = 1e-2

  fixedPoints = []
  for point in model.points
    if point.fixed
      fixedPoints.push(point)

  for iteration in [0...100]

    moves = []

    for constraint in model.constraints
      e = constraint.error()
      if e > epsilon
        relevantPoints = constraint.points()
        relevantPoints = _.difference(relevantPoints, fixedPoints)

        derivatives = gradient(constraint, relevantPoints)
        moves.push({
          points: relevantPoints
          derivatives: derivatives
          error: e
        })

    if moves.length == 0
      # console.log "solved", iteration
      break

    for move in moves
      for point, i in move.points
        derivative = move.derivatives[i]
        d = math.normalize(derivative)
        step = Math.sqrt(move.error) * 0.1
        point.x -= d.x * step
        point.y -= d.y * step



gradient = (constraint, points) ->
  delta = 1e-10

  derivatives = []

  for point in points
    derivative = new Point()
    derivatives.push(derivative)

    for i in point.coordinates
      original = point[i]
      e1 = constraint.error()
      point[i] += delta
      e2 = constraint.error()
      point[i] = original
      derivative[i] = (e2 - e1) / delta

  return derivatives




init()