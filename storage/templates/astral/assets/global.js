function initializeCookie() {
  var cookies = document.cookie.split("; ");
  let exist = false;
  for (var i = 0; i < cookies.length; i++) {
    var cookie = cookies[i].split("=");
    if (cookie[0] === "cart_id") {
      exist = true;
      return;
    } 
  }

  if (!exist) {
    var expirationDate = new Date();
    expirationDate.setDate(expirationDate.getDate() + 365);
    let cart_id = generateRandomString(24);
    var cookieString = `cart_id=${cart_id}; expires=${expirationDate.toUTCString()}; path=/`;
    document.cookie = cookieString;
  }

}
initializeCookie();


function generateRandomString(length) {
  var result = [];
  var characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  var charactersLength = characters.length;
  var bytes = new Uint8Array(length);
  window.crypto.getRandomValues(bytes);
  for (var i = 0; i < length; i++) {
    result.push(characters[bytes[i] % charactersLength]);
  }
  return result.join('');
}

// ---------------------------------------------------------------

function fetchConfig(type = 'json') {
  return {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json', Accept: `application/${type}` },
  };
}