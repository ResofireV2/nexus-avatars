(function () {
  "use strict";

  const React = window.React;
  const NE    = window.NexusExtensions;

  if (!React || !NE) {
    console.warn("[NexusAvatars] NexusExtensions not available.");
    return;
  }

  const { useState, useEffect, useCallback } = React;
  const e = React.createElement;

  const SLUG = "nexus-avatars";
  const BASE = `/ext/${SLUG}/api`;

  // ---------------------------------------------------------------------------
  // API helper
  // ---------------------------------------------------------------------------
  function apiFetch(path, opts = {}) {
    const token = localStorage.getItem("nexus_token");
    return fetch(BASE + path, {
      headers: {
        "Content-Type":  "application/json",
        "Authorization": token ? `Bearer ${token}` : "",
        ...opts.headers,
      },
      ...opts,
      body: opts.body ? JSON.stringify(opts.body) : undefined,
    }).then(r => r.json());
  }

  // ---------------------------------------------------------------------------
  // Style definitions
  // ---------------------------------------------------------------------------
  const STYLES = [
    { key: "mech",      label: "Mech"      },
    { key: "feline",    label: "Feline"    },
    { key: "canine",    label: "Canine"    },
    { key: "inkblot",   label: "Inkblot"   },
    { key: "emblem",    label: "Emblem"    },
    { key: "snowflake", label: "Snowflake" },
  ];

  // ---------------------------------------------------------------------------
  // StylePreviewImg — loads SVG preview from the preview endpoint
  // ---------------------------------------------------------------------------
  function StylePreviewImg({ username, styleKey, size = 72 }) {
    const [src,     setSrc]     = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
      setLoading(true);
      setSrc(null);
      const url = `${BASE}/preview?username=${encodeURIComponent(username)}&style=${styleKey}`;
      const img = new Image();
      img.onload  = () => { setSrc(url);  setLoading(false); };
      img.onerror = () => { setLoading(false); };
      img.src = url;
    }, [username, styleKey]);

    const box = {
      width: size, height: size,
      borderRadius: "var(--av-radius)",
      background: "var(--s3)",
      display: "flex", alignItems: "center", justifyContent: "center",
      flexShrink: 0,
    };

    if (loading) {
      return e("div", { style: box },
        e("i", { className: "fa-solid fa-spinner", style: { color: "var(--t5)", fontSize: 14 } })
      );
    }

    if (!src) {
      return e("div", { style: box },
        e("i", { className: "fa-solid fa-xmark", style: { color: "var(--t5)", fontSize: 14 } })
      );
    }

    return e("img", {
      src, alt: styleKey,
      style: { width: size, height: size, borderRadius: "var(--av-radius)", objectFit: "cover", flexShrink: 0, display: "block" },
    });
  }

  // ---------------------------------------------------------------------------
  // ProfileSidebarPicker — shown in profile_sidebar slot (own profile only)
  //
  // Props per slot contract: { username, current_user }
  // ---------------------------------------------------------------------------
  function ProfileSidebarPicker({ username, current_user }) {
    // Only render for the profile owner
    if (!current_user || current_user.username !== username) return null;

    const [selected, setSelected] = useState(null);
    const [saving,   setSaving]   = useState(false);
    const [saved,    setSaved]    = useState(false);
    const [error,    setError]    = useState(null);

    const save = useCallback(async () => {
      if (!selected || saving) return;
      setSaving(true);
      setSaved(false);
      setError(null);
      try {
        const d = await apiFetch("/style", { method: "POST", body: { style: selected } });
        if (d.data?.avatar_url) {
          setSaved(true);
          setTimeout(() => setSaved(false), 2500);
          setTimeout(() => window.location.reload(), 600);
        } else {
          setError(d.error || "Something went wrong.");
        }
      } catch {
        setError("Network error. Please try again.");
      } finally {
        setSaving(false);
      }
    }, [selected, saving]);

    return e("div", {
      style: {
        background: "var(--s2)",
        border: "0.5px solid var(--b1)",
        borderRadius: 12,
        padding: 16,
        marginBottom: 12,
      }
    },
      // Header
      e("div", { style: { display: "flex", alignItems: "center", gap: 8, marginBottom: 12 } },
        e("i", { className: "fa-solid fa-masks-theater", style: { fontSize: 13, color: "var(--ac)" } }),
        e("div", { style: { fontSize: 13, fontWeight: 500, color: "var(--t1)" } }, "Avatar Style"),
      ),

      // Style grid — 3 columns
      e("div", {
        style: { display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8, marginBottom: 12 }
      },
        STYLES.map(({ key, label }) => {
          const isSelected = selected === key;
          return e("div", {
            key,
            onClick: () => setSelected(key),
            style: {
              display: "flex", flexDirection: "column", alignItems: "center",
              gap: 6, padding: 8, borderRadius: 10, cursor: "pointer",
              background: isSelected ? "var(--ac-bg)" : "var(--s3)",
              border: `1.5px solid ${isSelected ? "var(--ac-border)" : "var(--b1)"}`,
              transition: "all .12s", position: "relative",
            }
          },
            isSelected && e("div", {
              style: {
                position: "absolute", top: 4, right: 4,
                width: 16, height: 16, borderRadius: "50%",
                background: "var(--ac)",
                display: "flex", alignItems: "center", justifyContent: "center",
              }
            }, e("i", { className: "fa-solid fa-check", style: { fontSize: 8, color: "var(--ac-on)" } })),
            e(StylePreviewImg, { username, styleKey: key, size: 56 }),
            e("div", {
              style: {
                fontSize: 10,
                color: isSelected ? "var(--ac-text)" : "var(--t3)",
                fontWeight: isSelected ? 500 : 400,
              }
            }, label)
          );
        })
      ),

      // Save button
      e("button", {
        className: "btn-primary",
        onClick: save,
        disabled: !selected || saving,
        style: { width: "100%", fontSize: 13, padding: "8px 0", opacity: (!selected || saving) ? 0.5 : 1 },
      }, saving ? "Saving…" : saved ? "✓ Saved!" : "Save Style"),

      error && e("div", { style: { fontSize: 12, color: "var(--red)", marginTop: 8 } }, error),

      !selected && e("div", {
        style: { fontSize: 11, color: "var(--t5)", marginTop: 8, textAlign: "center" }
      }, "Select a style above to change your avatar")
    );
  }

  // ---------------------------------------------------------------------------
  // Admin panel — uses SimpleSettingsPanel for settings, then a Maintenance
  // section below it on the same flat page.
  // ---------------------------------------------------------------------------
  function AvatarAdminPanel() {
    const { SimpleSettingsPanel } = window.NexusExtensionTemplates || {};

    // Maintenance state
    const [stats,      setStats]      = useState(null);
    const [generating, setGenerating] = useState(false);
    const [flushing,   setFlushing]   = useState(false);
    const [message,    setMessage]    = useState(null);

    const loadStats = useCallback(() => {
      apiFetch("/admin/stats")
        .then(d => d.data && setStats(d.data))
        .catch(() => {});
    }, []);

    useEffect(() => { loadStats(); }, []);

    const generate = async () => {
      if (generating) return;
      setGenerating(true);
      setMessage(null);
      try {
        const d = await apiFetch("/admin/bulk-generate", { method: "POST" });
        if (d.data) {
          setMessage({ type: "ok", text: d.data.message });
          loadStats();
        } else {
          setMessage({ type: "err", text: d.error || "Failed to queue job." });
        }
      } catch {
        setMessage({ type: "err", text: "Network error." });
      } finally {
        setGenerating(false);
      }
    };

    const flush = async () => {
      if (flushing) return;
      if (!window.confirm("Delete all generated avatars? Users will revert to Nexus default initials until new avatars are generated.")) return;
      setFlushing(true);
      setMessage(null);
      try {
        const d = await apiFetch("/admin/flush", { method: "POST" });
        if (d.data) {
          setMessage({
            type: "ok",
            text: `Flushed ${d.data.users_cleared} user record(s) and deleted ${d.data.files_deleted} file(s).`,
          });
          loadStats();
        } else {
          setMessage({ type: "err", text: d.error || "Flush failed." });
        }
      } catch {
        setMessage({ type: "err", text: "Network error." });
      } finally {
        setFlushing(false);
      }
    };

    const noAvatar  = stats?.users_without_avatar ?? "—";
    const generated = stats?.generated_avatars    ?? "—";

    return e("div", null,

      // ── Settings ────────────────────────────────────────────────────────────
      SimpleSettingsPanel
        ? e(SimpleSettingsPanel, {
            slug: SLUG,
            fields: [
              {
                key:   "enabled_styles",
                label: "Enabled styles",
                type:  "string",
                hint:  "Comma-separated list of active styles. Valid values: mech, feline, canine, inkblot, emblem, snowflake.",
              },
              {
                key:     "random",
                label:   "Random style assignment",
                type:    "boolean",
                hint:    "When on, new users get a random style from the enabled pool. When off, assignment is deterministic (same user always gets the same style).",
              },
            ],
          })
        : e("div", { style: { color: "var(--red)", fontSize: 13, marginBottom: 24 } },
            "NexusExtensionTemplates not available."
          ),

      // ── Maintenance header ──────────────────────────────────────────────────
      e("div", {
        style: {
          fontSize: 11, fontWeight: 500, color: "var(--t5)",
          textTransform: "uppercase", letterSpacing: ".8px",
          paddingTop: 28, paddingBottom: 12,
          borderTop: "0.5px solid var(--b1)",
          marginTop: 24,
        }
      }, "Maintenance"),

      // Stats row
      e("div", {
        style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 20 }
      },
        StatCard("fa-image-portrait", "Generated avatars", generated, "var(--ac)"),
        StatCard("fa-circle-question", "Without avatar",   noAvatar,  "var(--t4)")
      ),

      // Generate section
      e("div", {
        style: {
          background: "var(--s2)", border: "0.5px solid var(--b1)",
          borderRadius: 12, padding: "16px 18px", marginBottom: 14,
        }
      },
        e("div", { style: { fontSize: 13, fontWeight: 500, color: "var(--t1)", marginBottom: 4 } },
          "Generate for existing users"
        ),
        e("div", { style: { fontSize: 12, color: "var(--t4)", marginBottom: 12, lineHeight: 1.5 } },
          `Generate avatars for all ${noAvatar === "—" ? "" : noAvatar + " "}users who currently have no avatar. `,
          "Runs in the background — this page won't block."
        ),
        e("button", {
          className: "btn-primary",
          onClick: generate,
          disabled: generating || noAvatar === 0,
          style: { fontSize: 13, padding: "8px 20px" },
        }, generating ? "Queuing…" : `Generate for ${noAvatar === "—" ? "…" : noAvatar} users`)
      ),

      // Flush section
      e("div", {
        style: {
          background: "var(--s2)", border: "0.5px solid var(--b1)",
          borderRadius: 12, padding: "16px 18px",
        }
      },
        e("div", { style: { fontSize: 13, fontWeight: 500, color: "var(--t1)", marginBottom: 4 } },
          "Flush generated avatars"
        ),
        e("div", { style: { fontSize: 12, color: "var(--t4)", marginBottom: 12, lineHeight: 1.5 } },
          `Delete all ${generated === "—" ? "" : generated + " "}generated avatars and clear them from user records. `,
          "Users will revert to Nexus default initials. Use Generate above to rebuild."
        ),
        e("button", {
          onClick: flush,
          disabled: flushing || generated === 0,
          style: {
            fontSize: 13, padding: "8px 20px",
            background: "transparent",
            border: "0.5px solid var(--red)",
            color: "var(--red)",
            borderRadius: 8,
            cursor: (flushing || generated === 0) ? "not-allowed" : "pointer",
            opacity: (flushing || generated === 0) ? 0.5 : 1,
          },
        }, flushing ? "Flushing…" : "Flush Avatars")
      ),

      // Feedback message
      message && e("div", {
        style: {
          marginTop: 14, fontSize: 12, padding: "10px 14px", borderRadius: 8,
          color:       message.type === "ok" ? "var(--green)" : "var(--red)",
          background:  message.type === "ok" ? "rgba(52,211,153,0.08)" : "rgba(248,113,113,0.08)",
          border: `0.5px solid ${message.type === "ok" ? "rgba(52,211,153,0.25)" : "rgba(248,113,113,0.25)"}`,
        }
      }, message.text)
    );
  }

  function StatCard(icon, label, value, color) {
    return e("div", {
      key: label,
      style: {
        background: "var(--s2)", border: "0.5px solid var(--b1)",
        borderRadius: 10, padding: "14px 16px",
        display: "flex", flexDirection: "column", gap: 6,
      }
    },
      e("div", { style: { fontSize: 11, color: "var(--t5)", textTransform: "uppercase", letterSpacing: ".06em" } }, label),
      e("div", { style: { fontSize: 22, fontWeight: 500, color } }, value)
    );
  }

  // ---------------------------------------------------------------------------
  // Lazy generation — fire once on load for logged-in users with no avatar
  // ---------------------------------------------------------------------------
  (function lazyGenerateForCurrentUser() {
    const token = localStorage.getItem("nexus_token");
    if (!token) return;
    const cu = window.__nexusCurrentUser;
    if (cu && cu.avatar_url) return;
    fetch(`${BASE}/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` },
    })
      .then(r => r.json())
      .then(d => {
        if (d.data?.generated && d.data?.avatar_url) {
          setTimeout(() => window.location.reload(), 800);
        }
      })
      .catch(() => {});
  })();

  // ---------------------------------------------------------------------------
  // Register profile_sidebar slot component
  // ---------------------------------------------------------------------------
  NE.registerSlot({
    slug:      SLUG,
    slot:      "profile_sidebar",
    component: ProfileSidebarPicker,
    priority:  50,
  });

  // ---------------------------------------------------------------------------
  // Register admin panel
  // ---------------------------------------------------------------------------
  NE.registerAdminPanel(SLUG, {
    label:     "Nexus Avatars",
    icon:      "fa-masks-theater",
    component: AvatarAdminPanel,
  });

})();
