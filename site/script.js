$(function() {
  var features = [
    "a/b tests",
    "conversions",
    "countries",
    "custom events",
    "pages",
    "platforms",
    "referrers",
    "resolutions",
    "total visits",
    "unique visits"
  ];
  var index = 0;
  var letter = 0;
  var direction = 1;
  var el = $("h1 strong");
  var word = "";
  var subword = "";
  var blink = true;
  var pause = 0;

  setInterval(function() {
    word = features[index]
    subword = word.slice(0, letter);
    if (subword == "") {
      el.html("_");
    } else {
      el.html(subword + (blink ? "<span class='blink'>_</span>" : ""));
    }

    if (direction == 1 && subword.length < word.length) {
    } else if (direction == 1 && subword.length == word.length) {
      direction = 0;
    } else if (direction == -1 && subword.length == 0) {
      direction = 1;
      index = (index + 1) % features.length;
    } else if (direction == 0) {
      pause += 1;
      if (pause > 15) {
        pause = 0;
        direction = -1;
      }
    }
    
    letter = letter + (direction * 2);
    blink = !blink;
  }, 200);
});
