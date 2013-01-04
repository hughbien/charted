var Metrics = {
  URL: "/metrics/",
  post: function(queryString) {
    var img = new Image();
    img.src = this.URL + "?" + queryString;
  },
  cookie: function() {
    var obj = {};
    var val = document.cookie.match(new RegExp("(?:^|;) *metrics=([^;]*)"));
    if (val) {
      val = this.decode(val[1]).split("&");
      return val;
    }
    return null;
  },
  decode: function(encoded) {
    return decodeURIComponent(encoded.replace("+", "%20"));
  }
};
Metrics.post(
  "path=" + encodeURIComponent(window.location.pathname) +
  "&title=" + encodeURIComponent(document.title));
