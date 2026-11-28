(function () {
  const Hooks = {};

  Hooks.ScrollBottom = {
    mounted() {
      this.stick = true;
      this.el.addEventListener("scroll", () => {
        const gap = this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight;
        this.stick = gap < 80;
      });
      this.el.scrollTop = this.el.scrollHeight;
    },
    updated() {
      if (this.stick) this.el.scrollTop = this.el.scrollHeight;
    },
  };

  Hooks.Composer = {
    mounted() {
      this.el.addEventListener("keydown", (e) => {
        if (e.key !== "Enter" || e.shiftKey || e.isComposing) return;
        e.preventDefault();
        const form = this.el.form;
        const steer = (e.metaKey || e.ctrlKey) && form.querySelector('button[value="steer"]');
        const btn = steer || form.querySelector('button[type="submit"]:not([value="steer"]), button:not([type])');
        form.requestSubmit(btn || undefined);
      });
      this.handleEvent("composer:clear", () => {
        if (this.el.id === "composer") {
          this.el.value = "";
          this.el.focus();
        }
      });
    },
  };

  const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content");
  const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
    params: { _csrf_token: csrf },
    hooks: Hooks,
  });
  liveSocket.connect();
  window.liveSocket = liveSocket;
})();
