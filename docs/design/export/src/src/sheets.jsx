// Notely — Account sheet (slides up from bottom)
// + Tweaks panel
// + Compose overlay (minimal, just to show the FAB landing)

function AccountSheet({ open, onClose, theme, onToggleDark }) {
  if (!open) return null;
  return (
    <div onClick={onClose} style={{
      position: 'absolute', inset: 0, zIndex: 90,
      background: 'rgba(15,10,25,0.32)',
      backdropFilter: 'blur(4px)',
      display: 'flex', alignItems: 'flex-end',
      animation: 'fadeIn 180ms ease-out',
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        width: '100%',
        background: theme.surface,
        borderTopLeftRadius: 24, borderTopRightRadius: 24,
        padding: '12px 18px 30px',
        boxShadow: '0 -8px 40px rgba(20,10,40,0.18)',
        animation: 'sheetUp 280ms cubic-bezier(.2,.9,.2,1)',
      }}>
        {/* grabber */}
        <div style={{
          width: 36, height: 4, borderRadius: 3,
          background: theme.border, margin: '0 auto 16px',
        }}/>

        {/* profile */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 14,
          padding: '6px 4px 16px',
          borderBottom: `1px solid ${theme.border}`, marginBottom: 10,
        }}>
          <Avatar size={48} initial="M" theme={theme}/>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 600, letterSpacing: -0.3, color: theme.text }}>
              Maya Ayalon
            </div>
            <div style={{ fontSize: 13, color: theme.text3, marginTop: 1 }}>
              maya.ayalon@gmail.com
            </div>
          </div>
          <div style={{
            padding: '4px 9px', borderRadius: 999,
            background: theme.violetSoft, color: theme.violetInk,
            fontSize: 10.5, fontWeight: 600, letterSpacing: 0.2, textTransform: 'uppercase',
          }}>Pro</div>
        </div>

        {/* sync status */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '10px 12px', background: theme.surface2,
          borderRadius: 12, marginBottom: 14,
        }}>
          <div style={{
            width: 28, height: 28, borderRadius: 8,
            background: 'rgba(16,185,129,0.14)', color: '#059669',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <IconCloud size={15}/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, fontWeight: 500, color: theme.text }}>Synced to Firestore</div>
            <div style={{ fontSize: 11.5, color: theme.text3, marginTop: 1 }}>
              Last sync · just now · 47 notes · 3 devices
            </div>
          </div>
        </div>

        {/* menu */}
        <SheetRow theme={theme} icon={<IconSettings size={17}/>} label="Preferences"/>
        <SheetRow theme={theme} icon={<IconMoon size={17}/>} label="Appearance"
                  detail={theme.dark ? 'Dark' : 'Light'} onClick={onToggleDark}/>
        <SheetRow theme={theme} icon={<IconArchive size={17}/>} label="Archive" detail="12"/>
        <SheetRow theme={theme} icon={<IconSparkle size={17}/>} label="What's new" pro/>
        <SheetRow theme={theme} icon={<IconLogout size={17}/>} label="Sign out" danger/>
      </div>
    </div>
  );
}

function SheetRow({ theme, icon, label, detail, onClick, danger, pro }) {
  return (
    <button onClick={onClick} style={{
      all: 'unset', cursor: 'pointer', width: '100%', boxSizing: 'border-box',
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 6px',
      borderBottom: `1px solid ${theme.border}`,
    }}>
      <div style={{
        width: 28, height: 28, borderRadius: 8,
        background: danger ? 'rgba(220,38,38,0.1)' : theme.violetSoft,
        color: danger ? '#DC2626' : theme.violetInk,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>{icon}</div>
      <div style={{
        flex: 1, fontSize: 14.5, fontWeight: 500, letterSpacing: -0.2,
        color: danger ? '#DC2626' : theme.text,
      }}>{label}</div>
      {pro && <span style={{
        fontSize: 10, fontWeight: 600, letterSpacing: 0.2,
        padding: '2px 6px', borderRadius: 4,
        background: theme.violetSoft, color: theme.violetInk,
      }}>NEW</span>}
      {detail && <span style={{ fontSize: 13, color: theme.text3 }}>{detail}</span>}
      <IconChevron size={14} stroke={theme.text4}/>
    </button>
  );
}

// ──────────────────────────────────────
// Compose bottom-sheet (light preview)
// ──────────────────────────────────────
function ComposeSheet({ open, onClose, theme }) {
  if (!open) return null;
  return (
    <div onClick={onClose} style={{
      position: 'absolute', inset: 0, zIndex: 90,
      background: 'rgba(15,10,25,0.32)',
      animation: 'fadeIn 180ms ease-out',
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: theme.surface, color: theme.text,
        borderTopLeftRadius: 28, borderTopRightRadius: 28,
        padding: '12px 18px 24px',
        height: '78%',
        display: 'flex', flexDirection: 'column',
        animation: 'sheetUp 320ms cubic-bezier(.2,.9,.2,1)',
      }}>
        <div style={{
          width: 36, height: 4, borderRadius: 3,
          background: theme.border, margin: '0 auto 14px',
        }}/>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 14,
        }}>
          <button onClick={onClose} style={{
            all: 'unset', cursor: 'pointer',
            fontSize: 14, color: theme.text2, fontWeight: 500,
          }}>Cancel</button>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 4,
            fontSize: 11.5, color: theme.text3,
          }}>
            <IconCloud size={13}/> Saving…
          </div>
          <button style={{
            all: 'unset', cursor: 'pointer',
            fontSize: 14, fontWeight: 600, color: theme.violet,
          }}>Done</button>
        </div>

        <div style={{
          fontFamily: FONT_DISPLAY, fontSize: 30, lineHeight: 1.1,
          letterSpacing: -0.6, color: theme.text4,
        }}>Title</div>
        <div style={{
          marginTop: 10, fontSize: 15, lineHeight: 1.5,
          color: theme.text4,
        }}>Start writing…</div>

        {/* suggested tags */}
        <div style={{ marginTop: 'auto', display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 11.5, color: theme.text3, fontWeight: 500,
            alignSelf: 'center', marginRight: 4 }}>Suggest:</span>
          {['Projects', 'Dev', 'Ideas'].map(t => (
            <TagPill key={t} name={t} theme={theme} outlined/>
          ))}
        </div>

        {/* formatting strip */}
        <div style={{
          marginTop: 14, display: 'flex', gap: 6, alignItems: 'center',
          padding: '8px 4px', borderTop: `1px solid ${theme.border}`,
        }}>
          {['B', 'I', 'U'].map(c => (
            <button key={c} style={{
              all: 'unset', cursor: 'pointer',
              width: 32, height: 32, borderRadius: 8,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 14, fontWeight: 700, color: theme.text2,
              fontStyle: c === 'I' ? 'italic' : 'normal',
              textDecoration: c === 'U' ? 'underline' : 'none',
            }}>{c}</button>
          ))}
          <div style={{ width: 1, height: 20, background: theme.border, margin: '0 4px' }}/>
          <button style={{
            all: 'unset', cursor: 'pointer',
            width: 32, height: 32, borderRadius: 8, color: theme.text2,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}><IconList size={17}/></button>
          <button style={{
            all: 'unset', cursor: 'pointer',
            width: 32, height: 32, borderRadius: 8, color: theme.text2,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}><IconCheck size={17}/></button>
          <div style={{ flex: 1 }}/>
          <button style={{
            all: 'unset', cursor: 'pointer',
            width: 32, height: 32, borderRadius: 8, color: theme.violet,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}><IconSparkle size={17}/></button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { AccountSheet, ComposeSheet });
