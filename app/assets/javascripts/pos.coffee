$ ->
  locupdate = (pos) ->
    info = document.getElementById("memo_info")
    lonlat = document.getElementById("memo_lonlat")
    debug = document.getElementById("debug")
    if info
      info.value =
        "(lat:" + pos.coords.latitude +
        ",lon:" + pos.coords.longitude +
        ",acc:" + pos.coords.accuracy +
        ")"
    if lonlat
      lonlat.value =
        "POINT(" + pos.coords.longitude +
        " " + pos.coords.latitude +
        ")"
    if debug
      debug.innerHTML =
        "lat : " + pos.coords.latitude +
        "<br/>long : " + pos.coords.longitude +
        "<br/>accuracy : " + pos.coords.accuracy + "<br/>"
  handleError = (a) ->
    debug = document.getElementById("debug")
    if debug
      debug.innerHTML = "<p> error: " + a.code + "</p>"
  id = null
  start = ->
    if id
      return
    new_memo = document.getElementById("new_memo")
    if new_memo
      id = navigator.geolocation.watchPosition(locupdate, handleError)
  stop = ->
    if !id
      return
    navigator.geolocation.clearWatch(id)
    id = null
  $(document).on 'turbolinks:load', start
  $(document).on 'turbolinks:click', stop
  start()
