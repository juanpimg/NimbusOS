// Navegación móvil mínima + año. Sin frameworks.
(function () {
  var year = new Date().getFullYear();
  document.querySelectorAll("footer span:first-child").forEach(function (el) {
    el.textContent = "NimbusOS " + year + " · GPL-3.0-or-later";
  });
})();
