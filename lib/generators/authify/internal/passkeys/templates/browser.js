(() => {
  if (window.authifyPasskeysLoaded) return;
  window.authifyPasskeysLoaded = true;
  async function post(url, body) {
    const response = await fetch(url, {
      method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      body: JSON.stringify(body)
    });
    const csrf = response.headers.get("X-CSRF-Token");
    if (csrf) document.querySelector('meta[name="csrf-token"]').content = csrf;
    if (!response.ok) throw new Error("Passkey verification failed. Sign in again and retry.");
    return response.status === 201 || response.status === 204 ? null : response.json();
  }
  document.addEventListener("click", async (event) => {
    const button = event.target.closest("#authify-register-passkey, #authify-sign-in-passkey, #authify-confirm-passkey, #authify-confirm-password");
    if (!button) return;
    const status = document.getElementById("authify-passkey-status");
    button.disabled = true;
    try {
      if (!window.PublicKeyCredential?.parseCreationOptionsFromJSON || !PublicKeyCredential.parseRequestOptionsFromJSON) throw new Error("Use a current browser with passkey support.");
      if (button.id === "authify-register-passkey") {
        const options = await post("/passkeys/registration_options", { current_password: document.getElementById("authify-current-password").value, code: document.getElementById("authify-current-code").value });
        const credential = await navigator.credentials.create({ publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options) });
        await post("/passkeys", { credential: credential.toJSON(), name: "Passkey" });
        window.location.reload();
      } else if (button.id === "authify-confirm-password") {
        // Obtaining options verifies the password and rotates the session. A new
        // registration request will replace this unused, expiring challenge.
        await post("/passkeys/registration_options", { current_password: document.getElementById("authify-current-password").value, code: document.getElementById("authify-current-code").value });
        document.getElementById("authify-current-password").value = "";
        document.getElementById("authify-current-code").value = "";
        if (status) status.textContent = "Identity confirmed. You can now manage your passkeys.";
      } else {
        const reauth = button.id === "authify-confirm-passkey";
        const email = document.querySelector('input[name="email"]')?.value;
        const options = await post("/passkeys/authentication_options", { email, purpose: reauth ? "reauthentication" : "authentication" });
        const credential = await navigator.credentials.get({ publicKey: PublicKeyCredential.parseRequestOptionsFromJSON(options) });
        const result = await post("/passkeys/authenticate", { credential: credential.toJSON(), purpose: reauth ? "reauthentication" : "authentication" });
        window.location.assign(result.redirect_to);
      }
    } catch (error) {
      if (status) status.textContent = error.message;
    } finally { button.disabled = false; }
  });
})();
