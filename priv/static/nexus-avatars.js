(function () {
  "use strict";

  const React = window.React;
  const NE    = window.NexusExtensions;
  const NET   = window.NexusExtensionTemplates;

  if (!React || !NE) {
    console.warn("[NexusAvatars] NexusExtensions not available.");
    return;
  }

  const { useState, useEffect, useCallback, useRef } = React;
  const e = React.createElement;

  const SLUG = "nexus-avatars";
  const BASE = `/ext/${SLUG}/api`;

  // ---------------------------------------------------------------------------
  // history.pushState patch — required for SPA navigation
  // ---------------------------------------------------------------------------
  (function () {
    const orig = window.history.pushState.bind(window.history);
    function sanitize(o) {
      if (!o || typeof o !== "object") return o;
      if (typeof o === "function") return undefined;
      if (Array.isArray(o)) return o.map(sanitize).filter(v => v !== undefined);
      const r = {};
      for (const k of Object.keys(o)) {
        const v = sanitize(o[k]);
        if (v !== undefined) r[k] = v;
      }
      return r;
    }
    window.history.pushState = function (s, t, u) {
      try { JSON.stringify(s); return orig(s, t, u); }
      catch (_) { return orig(sanitize(s), t, u); }
    };
  })();

  // ---------------------------------------------------------------------------
  // API helpers
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
    { key: "mech",      label: "Mech",      icon: "fa-robot"         },
    { key: "feline",    label: "Orc",       icon: "fa-skull"         },
    { key: "canine",    label: "Zombie",    icon: "fa-skull-crossbones" },
    { key: "inkblot",   label: "Inkblot",   icon: "fa-droplet"       },
    { key: "emblem",    label: "Emblem",    icon: "fa-shield-halved" },
    { key: "snowflake", label: "Snowflake", icon: "fa-snowflake"     },
  ];

  // ---------------------------------------------------------------------------
  // StylePreviewImg — loads avatar preview from the preview endpoint
  // ---------------------------------------------------------------------------
  function StylePreviewImg({ username, styleKey, size = 72 }) {
    const [src, setSrc] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
      setLoading(true);
      setSrc(null);
      const url = `${BASE}/preview?username=${encodeURIComponent(username)}&style=${styleKey}`;
      // Use an Image object to preload
      const img = new Image();
      img.onload  = () => { setSrc(url); setLoading(false); };
      img.onerror = () => { setLoading(false); };
      img.src = url;
    }, [username, styleKey]);

    if (loading) {
      return e("div", {
        style: {
          width: size, height: size,
          borderRadius: "var(--av-radius)",
          background: "var(--s3)",
          display: "flex", alignItems: "center", justifyContent: "center",
          flexShrink: 0,
        }
      }, e("i", { className: "fa-solid fa-spinner", style: { color: "var(--t5)", fontSize: 14 } }));
    }

    if (!src) {
      return e("div", {
        style: {
          width: size, height: size,
          borderRadius: "var(--av-radius)",
          background: "var(--s3)",
          display: "flex", alignItems: "center", justifyContent: "center",
          flexShrink: 0,
        }
      }, e("i", { className: "fa-solid fa-xmark", style: { color: "var(--t5)", fontSize: 14 } }));
    }

    return e("img", {
      src,
      alt: styleKey,
      style: {
        width: size, height: size,
        borderRadius: "var(--av-radius)",
        objectFit: "cover",
        flexShrink: 0,
        display: "block",
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Profile sidebar widget — style picker (own profile only)
  // ---------------------------------------------------------------------------
  function AvatarStyleWidget({ navigate, currentUser }) {
    // Read the profile username from the current URL path
    // Profile pages are at /profile/:username
    const pathUsername = window.location.pathname.split("/").filter(Boolean)[1] || "";

    // Only show to profile owner
    if (!currentUser || currentUser.username !== pathUsername) return null;

    const [currentStyle, setCurrentStyle] = useState(null);
    const [selected,     setSelected]     = useState(null);
    const [saving,       setSaving]       = useState(false);
    const [saved,        setSaved]        = useState(false);
    const [error,        setError]        = useState(null);

    // Derive current style from avatar_url prefix hint or fetch from stored style
    useEffect(() => {
      // We don't know the stored style from the user object alone —
      // peek at the avatar_url to give a hint, or just show all options
      setCurrentStyle(null);
      setSelected(null);
    }, [currentUser?.username]);

    const save = useCallback(async () => {
      if (!selected || saving) return;
      setSaving(true);
      setSaved(false);
      setError(null);
      try {
        const d = await apiFetch("/style", { method: "POST", body: { style: selected } });
        if (d.data?.avatar_url) {
          setSaved(true);
          setCurrentStyle(selected);
          setTimeout(() => setSaved(false), 2500);
          // Trigger a page reload to show the new avatar everywhere
          setTimeout(() => window.location.reload(), 600);
        } else {
          setError(d.error || "Something went wrong.");
        }
      } catch (err) {
        setError("Network error. Please try again.");
      } finally {
        setSaving(false);
      }
    }, [selected, saving]);

    return e("div", {
      style: {
        background: "var(--s2)",
        border: "0.5px solid var(--b1)",
        borderRadius: "var(--border-radius-lg, 12px)",
        padding: "16px",
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
        style: {
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: 8,
          marginBottom: 12,
        }
      },
        STYLES.map(({ key, label }) => {
          const isSelected = selected === key;
          const isCurrent  = currentStyle === key;
          return e("div", {
            key,
            onClick: () => setSelected(key),
            style: {
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 6,
              padding: 8,
              borderRadius: 10,
              cursor: "pointer",
              background: isSelected ? "var(--ac-bg)" : "var(--s3)",
              border: `1.5px solid ${isSelected ? "var(--ac-border)" : "var(--b1)"}`,
              transition: "all .12s",
              position: "relative",
            }
          },
            // Current badge
            isCurrent && !isSelected && e("div", {
              style: {
                position: "absolute", top: 4, right: 4,
                width: 8, height: 8, borderRadius: "50%",
                background: "var(--green)",
              }
            }),
            // Selected checkmark
            isSelected && e("div", {
              style: {
                position: "absolute", top: 4, right: 4,
                width: 16, height: 16, borderRadius: "50%",
                background: "var(--ac)",
                display: "flex", alignItems: "center", justifyContent: "center",
              }
            }, e("i", { className: "fa-solid fa-check", style: { fontSize: 8, color: "var(--ac-on)" } })),
            // Preview image
            e(StylePreviewImg, {
              username: currentUser.username,
              styleKey: key,
              size: 56,
            }),
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
        style: {
          width: "100%",
          fontSize: 13,
          padding: "8px 0",
          opacity: (!selected || saving) ? 0.5 : 1,
        }
      }, saving ? "Saving…" : saved ? "✓ Saved!" : "Save Style"),

      // Error
      error && e("div", { style: { fontSize: 12, color: "var(--red)", marginTop: 8 } }, error),

      // Hint
      !selected && e("div", {
        style: { fontSize: 11, color: "var(--t5)", marginTop: 8, textAlign: "center" }
      }, "Select a style above to change your avatar")
    );
  }

  // ---------------------------------------------------------------------------
  // Admin panel — custom tab shell (Styles + Maintenance)
  // ---------------------------------------------------------------------------
  function AdminPanel() {
    const [activeTab, setActiveTab] = useState("styles");

    const tabs = [
      { key: "styles",      label: "Styles",      icon: "fa-masks-theater" },
      { key: "maintenance", label: "Maintenance",  icon: "fa-wrench" },
    ];

    return e("div", null,
      // Tab bar
      e("div", {
        style: {
          display: "flex",
          gap: 2,
          borderBottom: "1px solid var(--b1)",
          marginBottom: 24,
        }
      },
        tabs.map(tab =>
          e("button", {
            key: tab.key,
            onClick: () => setActiveTab(tab.key),
            style: {
              display: "flex",
              alignItems: "center",
              gap: 7,
              padding: "10px 16px",
              background: "none",
              border: "none",
              borderBottom: activeTab === tab.key ? "2px solid var(--ac)" : "2px solid transparent",
              marginBottom: -1,
              cursor: "pointer",
              fontSize: 13,
              fontWeight: activeTab === tab.key ? 500 : 400,
              color: activeTab === tab.key ? "var(--t1)" : "var(--t3)",
              borderRadius: 0,
              transition: "color .12s",
            }
          },
            e("i", { className: `fa-solid ${tab.icon}`, style: { fontSize: 13 } }),
            tab.label
          )
        )
      ),

      // Active tab content
      activeTab === "styles"      ? e(StylesTab)      : null,
      activeTab === "maintenance" ? e(MaintenanceTab) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Styles Tab — 7 selectable cards (Random + 6 styles)
  // ---------------------------------------------------------------------------
  function StylesTab() {
    const [settings,  setSettings]  = useState(null);
    const [loading,   setLoading]   = useState(true);
    const [saving,    setSaving]    = useState(false);
    const [error,     setError]     = useState(null);

    // Local state — what's currently selected
    const [enabledStyles, setEnabledStyles] = useState([]);
    const [randomOn,      setRandomOn]      = useState(true);
    const [dirty,         setDirty]         = useState(false);

    // Load current settings
    useEffect(() => {
      fetch(`/api/v1/admin/extensions/${SLUG}`, {
        headers: { "Authorization": `Bearer ${localStorage.getItem("nexus_token")}` }
      })
        .then(r => r.json())
        .then(d => {
          const s = d.extension?.settings || {};
          const raw = (s.enabled_styles || "mech,feline,canine,inkblot,emblem,snowflake")
            .split(",").map(x => x.trim()).filter(Boolean);
          setEnabledStyles(raw);
          setRandomOn(s.random !== false);
          setSettings(s);
          setLoading(false);
        })
        .catch(() => setLoading(false));
    }, []);

    // Wire save to top bar
    useEffect(() => {
      const fn = async () => {
        setSaving(true);
        setError(null);
        try {
          const payload = {
            enabled_styles: enabledStyles.join(","),
            random: randomOn,
          };
          const r = await fetch(`/api/v1/admin/extensions/${SLUG}/settings`, {
            method: "PATCH",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${localStorage.getItem("nexus_token")}`,
            },
            body: JSON.stringify({ settings: payload }),
          });
          const d = await r.json();
          if (d.error) throw new Error(d.error);
          setDirty(false);
        } catch (err) {
          setError(err.message || "Save failed.");
        } finally {
          setSaving(false);
        }
      };
      window._nexusAdminSaveFn = fn;
      return () => {
        if (window._nexusAdminSaveFn === fn) window._nexusAdminSaveFn = null;
      };
    }, [enabledStyles, randomOn]);

    const markDirty = () => {
      if (!dirty) {
        setDirty(true);
        if (window._nexusAdminSetDirty) window._nexusAdminSetDirty();
      }
    };

    const toggleStyle = (key) => {
      setEnabledStyles(prev => {
        const next = prev.includes(key) ? prev.filter(k => k !== key) : [...prev, key];
        return next;
      });
      markDirty();
    };

    const toggleRandom = () => {
      setRandomOn(prev => !prev);
      markDirty();
    };

    if (loading) {
      return e("div", { style: { padding: 24, color: "var(--t4)", fontSize: 13 } }, "Loading…");
    }

    return e("div", { style: { padding: "0 4px" } },
      // Description
      e("div", { style: { fontSize: 13, color: "var(--t3)", marginBottom: 20, lineHeight: 1.6 } },
        "Choose which avatar styles are available. Users will be assigned from the enabled styles. ",
        "If no styles are selected, Nexus default initials avatars are shown."
      ),

      // RANDOM card — full width, sits above the grid
      e("div", {
        onClick: toggleRandom,
        style: {
          display: "flex",
          alignItems: "center",
          gap: 14,
          padding: "14px 16px",
          borderRadius: 10,
          cursor: "pointer",
          marginBottom: 16,
          background: randomOn ? "var(--ac-bg)" : "var(--s2)",
          border: `1.5px solid ${randomOn ? "var(--ac-border)" : "var(--b1)"}`,
          transition: "all .12s",
        }
      },
        e("div", {
          style: {
            width: 44, height: 44,
            borderRadius: 10,
            background: randomOn ? "var(--ac)" : "var(--s3)",
            display: "flex", alignItems: "center", justifyContent: "center",
            flexShrink: 0,
            transition: "background .12s",
          }
        },
          e("i", {
            className: "fa-solid fa-shuffle",
            style: { fontSize: 18, color: randomOn ? "var(--ac-on)" : "var(--t4)" }
          })
        ),
        e("div", { style: { flex: 1 } },
          e("div", { style: { fontSize: 14, fontWeight: 500, color: randomOn ? "var(--ac-text)" : "var(--t1)" } },
            "Random"
          ),
          e("div", { style: { fontSize: 12, color: "var(--t4)", marginTop: 2 } },
            "Randomly assign from enabled styles. Deselect for deterministic hash-based assignment."
          )
        ),
        randomOn && e("i", { className: "fa-solid fa-check", style: { fontSize: 14, color: "var(--ac)" } })
      ),

      // Style cards grid — 3 columns
      e("div", {
        style: {
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: 10,
          marginBottom: 16,
        }
      },
        STYLES.map(({ key, label, icon }) => {
          const on = enabledStyles.includes(key);
          return e("div", {
            key,
            onClick: () => toggleStyle(key),
            style: {
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 10,
              padding: "14px 10px",
              borderRadius: 10,
              cursor: "pointer",
              background: on ? "var(--ac-bg)" : "var(--s2)",
              border: `1.5px solid ${on ? "var(--ac-border)" : "var(--b1)"}`,
              transition: "all .12s",
              position: "relative",
            }
          },
            // Checkmark badge
            on && e("div", {
              style: {
                position: "absolute", top: 8, right: 8,
                width: 20, height: 20, borderRadius: "50%",
                background: "var(--ac)",
                display: "flex", alignItems: "center", justifyContent: "center",
              }
            }, e("i", { className: "fa-solid fa-check", style: { fontSize: 10, color: "var(--ac-on)" } })),

            // Preview — uses style name as seed for consistent admin preview
            e(StylePreviewImg, { username: key, styleKey: key, size: 80 }),

            e("div", {
              style: {
                fontSize: 13,
                fontWeight: 500,
                color: on ? "var(--ac-text)" : "var(--t2)",
              }
            }, label)
          );
        })
      ),

      // Empty state warning
      enabledStyles.length === 0 && e("div", {
        style: {
          fontSize: 12,
          color: "var(--amber)",
          padding: "10px 14px",
          borderRadius: 8,
          background: "rgba(251,191,36,0.08)",
          border: "0.5px solid rgba(251,191,36,0.25)",
        }
      },
        e("i", { className: "fa-solid fa-triangle-exclamation", style: { marginRight: 6 } }),
        "No styles selected — users will see Nexus default initials avatars."
      ),

      error && e("div", { style: { fontSize: 12, color: "var(--red)", marginTop: 8 } }, error)
    );
  }

  // ---------------------------------------------------------------------------
  // Maintenance Tab — Generate button + Flush button
  // ---------------------------------------------------------------------------
  function MaintenanceTab() {
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
          setMessage({ type: "success", text: d.data.message });
          loadStats();
        } else {
          setMessage({ type: "error", text: d.error || "Failed to queue job." });
        }
      } catch {
        setMessage({ type: "error", text: "Network error." });
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
            type: "success",
            text: `Flushed ${d.data.users_cleared} user record(s) and deleted ${d.data.files_deleted} file(s).`
          });
          loadStats();
        } else {
          setMessage({ type: "error", text: d.error || "Flush failed." });
        }
      } catch {
        setMessage({ type: "error", text: "Network error." });
      } finally {
        setFlushing(false);
      }
    };

    const noAvatar  = stats?.users_without_avatar ?? "—";
    const generated = stats?.generated_avatars    ?? "—";

    return e("div", { style: { padding: "0 4px" } },

      // Stats row
      e("div", {
        style: {
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 12,
          marginBottom: 24,
        }
      },
        StatCard("fa-image-portrait", "Generated avatars", generated, "var(--ac)"),
        StatCard("fa-circle-question", "Without avatar",  noAvatar,  "var(--t4)")
      ),

      // Generate section
      e("div", {
        style: {
          background: "var(--s2)",
          border: "0.5px solid var(--b1)",
          borderRadius: 12,
          padding: "16px 18px",
          marginBottom: 14,
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
          style: { fontSize: 13, padding: "8px 20px" }
        }, generating ? "Queuing…" : `Generate for ${noAvatar === "—" ? "…" : noAvatar} users`)
      ),

      // Flush section
      e("div", {
        style: {
          background: "var(--s2)",
          border: "0.5px solid var(--b1)",
          borderRadius: 12,
          padding: "16px 18px",
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
          style: {
            fontSize: 13, padding: "8px 20px",
            background: "transparent",
            border: "0.5px solid var(--red)",
            color: "var(--red)",
            borderRadius: 8,
            cursor: generated === 0 ? "not-allowed" : "pointer",
            opacity: generated === 0 ? 0.5 : 1,
          },
          onClick: flush,
          disabled: flushing || generated === 0,
        }, flushing ? "Flushing…" : "Flush Avatars")
      ),

      // Feedback message
      message && e("div", {
        style: {
          marginTop: 14,
          fontSize: 12,
          padding: "10px 14px",
          borderRadius: 8,
          color: message.type === "success" ? "var(--green)" : "var(--red)",
          background: message.type === "success" ? "rgba(52,211,153,0.08)" : "rgba(248,113,113,0.08)",
          border: `0.5px solid ${message.type === "success" ? "rgba(52,211,153,0.25)" : "rgba(248,113,113,0.25)"}`,
        }
      }, message.text)
    );
  }

  function StatCard(icon, label, value, color) {
    return e("div", {
      key: label,
      style: {
        background: "var(--s2)",
        border: "0.5px solid var(--b1)",
        borderRadius: 10,
        padding: "14px 16px",
        display: "flex",
        flexDirection: "column",
        gap: 6,
      }
    },
      e("div", { style: { fontSize: 11, color: "var(--t5)", textTransform: "uppercase", letterSpacing: ".06em" } },
        label
      ),
      e("div", { style: { fontSize: 22, fontWeight: 500, color } }, value)
    );
  }

  // ---------------------------------------------------------------------------
  // Lazy generation — generate avatar for logged-in user if they have none
  // Fires once on bundle load, silently no-ops if they already have an avatar
  // ---------------------------------------------------------------------------
  (function lazyGenerateForCurrentUser() {
    const token = localStorage.getItem("nexus_token");
    if (!token) return;

    // Check if the current user has an avatar — peek at the /auth/me response
    // already cached in the page, or use NexusExtensions.currentUser if exposed
    const cu = window.__nexusCurrentUser;
    if (cu && cu.avatar_url) return; // already has one

    // Fire and forget — generate silently
    fetch(`${BASE}/generate`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`,
      },
    })
      .then(r => r.json())
      .then(d => {
        if (d.data?.generated && d.data?.avatar_url) {
          // Avatar was just generated — soft reload to show it
          // Small delay to ensure the file is written
          setTimeout(() => window.location.reload(), 800);
        }
      })
      .catch(() => {});
  })();

  // ---------------------------------------------------------------------------
  // Register profile sidebar widget
  // ---------------------------------------------------------------------------
  NE.registerRightWidget({
    id:        "nexus-avatars-style-picker",
    label:     "Avatar Style",
    component: AvatarStyleWidget,
    priority:  60,
    pages:     ["profile"],
  });

  // ---------------------------------------------------------------------------
  // Register admin panel
  // ---------------------------------------------------------------------------
  NE.registerAdminPanel(SLUG, {
    label:     "Nexus Avatars",
    icon:      "fa-masks-theater",
    component: AdminPanel,
  });

})();
