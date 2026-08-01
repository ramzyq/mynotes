// Notely — Variant B: "Warm Index"
// Denser list with colored left-edge accent + inline tag dots.
// FAB: bottom composer bar with quick-action mic. Leans toward info density.

function VariantWarmIndex({ theme, tweaks, onOpenAccount, onOpenNote, onOpenCompose }) {
  const [query, setQuery] = React.useState('');
  const [filter, setFilter] = React.useState('All');
  const [notes, setNotes] = React.useState(() => window.NOTELY_NOTES.map(n => ({ ...n, archived: false })));

  const togglePin = (id) => setNotes(ns => ns.map(n => n.id === id ? { ...n, pinned: !n.pinned } : n));

  const visible = React.useMemo(() => {
    let list = notes.filter(n => !n.archived);
    if (query.trim()) {
      const q = query.toLowerCase();
      list = list.filter(n => n.title.toLowerCase().includes(q) || n.preview.toLowerCase().includes(q));
    }
    if (filter === 'Pinned') list = list.filter(n => n.pinned);
    return list;
  }, [notes, query, filter]);
  const pinned = visible.filter(n => n.pinned);
  const rest   = visible.filter(n => !n.pinned);

  return (
    <div style={{
      minHeight: '100%', background: theme.bg, fontFamily: FONT_STACK,
      color: theme.text, position: 'relative', paddingBottom: 140,
    }}>
      {/* Header */}
      <div style={{ padding: '66px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 22,
        }}>
          <div>
            <div style={{ fontSize: 12, color: theme.text3, letterSpacing: 0.3, fontWeight: 500, textTransform: 'uppercase' }}>
              Wednesday · April 17
            </div>
            <div style={{
              fontSize: 26, fontWeight: 700, letterSpacing: -0.7, color: theme.text,
              marginTop: 2,
            }}>Good afternoon, Maya</div>
          </div>
          <button onClick={onOpenAccount} style={{ all: 'unset', cursor: 'pointer', padding: 2 }}>
            <Avatar size={36} initial="M" theme={theme} ring />
          </button>
        </div>

        {/* Search */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          background: theme.surface2, borderRadius: 14, padding: '11px 14px',
        }}>
          <IconSearch size={18} stroke={theme.text3}/>
          <input
            value={query} onChange={(e) => setQuery(e.target.value)}
            placeholder="Search 47 notes"
            style={{ all: 'unset', flex: 1, fontSize: 15, color: theme.text }}/>
          <button style={{ all: 'unset', cursor: 'pointer', color: theme.text3 }}>
            <IconMic size={18}/>
          </button>
        </div>

        {/* Filter chips */}
        <div style={{ marginTop: 14, display: 'flex', gap: 6, overflowX: 'auto' }}>
          {[
            { k: 'All', icon: null },
            { k: 'Pinned', icon: <IconPinFilled size={11}/> },
            { k: 'Recent', icon: null },
            { k: 'Shared', icon: null },
          ].map(({ k, icon }) => (
            <button key={k} onClick={() => setFilter(k)} style={{
              all: 'unset', cursor: 'pointer',
              fontSize: 13, fontWeight: 500, letterSpacing: -0.1,
              padding: '6px 12px', borderRadius: 999,
              color: filter === k ? theme.text : theme.text2,
              background: filter === k ? theme.surface : 'transparent',
              border: `1px solid ${filter === k ? theme.borderStrong : theme.border}`,
              display: 'inline-flex', alignItems: 'center', gap: 5,
            }}>
              {icon}{k}
            </button>
          ))}
        </div>
      </div>

      {/* Pinned — carousel of accent cards */}
      {pinned.length > 0 && (
        <div style={{ marginTop: 22 }}>
          <div style={{
            padding: '0 20px', display: 'flex', alignItems: 'center', gap: 7,
            marginBottom: 10,
          }}>
            <IconPinFilled size={11} stroke={theme.violet}/>
            <div style={{
              fontSize: 11.5, fontWeight: 600, letterSpacing: 0.6,
              color: theme.text3, textTransform: 'uppercase',
            }}>Pinned</div>
          </div>
          <div style={{
            display: 'flex', gap: 12, padding: '0 20px 8px',
            overflowX: 'auto', scrollbarWidth: 'none',
          }}>
            {pinned.map(n => <PinnedCard key={n.id} note={n} theme={theme} onOpen={() => onOpenNote?.(n)} onPin={() => togglePin(n.id)}/>)}
          </div>
        </div>
      )}

      {/* All notes — index rows */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          fontSize: 11.5, fontWeight: 600, letterSpacing: 0.6,
          color: theme.text3, textTransform: 'uppercase', marginBottom: 6,
        }}>Everything</div>

        <div style={{
          background: theme.surface, borderRadius: 18,
          border: `1px solid ${theme.border}`,
          overflow: 'hidden',
        }}>
          {rest.map((n, i) => (
            <IndexRow
              key={n.id} note={n} theme={theme}
              isLast={i === rest.length - 1}
              onOpen={() => onOpenNote?.(n)}
              onPin={() => togglePin(n.id)}/>
          ))}
        </div>
      </div>

      {/* Composer bar FAB */}
      <ComposerBar theme={theme} onOpen={onOpenCompose}/>
    </div>
  );
}

function PinnedCard({ note, theme, onOpen, onPin }) {
  const accent = note.tags[0] || 'Personal';
  return (
    <div onClick={onOpen} style={{
      flexShrink: 0, width: 220,
      background: theme.surface, border: `1px solid ${theme.border}`,
      borderRadius: 16, padding: 14, cursor: 'pointer',
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 3,
        background: theme.tagDot(accent),
      }}/>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        marginBottom: 8,
      }}>
        <TagPill name={accent} theme={theme} small/>
        <button onClick={(e) => { e.stopPropagation(); onPin(); }} style={{
          all: 'unset', cursor: 'pointer', color: theme.violet,
        }}>
          <IconPinFilled size={12}/>
        </button>
      </div>
      <div style={{
        fontSize: 14.5, fontWeight: 600, lineHeight: 1.28,
        letterSpacing: -0.3, color: theme.text, marginBottom: 6,
        display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
      }}>{note.title}</div>
      <div style={{
        fontSize: 12, color: theme.text3, lineHeight: 1.4,
        display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical', overflow: 'hidden',
      }}>{note.preview}</div>
      <div style={{
        marginTop: 10, fontSize: 10.5, color: theme.text4,
        fontVariantNumeric: 'tabular-nums',
      }}>{note.updated}</div>
    </div>
  );
}

function IndexRow({ note, theme, isLast, onOpen, onPin }) {
  const accent = note.tags[0] || 'Personal';
  return (
    <div onClick={onOpen} style={{
      display: 'flex', alignItems: 'flex-start', gap: 12,
      padding: '13px 14px', cursor: 'pointer',
      borderBottom: isLast ? 'none' : `1px solid ${theme.border}`,
      position: 'relative',
    }}>
      {/* colored accent bar */}
      <div style={{
        width: 3, alignSelf: 'stretch', borderRadius: 2,
        background: theme.tagDot(accent), flexShrink: 0,
        marginTop: 3, marginBottom: 3,
      }}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
          <div style={{
            flex: 1, minWidth: 0,
            fontSize: 14.5, fontWeight: 600, letterSpacing: -0.3,
            color: theme.text, lineHeight: 1.3,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          }}>{note.title}</div>
          <div style={{
            fontSize: 11, color: theme.text4, fontVariantNumeric: 'tabular-nums',
            flexShrink: 0, marginTop: 1,
          }}>{note.updated}</div>
        </div>
        <div style={{
          marginTop: 2, fontSize: 12.5, color: theme.text3,
          lineHeight: 1.4, overflow: 'hidden', textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
        }}>{note.preview}</div>
        <div style={{ marginTop: 7, display: 'flex', gap: 10, alignItems: 'center' }}>
          {note.tags.map(t => (
            <TagPill key={t} name={t} theme={theme} small style="dot"/>
          ))}
        </div>
      </div>
    </div>
  );
}

function ComposerBar({ theme, onOpen }) {
  return (
    <div style={{
      position: 'absolute', bottom: 26, left: 14, right: 14,
      background: theme.dark ? 'rgba(25,20,35,0.78)' : 'rgba(255,255,255,0.78)',
      backdropFilter: 'blur(24px) saturate(180%)',
      WebkitBackdropFilter: 'blur(24px) saturate(180%)',
      border: `1px solid ${theme.border}`,
      borderRadius: 22, padding: 6,
      display: 'flex', alignItems: 'center', gap: 6,
      boxShadow: '0 16px 40px rgba(60,30,120,0.14), 0 2px 8px rgba(60,30,120,0.05)',
      zIndex: 30,
    }}>
      <button onClick={onOpen} style={{
        all: 'unset', flex: 1, cursor: 'pointer',
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '10px 14px', borderRadius: 16,
        color: theme.text3, fontSize: 14, letterSpacing: -0.15,
      }}>
        <IconEdit size={17} stroke={theme.violet}/>
        Write a note…
      </button>
      <button style={{
        all: 'unset', cursor: 'pointer',
        width: 40, height: 40, borderRadius: 14,
        background: theme.dark ? 'rgba(255,255,255,0.06)' : 'rgba(28,20,40,0.04)',
        color: theme.text2,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <IconMic size={17}/>
      </button>
      <button onClick={onOpen} style={{
        all: 'unset', cursor: 'pointer',
        width: 44, height: 44, borderRadius: 16,
        background: `linear-gradient(135deg, ${theme.violet}, ${theme.violetDeep})`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#fff',
        boxShadow: '0 4px 10px rgba(124,92,245,0.36), inset 0 1px 0 rgba(255,255,255,0.3)',
      }}>
        <IconPlus size={20} strokeWidth={2.4}/>
      </button>
    </div>
  );
}

Object.assign(window, { VariantWarmIndex, PinnedCard, IndexRow, ComposerBar });
