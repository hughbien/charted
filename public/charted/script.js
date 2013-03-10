var Charted = {
  URL: "/charted/",
  send: function(queryString) {
    var script = document.createElement("script");
    script.type = "text/javascript";
    script.async = true;
    script.src = this.URL + "?" + queryString;
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
  }
};
Charted.send(
  "path=" + encodeURIComponent(window.location.pathname) +
  "&title=" + encodeURIComponent(document.title) +
  "&referrer=" + encodeURIComponent(document.referrer) +
  "&resolution=" + encodeURIComponent(screen.width+"x"+screen.height));
