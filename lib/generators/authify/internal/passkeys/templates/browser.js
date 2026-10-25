(() => {
  if (window.authifyPasskeysLoaded) return;
  window.authifyPasskeysLoaded = true;
  async function post(url, body) {
    const response = await fetch(url, {
      method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      body: JSON.stringify(body)
    });
    if (!response.ok) throw new Error("Passkey verification failed. Sign in again and retry.");
    return response.status === 201 ? null : response.json();
  }
  document.addEventListener("click", async (event) => {
    const button = event.target.closest("#authify-register-passkey, #authify-sign-in-passkey");
    if (!button) return;
    const status = document.getElementById("authify-passkey-status");
    button.disabled = true;
    try {
      if (!window.PublicKeyCredential?.parseCreationOptionsFromJSON || !PublicKeyCredential.parseRequestOptionsFromJSON) throw new Error("Use a current browser with passkey support.");
      if (button.id === "authify-register-passkey") {
        const options = await post("/passkeys/registration_options", {});
        const credential = await navigator.credentials.create({ publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options) });
        await post("/passkeys", { credential: credential.toJSON(), name: "Passkey" });
        window.location.reload();
      } else {
        const email = document.querySelector('input[name="email"]').value;
        const options = await post("/passkeys/authentication_options", { email });
        const credential = await navigator.credentials.get({ publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options) });
        const result = await post("/passkeys/authenticate", { credential: credential.toJSON() });
        window.location.assign(result.redirect_to);
      }
    } catch (error) {
      if (status) status.textContent = error.message;
    } finally { button.disabled = false; }
  });
})();
