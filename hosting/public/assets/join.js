'use strict';

// /join/<token> -> notely://join/<token>. The token is opaque; only the app
// can use it (it must be signed in, and the owner approves or the link is open).
(function () {
  var match = location.pathname.match(/^\/join\/([A-Za-z0-9]+)\/?$/);
  var open = document.getElementById('open');
  if (!match) {
    open.hidden = true;
    document.querySelector('h1').textContent = "This link isn't complete";
    return;
  }
  open.href = 'notely://join/' + match[1];
})();
