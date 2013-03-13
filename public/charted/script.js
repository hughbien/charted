var Charted = {
  URL: "/charted/",
  RECORD_URL: "/charted/record/",
  send: function(url, queryString) {
    var script = document.createElement("script");
    script.type = "text/javascript";
    script.async = true;
    script.src = url + "?" + queryString;
    document.getElementsByTagName("head")[0].appendChild(script);
  },
  cookie: function() {
    var obj = {};
    var val = document.cookie.match(new RegExp("(?:^|;) *charted=([^;]*)"));
    if (val) {
      val = this.decode(val[1]).split("&");
      return val;
    }
    return null;
  },
  decode: function(encoded) {
    return decodeURIComponent(encoded.replace("+", "%20"));
  },
  events: function() {
    var str = [];
    for (var i = 0; i < arguments.length; i++) {
      str.push(arguments[i]);
    }
    this.send(this.RECORD_URL, "events=" + encodeURIComponent(str.join(";")));
  }
};
Charted.send(
  Charted.URL,
  "path=" + encodeURIComponent(window.location.pathname) +
  "&title=" + encodeURIComponent(document.title) +
  "&referrer=" + encodeURIComponent(document.referrer) +
  "&resolution=" + encodeURIComponent(screen.width+"x"+screen.height));
