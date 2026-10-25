(() => {
  function render() {
    if (!window.turnstile) return;
    document.querySelectorAll("[data-authify-turnstile]").forEach((element) => {
      if (element.dataset.rendered) return;
      window.turnstile.render(element, {
        sitekey: element.dataset.sitekey,
        action: element.dataset.action,
        "response-field-name": "authify_challenge_token"
      });
      element.dataset.rendered = "true";
    });
  }
  if (!window.authifyTurnstileReady) {
    window.authifyTurnstileReady = render;
    document.addEventListener("turbo:load", render);
    document.addEventListener("turbo:before-cache", () => {
      document.querySelectorAll("[data-authify-turnstile]").forEach((element) => {
        if (window.turnstile && element.dataset.rendered) window.turnstile.remove(element);
        delete element.dataset.rendered;
      });
    });
  }
  if (window.turnstile) render();
  else if (!document.querySelector("script[data-authify-turnstile-api]")) {
    const script = document.createElement("script");
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=authifyTurnstileReady";
    script.async = true;
    script.dataset.authifyTurnstileApi = "true";
    document.head.appendChild(script);
  }
})();
