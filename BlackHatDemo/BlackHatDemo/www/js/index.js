function handleOpenURL(url) {
  if (app.handleOpenURL == undefined) {
    app.toHandle = url;
  } else {
    app.handleOpenURL(url);
  }
}

var app = {
  initialize: function() {
    document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
  },

  onDeviceReady: function() {
    var bh = cordova.plugins.BlackHatDemoPlugin;
    bh.start(function(ign) {
    /*
      var json = `{
    "credits": [
        {
            "txt": "Item 1",
            "amt": 3.147,
            "key": "03cc613b5b05024de57fc3bb5f6e0d262224e369bf7e7aec7a560433c2f6e4976424c3160c06f89896784f4f80a01e16b3fb515dd3ad4727583b8c3345c71eb3",
            "rnd": "ee5f6bf0cfc79ad67fe8b92b1cf68e553525bb2a21f7c89186f8212e3d083ac7a9a8e1258f8f5687516c7b4f44927bb0b9adaa95429e26457b28e8bfdc257438"
        },
        {
            "txt": "This description is just too long it will be cut off, surely.",
            "amt": 250.02,
            "key": "f4d4a0519821c573e26b95cf25d5faede20c76867c57d920ccf83702fff49fcd3ca45c4623e3220062c81e29ca69e9354ddefd24bb42f4210e0eeaa4c317ce8b",
            "rnd": "927b509a30e764aa49e118328b00aa47c392bc2b5a6978e91f8978b0ebd2e29af31a2e4d56bc63f2339d06cc66fdabd1118e1af6f4b40bd85d9ef3c05b1e6eab"
        }
    ]
  }`;
  */

      var busy = false;
      var list = document.getElementById("credits");
      var phantom = document.getElementById("phantom");
      var amtInput = document.getElementById("amt");
      var txtInput = document.getElementById("txt");
      var addButton = document.getElementById("add");

      function checkValid() {
        var amt = amtInput.value;
        if (amt.indexOf(".") == -1) return false;
        var split = amt.split(".");
        if (split.length != 2) return false;
        if (split[1].length > 2) return false;
        amt = parseFloat(amt);
        if (isNaN(amt)) return false;
        if (amt > 99.99) return false;
        var txt = txtInput.value;
        if (txt.length == 0) return false;
        if (txt.length > 32) return false;
        return true;
      }

      function ready() {
        if (checkValid() && !busy) {
          addButton.style.opacity = 1.0;
          return true;
        } else {
          addButton.style.opacity = 0.2;
          return false;
        }
      }
      ready();

      amtInput.addEventListener('input', ready);
      txtInput.addEventListener('input', ready);

      addButton.onclick = function() {
        if (!ready()) return;
        if (busy) return;
        busy = true;
        addButton.style.opacity = 0.2;
        var credit = {amt: parseFloat(amtInput.value), txt: txtInput.value, key: "NA", rnd: "", tok: ""};
        var div = createItem(credit, true);
        div.style.opacity = 0.2;
        list.appendChild(div);
        setTimeout(function() {
          div.style.height = "2.5rem";
          bh.submitCredit(credit).then(function(json) {
            var credit = JSON.parse(json);
            var key = div.querySelector(".key")
            key.innerHTML = credit.key;
            div.style.opacity = 1.0;
            addButton.style.opacity = 1.0;
            busy = false;
          });
        },0);
      }

      /*
      function getCredits() {
        return new Promise(function(resolve, reject) {
          setTimeout(function() {
            resolve(JSON.parse(json));
          },800);
        });
      };
      */

      /*
      function submitCredit(credit) {
        return new Promise(function(resolve, reject) {
          setTimeout(function() {
            credit.key = "ABC";
            resolve(credit);
          },800);
        });
      }
      */

      function toFourStr(amt) {
        amt += 0.005;
        if (amt >= 100) amt = 99.99
        amt = "" + amt;
        var halves = amt.split(".");
        if (halves.length == 1) halves.push("00");
        if (halves[0].length == 1) halves[0] = "0" + halves[0];
        if (halves[1].length == 1) halves[1] = halves[1] + "0";
        return halves[0][0] + halves[0][1] + "." + halves[1][0] + halves[1][1];
      }

      function toggleItem(div) {
        if (busy) return;
        busy = true;
        setTimeout(function() {
          busy = false;
        }, 500);
        var credits = document.getElementsByClassName("credit");
        for (var i = 0; i < credits.length; i++) {
          var credit = credits[i];
          if (credit == div) continue;
          credit.style.height = "2.5rem";
          credit.setAttribute("open","false");
        }
        //var div = document.getElementById(id);
        if (div.getAttribute("open") == "false") {
          var copy = document.createElement("div");
          copy.classList.add("credit");
          copy.innerHTML = div.innerHTML;
          copy.style.removeProperty("height");
          phantom.innerHTML = "";
          phantom.appendChild(copy);
          div.style.height = copy.clientHeight + "px";
          div.setAttribute("open","true");
        } else {
          div.style.height = "2.5rem";
          div.setAttribute("open","false");
        }
      }

      function createItem(credit, collapsed) {
        var div = document.createElement("div");
        div.classList.add("credit");
        //div.setAttribute("id",credit.key);
        div.setAttribute("open","false");
        div.onclick = function() {
          toggleItem(div);
        };
        if (collapsed) {
          div.style.height = "0px";
        } else {
          div.style.height = "2.5rem";
        }
        var info = document.createElement("div");
        info.classList.add("info");
        info.innerText = toFourStr(credit.amt) + " " + credit.txt.substring(0,32);
        var key = document.createElement("div");
        key.classList.add("key");
        key.innerText = credit.key
        div.appendChild(info);
        div.appendChild(key);
        return div;
      }

      bh.getCredits().then(function(json) {
        var credits = JSON.parse(json).credits;
        credits.map(function(credit) {
          var div = createItem(credit, false);
          list.appendChild(div);
        });
      });

      console.log("Ready.");

      app.handleOpenURL = function(url) {
        setTimeout(function() {
          var split = url.split(".");
          if (split.length != 2) return;
          var amt = split[0].substring(split[0].length-3,split[0].length);
          amt += ".";
          amt += split[1].substring(0,4);
          amt = parseFloat(amt);
          var tok = split[0].substring(9,split[0].length-3);
          var txt = decodeURIComponent(split[1].substring(4,split[1].length));
          busy = true;
          addButton.style.opacity = 0.2;
          var credit = {amt: amt, txt: txt, key: "NA", rnd: "", tok: tok};
          var div = createItem(credit, true);
          div.style.opacity = 0.2;
          list.appendChild(div);
          setTimeout(function() {
            div.style.height = "2.5rem";
            bh.submitCredit(credit).then(function(json) {
              var credit = JSON.parse(json);
              var key = div.querySelector(".key")
              key.innerHTML = credit.key;
              div.style.opacity = 1.0;
              addButton.style.opacity = 1.0;
              busy = false;
            });
          },0);
        }, 0);
      };
      if (app.toHandle != undefined) {
        app.handleOpenURL(app.toHandle);
      }

    }, function(msg) {
      console.log("Problem with plugin: " + msg);
    });
  },

};

app.initialize();
