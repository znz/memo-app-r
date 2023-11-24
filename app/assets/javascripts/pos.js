/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
$(function() {
  const locupdate = function(pos) {
    const info = document.getElementById("memo_info");
    const lonlat = document.getElementById("memo_lonlat");
    const debug = document.getElementById("debug");
    if (info) {
      info.value =
        "(lat:" + pos.coords.latitude +
        ",lon:" + pos.coords.longitude +
        ",acc:" + pos.coords.accuracy +
        ")";
    }
    if (lonlat) {
      lonlat.value =
        "POINT(" + pos.coords.longitude +
        " " + pos.coords.latitude +
        ")";
    }
    if (debug) {
      return debug.innerHTML =
        "lat : " + pos.coords.latitude +
        "<br/>long : " + pos.coords.longitude +
        "<br/>accuracy : " + pos.coords.accuracy + "<br/>";
    }
  };
  const handleError = function(a) {
    const debug = document.getElementById("debug");
    if (debug) {
      return debug.innerHTML = "<p> error: " + a.code + "</p>";
    }
  };
  let id = null;
  const start = function() {
    if (id) {
      return;
    }
    const new_memo = document.getElementById("new_memo");
    if (new_memo) {
      return id = navigator.geolocation.watchPosition(locupdate, handleError);
    }
  };
  const stop = function() {
    if (!id) {
      return;
    }
    navigator.geolocation.clearWatch(id);
    return id = null;
  };
  $(document).on('turbo:load', start);
  $(document).on('turbo:click', stop);
  return start();
});
