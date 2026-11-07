'use strict';

// Handler for Firebase Auth email action links (the project's "action URL"
// points here instead of Firebase's default page).
//
// - resetPassword: hands the link to the app. The new password must be chosen
//   in Notely, which sends Firebase only a secret derived from it; a password
//   typed on a web page would reach Firebase as typed and could open the
//   encrypted key backup. So this page has no password field, ever.
// - verifyEmail, recoverEmail, verifyAndChangeEmail: apply the one-time code
//   with Firebase's REST API (what the JS SDK's applyActionCode does).
(function () {
  var params = new URLSearchParams(location.search);
  var mode = params.get('mode');
  var code = params.get('oobCode');
  var apiKey = params.get('apiKey');

  function show(id) { document.getElementById(id).hidden = false; }

  if (!code || !mode) { show('unknown'); return; }

  if (mode === 'resetPassword') {
    show('reset');
    document.getElementById('open-reset').href = 'notely://auth/action' + location.search;
    document.getElementById('copy-reset').addEventListener('click', function () {
      var done = function () { document.getElementById('copied').hidden = false; };
      if (navigator.clipboard) navigator.clipboard.writeText(location.href).then(done, done);
    });
    return;
  }

  var copy = {
    verifyEmail: { title: 'Email verified', next: 'Go back to Notely and tap "I\'ve verified my email".' },
    verifyAndChangeEmail: { title: 'Email changed', next: 'Sign in to Notely with your new email.' },
    recoverEmail: { title: 'Email change undone', next: 'Your account email is back to what it was. If you didn\'t ask for the change, reset your password from Notely.' },
  }[mode];
  if (!copy || !apiKey) { show('unknown'); return; }

  show('apply');
  var title = document.getElementById('apply-title');
  var status = document.getElementById('apply-status');
  var next = document.getElementById('apply-next');

  fetch('https://identitytoolkit.googleapis.com/v1/accounts:update?key=' + encodeURIComponent(apiKey), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ oobCode: code }),
  })
    .then(function (response) {
      return response.json().then(function (body) { return { ok: response.ok, body: body }; });
    })
    .then(function (result) {
      if (!result.ok) throw new Error((result.body.error && result.body.error.message) || 'FAILED');
      title.textContent = copy.title;
      status.textContent = 'Done.';
      status.className = 'status ok';
      next.textContent = copy.next;
    })
    .catch(function (error) {
      var expired = /EXPIRED|INVALID_OOB_CODE/.test(String(error.message));
      title.textContent = expired ? 'This link has expired' : "That didn't work";
      status.textContent = expired
        ? 'Links from Notely emails work once and for a limited time.'
        : 'Check your connection and open the link again.';
      status.className = 'status error';
      next.textContent = expired ? 'Request a new email from the app.' : '';
    });
})();
