// Notely — Variant C: "Canvas"
// Masonry grid of staggered cards with colored cover tops.
// Pinned row up top as horizontal ticker of chips.
// FAB: corner-docked orb with soft violet aura.

function VariantCanvas({ theme, tweaks, onOpenAccount, onOpenNote, onOpenCompose }) {
  const [query, setQuery] = React.useState('');
  const [activeTag, setActiveTag] = React.useState(null);
  const [notes, setNotes] = React.useState(() => window.NOTELY_NOTES.map(n => ({ ...n, archived: false })));

  const togglePin = (id) => setNotes(ns => ns.map(n => n.id === id ? { ...n, pinned: !n.pinned } : n));

  const visible = React.useMemo(() => {
    let list = notes.filter(n => !n.archived);
    if (query.trim()) {
      const q = query.toLowerCase();
      list = list.filter(n => n.title.toLowerCase().includes(q) || n.preview.toLowerCase().includes(q));
    }
    if (activeTag) list = list.filter(n => n.tags.includes(activeTag));
    return list;
  }, [notes, query, activeTag]);
  const pinned = visible.filter(n => n.pinned);
  const rest   = visible.filter(n => !n.pinned);

  // Split into 2 masonry columns
  const colA = [], colB = [];
  rest.forEach((n, i) => (i % 2 === 0 ? colA : colB).push(n));

  const allTags = Array.from(new Set(window.NOTELY_NOTES.flatMap(n => n.tags)));

  return (
    <div style={{
      minHeight: '100%', background: theme.bg, fontFamily: FONT_STACK,
      color: theme.text, position: 'relative', paddingBottom: 130,
    }}>
      {/* Header */}
      <div style={{ padding: '66px 18px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 16,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <Wordmark theme={theme} size={18}/>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <button style={{
              all: 'unset', cursor: 'pointer',
              width: 32, height: 32, borderRadius: 999,
              background: theme.surface, border: `1px solid ${theme.border}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: theme.text2,
            }}>
              <IconSort size={16}/>
            </button>
            <button onClick={onOpenAccount} style={{ all: 'unset', cursor: 'pointer' }}>
              <Avatar size={32} initial="M" theme={theme} ring />
            </button>
          </div>
        </div>

        <div style={{
          fontFamily: FONT_DISPLAY, fontSize: 36, lineHeight: 1.02,
          letterSpacing: -1.1, color: theme.text, fontWeight: 400,
          marginBottom: 18,
        }}>
          Your <em style={{ color: theme.violet, fontStyle: 'italic' }}>canvas</em>.
        </div>

        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          background: theme.surface, border: `1px solid ${theme.border}`,
          borderRadius: 14, padding: '10px 12px',
        }}>
          <IconSearch size={18} stroke={theme.text3}/>
          <input value={query} onChange={(e) => setQuery(e.target.value)}
            placeholder="Search your canvas" style={{
              all: 'unset', flex: 1, fontSize: 15, color: theme.text,
            }}/>
        </div>

        {/* Horizontal tag scroll */}
        <div style={{
          marginTop: 14, display: 'flex', gap: 6, overflowX: 'auto',
          scrollbarWidth: 'none', paddingBottom: 2,
        }}>
          <button onClick={() => setActiveTag(null)} style={{
            all: 'unset', cursor: 'pointer',
            fontSize: 12.5, fontWeight: 500,
            padding: '6px 11px', borderRadius: 999,
            color: !activeTag ? '#fff' : theme.text2,
            background: !activeTag ? theme.violet : 'transparent',
            border: !activeTag ? 'none' : `1px solid ${theme.border}`,
            flexShrink: 0,
          }}>All</button>
          {allTags.map(t => {
            const active = activeTag === t;
            return (
              <button key={t} onClick={() => setActiveTag(active ? null : t)} style={{
                all: 'unset', cursor: 'pointer', flexShrink: 0,
                fontSize: 12.5, fontWeight: 500, letterSpacing: -0.1,
                padding: '6px 10px', borderRadius: 999,
                color: active ? theme.tagFg(t) : theme.text2,
                background: active ? theme.tagBg(t) : 'transparent',
                border: `1px solid ${active ? 'transparent' : theme.border}`,
                display: 'inline-flex', alignItems: 'center', gap: 5,
              }}>
                <span style={{
                  width: 6, height: 6, borderRadius: 3, background: theme.tagDot(t),
                }}/>{t}
              </button>
            );
          })}
        </div>
      </div>

      {/* Pinned */}
      {pinned.length > 0 && (
        <div style={{ marginTop: 18, padding: '0 18px' }}>
          <SectionHeader theme={theme} label="Pinned" count={pinned.length}
                         icon={<IconPinFilled size={11} stroke={theme.violet}/>}/>
          <div style={{ display: 'flex', gap: 10, overflowX: 'auto', scrollbarWidth: 'none', paddingBottom: 4 }}>
            {pinned.map(n => <CoverCard key={n.id} note={n} theme={theme}
              onOpen={() => onOpenNote?.(n)} onPin={() => togglePin(n.id)} wide/>)}
          </div>
        </div>
      )}

      {/* Masonry grid */}
      <div style={{
        padding: '18px 18px 0', display: 'grid',
        gridTemplateColumns: '1fr 1fr', gap: 10,
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {colA.map(n => <CoverCard key={n.id} note={n} theme={theme}
            onOpen={() => onOpenNote?.(n)} onPin={() => togglePin(n.id)}/>)}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {colB.map(n => <CoverCard key={n.id} note={n} theme={theme}
            onOpen={() => onOpenNote?.(n)} onPin={() => togglePin(n.id)}/>)}
        </div>
      </div>

      {/* Orb FAB */}
      <button onClick={onOpenCompose} style={{
        all: 'unset', position: 'absolute', bottom: 34, right: 20,
        width: 58, height: 58, borderRadius: 29, cursor: 'pointer',
        background: `radial-gradient(circle at 30% 25%, #D7C6FF, ${theme.violetDeep} 75%)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#fff',
        boxShadow: '0 0 0 8px rgba(167,139,250,0.14), 0 14px 34px rgba(124,92,245,0.45), inset 0 2px 0 rgba(255,255,255,0.35)',
        zIndex: 30,
      }}>
        <IconPlus size={24} strokeWidth={2.4}/>
      </button>
    </div>
  );
}

function CoverCard({ note, theme, onOpen, onPin, wide }) {
  // pick a height for masonry variation
  const heights = [132, 160, 144, 180, 150];
  const h = wide ? 140 : heights[note.id.charCodeAt(2) % heights.length];
  const accent = note.tags[0] || 'Personal';
  const coverBg = theme.tagBg(accent);

  return (
    <div onClick={onOpen} style={{
      width: wide ? 200 : '100%', flexShrink: 0,
      background: theme.surface, border: `1px solid ${theme.border}`,
      borderRadius: 16, overflow: 'hidden', cursor: 'pointer',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Colored cover */}
      <div style={{
        height: 34, background: coverBg,
        borderBottom: `1px solid ${theme.border}`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 12px',
      }}>
        <span style={{
          fontSize: 10.5, fontWeight: 600, letterSpacing: 0.3,
          color: theme.tagFg(accent), textTransform: 'uppercase',
        }}>{accent}</span>
        <button onClick={(e) => { e.stopPropagation(); onPin(); }} style={{
          all: 'unset', cursor: 'pointer', color: note.pinned ? theme.violet : theme.tagFg(accent),
          opacity: note.pinned ? 1 : 0.4,
        }}>
          {note.pinned ? <IconPinFilled size={12}/> : <IconPin size={12}/>}
        </button>
      </div>
      {/* Body */}
      <div style={{ padding: 12, flex: 1, display: 'flex', flexDirection: 'column', minHeight: h }}>
        <div style={{
          fontSize: 14, fontWeight: 600, letterSpacing: -0.3,
          color: theme.text, lineHeight: 1.28, marginBottom: 6,
          display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
        }}>{note.title}</div>
        <div style={{
          fontSize: 12, lineHeight: 1.42, color: theme.text3,
          flex: 1, overflow: 'hidden',
          display: '-webkit-box', WebkitLineClamp: 5, WebkitBoxOrient: 'vertical',
        }}>{note.preview}</div>
        <div style={{
          marginTop: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          gap: 6,
        }}>
          <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', minWidth: 0 }}>
            {note.tags.slice(1,3).map(t => (
              <span key={t} style={{
                width: 6, height: 6, borderRadius: 3, background: theme.tagDot(t),
                flexShrink: 0,
              }}/>
            ))}
          </div>
          <div style={{
            fontSize: 10.5, color: theme.text4, fontVariantNumeric: 'tabular-nums',
            flexShrink: 0,
          }}>{note.updated}</div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { VariantCanvas, CoverCard });
